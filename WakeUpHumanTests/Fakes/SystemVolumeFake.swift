@testable import WakeUpHuman

/// Stands in for the CoreAudio volume controller: records every call, never touches the Mac.
@MainActor
final class SystemVolumeFake: SystemVolumeControlling {
    /// What `current()` reports; `nil` models an output device with no settable volume.
    var currentSnapshot: VolumeSnapshot?
    var setVolumeResult = true
    var setMutedResult = true
    var restoreResult = true

    private(set) var setVolumeCalls: [Float32] = []
    private(set) var setMutedCalls: [Bool] = []
    private(set) var restoredSnapshots: [VolumeSnapshot] = []

    init(currentSnapshot: VolumeSnapshot? = nil) {
        self.currentSnapshot = currentSnapshot
    }

    func current() -> VolumeSnapshot? {
        currentSnapshot
    }

    func setVolume(_ volume: Float32) -> Bool {
        setVolumeCalls.append(volume)
        return setVolumeResult
    }

    func setMuted(_ muted: Bool) -> Bool {
        setMutedCalls.append(muted)
        return setMutedResult
    }

    func restore(_ snapshot: VolumeSnapshot) -> Bool {
        restoredSnapshots.append(snapshot)
        return restoreResult
    }
}
