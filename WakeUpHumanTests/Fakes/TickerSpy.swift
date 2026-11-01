import Foundation

@testable import WakeUpHuman

/// Stands in for the repeating timer: nothing fires on its own, a test fires the tick by hand.
@MainActor
final class TickerSpy: RepeatingTicker {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var intervals: [TimeInterval] = []
    private(set) var isRunning = false
    private var tick: (@MainActor () -> Void)?

    func start(every interval: TimeInterval, tick: @escaping @MainActor () -> Void) {
        startCount += 1
        intervals.append(interval)
        self.tick = tick
        isRunning = true
    }

    func stop() {
        stopCount += 1
        tick = nil
        isRunning = false
    }

    /// Fires the scheduled tick once; does nothing when the ticker is stopped.
    func fire() {
        tick?()
    }
}
