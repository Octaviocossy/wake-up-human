@testable import WakeUpHuman

/// Stands in for the rain player: counts starts and stops, remembers the volume and plays nothing.
@MainActor
final class RainPlayerFake: RainPlaying {
    struct StartFailure: Error {}

    private(set) var isPlaying = false
    /// Every call to `start()`, including the ones that threw.
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var volume: Float = 0
    /// When set, `start()` throws it and the rain does not play.
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
