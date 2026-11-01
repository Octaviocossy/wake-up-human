@testable import WakeUpHuman

/// Stands in for an IOKit power assertion: counts acquires and releases, and never asserts anything.
@MainActor
final class PowerAssertionStub: PowerAssertionControlling {
    /// When `false`, `acquire()` reports a refusal and the assertion is not held.
    var acquireSucceeds = true
    private(set) var acquireCount = 0
    private(set) var releaseCount = 0
    private(set) var isHeld = false

    func acquire() -> Bool {
        acquireCount += 1
        guard acquireSucceeds else { return false }
        isHeld = true
        return true
    }

    func release() {
        releaseCount += 1
        isHeld = false
    }
}
