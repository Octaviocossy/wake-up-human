import Foundation

@testable import WakeUpHuman

/// Records what `OccurrenceScheduler` asked of the wall-clock timer, and lets a test deliver the
/// wake itself — no real timer runs.
@MainActor
final class DeadlineSchedulerSpy: DeadlineScheduling {
    private(set) var scheduledDeadlines: [Date] = []
    private(set) var cancelCount = 0
    private var pendingWake: (@MainActor @Sendable () -> Void)?

    /// The deadline currently scheduled; `nil` after a cancel or before any schedule.
    var currentDeadline: Date? { pendingWake == nil ? nil : scheduledDeadlines.last }

    func schedule(at deadline: Date, wake: @escaping @MainActor @Sendable () -> Void) {
        scheduledDeadlines.append(deadline)
        pendingWake = wake
    }

    func cancel() {
        cancelCount += 1
        pendingWake = nil
    }

    /// Fires the scheduled wake, as the timer would.
    func deliverWake() {
        pendingWake?()
    }
}
