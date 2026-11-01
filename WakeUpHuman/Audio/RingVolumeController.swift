import Foundation

/// Borrows the system volume for a Ring and gives it back (decisions 8 and 16).
///
/// `begin` snapshots the default output device's volume and mute, unmutes it and ramps the volume to
/// maximum; `end` restores the snapshot. The snapshot is persisted for the whole Ring, so a Force
/// Quit or a crash mid-Ring still gives the volume back on the next launch.
@MainActor
final class RingVolumeController {
    enum State: Equatable {
        case idle
        case ramping(percent: Int, secondsToMax: Int)
        case atMaximum
        /// The output device exposes no settable volume, so there is nothing to borrow.
        case unavailable
    }

    static let tickInterval: TimeInterval = 0.5
    static let pendingRestoreKey = "pendingVolumeRestore"

    private(set) var state: State = .idle {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }
    var onStateChange: (@MainActor (State) -> Void)?

    private let volume: SystemVolumeControlling
    private let ticker: RepeatingTicker
    private let defaults: UserDefaults
    private var snapshot: VolumeSnapshot?
    private var ramp: VolumeRamp?

    init(
        volume: SystemVolumeControlling,
        ticker: RepeatingTicker = RunLoopTicker(),
        defaults: UserDefaults = .standard
    ) {
        self.volume = volume
        self.ticker = ticker
        self.defaults = defaults
    }

    /// Starts the ramp from the current volume. Does nothing while a Ring already holds the volume,
    /// so an Occurrence joining a Ring never overwrites the snapshot with the already-raised level.
    func begin(now: Date) {
        guard state == .idle else { return }
        // A borrow that was never given back (Force Quit, crash) must be returned first, or this
        // snapshot would capture the raised level as if it were the user's own.
        restorePendingIfNeeded()

        guard let snapshot = volume.current() else {
            Log.audio.info("The output device has no settable volume; the Ring plays at its own level")
            state = .unavailable
            return
        }
        self.snapshot = snapshot
        persist(snapshot)

        volume.setMuted(false)
        ramp = VolumeRamp(start: snapshot.volume, startedAt: now)
        tick(now: now)
        // `tick` already stops a ramp that starts at maximum; a ticker would only fire once to find out.
        guard state != .atMaximum else { return }
        ticker.start(every: Self.tickInterval) { [weak self] in
            self?.tick(now: Date())
        }
    }

    /// Moves the volume along the ramp on the **current** default output device and unmutes it
    /// again, in case the output moved to another device (a Bluetooth speaker powering off).
    func tick(now: Date) {
        guard let ramp else { return }
        let level = ramp.volume(at: now)
        volume.setVolume(level)
        volume.setMuted(false)
        if ramp.isComplete(at: now) {
            state = .atMaximum
            ticker.stop()
        } else {
            state = .ramping(
                percent: Int((level * 100).rounded()),
                secondsToMax: ramp.secondsToMaximum(at: now)
            )
        }
    }

    /// Gives the volume and mute back to the device they were borrowed from. A second call is a no-op.
    func end() {
        guard state != .idle else { return }
        ticker.stop()
        if let snapshot {
            if !volume.restore(snapshot) {
                Log.audio.error("Could not restore the system volume after the Ring")
            }
        }
        defaults.removeObject(forKey: Self.pendingRestoreKey)
        snapshot = nil
        ramp = nil
        state = .idle
    }

    /// Restores a snapshot left behind by a Ring that never ended cleanly. The app calls it at launch.
    func restorePendingIfNeeded() {
        // While a Ring holds the volume, the stored snapshot is that Ring's own.
        guard snapshot == nil, let data = defaults.data(forKey: Self.pendingRestoreKey) else { return }
        defaults.removeObject(forKey: Self.pendingRestoreKey)
        guard let pending = try? JSONDecoder().decode(VolumeSnapshot.self, from: data) else {
            Log.audio.error("Discarded an unreadable pending volume restore")
            return
        }
        let restored = volume.restore(pending)
        Log.audio.info("Restored the system volume left by an earlier Ring: \(restored, privacy: .public)")
    }

    private func persist(_ snapshot: VolumeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            Log.audio.error("Could not persist the volume snapshot")
            return
        }
        defaults.set(data, forKey: Self.pendingRestoreKey)
    }
}
