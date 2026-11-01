import AudioToolbox
import CoreAudio
import Foundation

/// The default output device's volume and mute at one moment, identified by UID so it can be
/// restored to the same device even if the default output changed during the Ring.
struct VolumeSnapshot: Codable, Equatable, Sendable {
    let deviceUID: String
    let volume: Float32  // 0...1
    let isMuted: Bool
}

@MainActor
protocol SystemVolumeControlling: AnyObject {
    /// The current default output device's state, or `nil` if it has no settable volume.
    func current() -> VolumeSnapshot?
    /// Sets the current default output device's volume (0...1). `false` if refused.
    @discardableResult func setVolume(_ volume: Float32) -> Bool
    /// Mutes or unmutes the current default output device. `false` if refused or unsupported.
    @discardableResult func setMuted(_ muted: Bool) -> Bool
    /// Restores `snapshot` onto the device with its UID, if that device still exists.
    @discardableResult func restore(_ snapshot: VolumeSnapshot) -> Bool
}

/// The CoreAudio implementation. Boundary code: it talks to the real audio hardware, so it has no
/// unit tests — it is covered by the `-volumeProbe` spike (`VolumeProbe`) and by hand.
@MainActor
final class CoreAudioSystemVolume: SystemVolumeControlling {
    func current() -> VolumeSnapshot? {
        guard let device = defaultOutputDevice(), let uid = deviceUID(of: device) else { return nil }
        guard let volume = readVolume(of: device) else { return nil }
        return VolumeSnapshot(deviceUID: uid, volume: volume, isMuted: readMuted(of: device) ?? false)
    }

    @discardableResult
    func setVolume(_ volume: Float32) -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        return writeVolume(volume, to: device)
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        return writeMuted(muted, to: device)
    }

    @discardableResult
    func restore(_ snapshot: VolumeSnapshot) -> Bool {
        guard let device = device(forUID: snapshot.deviceUID) else {
            Log.audio.info("Cannot restore the volume: the output device is gone")
            return false
        }
        // Never let the restored level play audibly louder than intended: when the user's volume was
        // muted, mute first and then lower the level; otherwise lower the level and then unmute.
        if snapshot.isMuted {
            let muted = writeMuted(true, to: device)
            let leveled = writeVolume(snapshot.volume, to: device)
            return muted && leveled
        }
        let leveled = writeVolume(snapshot.volume, to: device)
        // A device without a mute control is never muted, so an unmute that finds nothing to do is fine.
        let unmuted = hasMute(device) ? writeMuted(false, to: device) : true
        return leveled && unmuted
    }

    // MARK: - Devices

    private func defaultOutputDevice() -> AudioObjectID? {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard report(status, "read the default output device"), device != AudioObjectID(kAudioObjectUnknown) else {
            return nil
        }
        return device
    }

    private func deviceUID(of device: AudioObjectID) -> String? {
        var address = Self.address(kAudioDevicePropertyDeviceUID, scope: kAudioObjectPropertyScopeGlobal)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid)
        guard report(status, "read the device UID"), let uid else { return nil }
        return uid.takeRetainedValue() as String
    }

    private func device(forUID uid: String) -> AudioObjectID? {
        var address = Self.address(kAudioHardwarePropertyTranslateUIDToDevice, scope: kAudioObjectPropertyScopeGlobal)
        var qualifier: CFString = uid as CFString
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let qualifierSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &qualifier) { qualifierPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, qualifierSize, qualifierPointer, &size, &device)
        }
        guard report(status, "translate a device UID"), device != AudioObjectID(kAudioObjectUnknown) else {
            return nil
        }
        return device
    }

    // MARK: - Volume

    /// The virtual main volume works on built-in speakers and on devices that only expose a
    /// per-channel volume, such as many Bluetooth speakers.
    private static var volumeAddress: AudioObjectPropertyAddress {
        address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
    }

    private func readVolume(of device: AudioObjectID) -> Float32? {
        var address = Self.volumeAddress
        guard isSettable(address, on: device),
            let volume: Float32 = read(&address, from: device, what: "read the volume")
        else { return nil }
        return volume
    }

    private func writeVolume(_ volume: Float32, to device: AudioObjectID) -> Bool {
        var address = Self.volumeAddress
        guard isSettable(address, on: device) else { return false }
        return write(min(max(volume, 0), 1), &address, to: device, what: "set the volume")
    }

    // MARK: - Mute

    private static var muteAddress: AudioObjectPropertyAddress {
        address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
    }

    private func hasMute(_ device: AudioObjectID) -> Bool {
        var address = Self.muteAddress
        return AudioObjectHasProperty(device, &address) && isSettable(address, on: device)
    }

    /// `nil` when the device has no mute control, which callers treat as not muted.
    private func readMuted(of device: AudioObjectID) -> Bool? {
        var address = Self.muteAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        guard let muted: UInt32 = read(&address, from: device, what: "read the mute state") else { return nil }
        return muted != 0
    }

    private func writeMuted(_ muted: Bool, to device: AudioObjectID) -> Bool {
        guard hasMute(device) else { return false }
        var address = Self.muteAddress
        return write(UInt32(muted ? 1 : 0), &address, to: device, what: "set the mute state")
    }

    // MARK: - Property plumbing

    private static func address(
        _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func isSettable(_ address: AudioObjectPropertyAddress, on device: AudioObjectID) -> Bool {
        var address = address
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(device, &address, &settable)
        return report(status, "check whether a property is settable") && settable.boolValue
    }

    private func read<Value: BitwiseCopyable>(
        _ address: inout AudioObjectPropertyAddress, from device: AudioObjectID, what: String
    )
        -> Value?
    {
        var size = UInt32(MemoryLayout<Value>.size)
        let value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        defer { value.deallocate() }
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, value)
        guard report(status, what) else { return nil }
        return value.pointee
    }

    private func write<Value: BitwiseCopyable>(
        _ value: Value, _ address: inout AudioObjectPropertyAddress, to device: AudioObjectID, what: String
    ) -> Bool {
        var value = value
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value)
        return report(status, what)
    }

    /// Logs every non-`noErr` status; returns whether the call succeeded.
    private func report(_ status: OSStatus, _ what: String) -> Bool {
        guard status != noErr else { return true }
        Log.audio.error("CoreAudio failed to \(what, privacy: .public): OSStatus \(status)")
        return false
    }
}
