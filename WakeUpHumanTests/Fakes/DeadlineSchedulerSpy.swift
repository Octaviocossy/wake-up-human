import Foundation

@testable import WakeUpHuman

/// Records what `OccurrenceScheduler` asked of the wall-clock timer, and lets a test run the
/// scheduled action itself — no real timer runs.
@MainActor
final class DeadlineSchedulerSpy: DeadlineScheduling {
    private(set) var scheduledDeadlines: [Date] = []
    private var pendingAction: (@MainActor @Sendable () -> Void)?

    /// The deadline currently scheduled; `nil` after a cancel or before any schedule.
    var currentDeadline: Date? { pendingAction == nil ? nil : scheduledDeadlines.last }

    func schedule(at deadline: Date, perform action: @escaping @MainActor @Sendable () -> Void) {
        scheduledDeadlines.append(deadline)
        pendingAction = action
    }

    func cancel() {
        pendingAction = nil
    }

    /// Runs the scheduled action, as the timer would at its deadline.
    func runScheduledAction() {
        pendingAction?()
    }
}
