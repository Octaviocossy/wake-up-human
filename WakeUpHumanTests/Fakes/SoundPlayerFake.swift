@testable import WakeUpHuman

/// Stands in for a generated sound (the alarm tone, the rain): counts starts and stops and plays nothing.
@MainActor
final class SoundPlayerFake: SoundPlaying {
    struct StartFailure: Error {}

    private(set) var isPlaying = false
    /// Every call to `start()`, including the ones that threw.
    private(set) var startCount = 0
    private(set) var stopCount = 0
    /// When set, `start()` throws it and the sound does not play.
    var startError: Error?

    func start() throws {
        startCount += 1
        if let startError { throw startError }
        isPlaying = true
    }

    func stop() {
        stopCount += 1
        isPlaying = false
    }
}
