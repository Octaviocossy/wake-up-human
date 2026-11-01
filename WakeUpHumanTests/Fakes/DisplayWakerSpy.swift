@testable import WakeUpHuman

/// Stands in for the user-activity declaration: counts wakes and releases, and lights no display.
@MainActor
final class DisplayWakerSpy: DisplayWaking {
    private(set) var wakeCount = 0
    private(set) var releaseCount = 0

    func wake() {
        wakeCount += 1
    }

    func release() {
        releaseCount += 1
    }
}
