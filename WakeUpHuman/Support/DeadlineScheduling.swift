import Foundation

/// Runs one in-process action at a deadline, and nothing else. It never decides whether the
/// deadline passed — the action checks the clock when it runs. It never wakes a sleeping Mac
/// (invariant 6): a deadline that passes during System sleep runs its action after the wake.
@MainActor
protocol DeadlineScheduling: AnyObject {
    /// Schedules `action` at `deadline`, replacing any action already scheduled.
    func schedule(at deadline: Date, perform action: @escaping @MainActor @Sendable () -> Void)
    /// Cancels the scheduled action. A no-op when none is scheduled.
    func cancel()
}

/// A `DispatchSourceTimer` scheduled against the **wall clock** and marked `.strict`:
/// - `wallDeadline`, not `deadline`: `DispatchTime` is mach uptime, which stops while the Mac
///   sleeps; wall time tracks the clock Occurrences are expressed in.
/// - `.strict`: opts out of timer coalescing and App Nap throttling — an `LSUIElement` agent with
///   no window is the process shape the system throttles hardest.
@MainActor
final class DispatchDeadlineScheduler: DeadlineScheduling {
    private var timer: (any DispatchSourceTimer)?

    func schedule(at deadline: Date, perform action: @escaping @MainActor @Sendable () -> Void) {
        cancel()
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        timer.schedule(wallDeadline: .now() + max(0, deadline.timeIntervalSinceNow), leeway: .milliseconds(0))
        timer.setEventHandler { MainActor.assumeIsolated { action() } }
        self.timer = timer
        timer.resume()
    }

    func cancel() {
        timer?.cancel()
        timer = nil
    }
}
