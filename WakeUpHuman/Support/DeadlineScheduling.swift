import Foundation

/// Schedules a single wake-up at a deadline, and nothing else. It never decides whether the
/// deadline passed — the caller checks the clock when woken.
@MainActor
protocol DeadlineScheduling: AnyObject {
    /// Schedules `wake` at `deadline`, replacing any wake already scheduled.
    func schedule(at deadline: Date, wake: @escaping @MainActor @Sendable () -> Void)
    /// Cancels the scheduled wake. A no-op when none is scheduled.
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

    func schedule(at deadline: Date, wake: @escaping @MainActor @Sendable () -> Void) {
        cancel()
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        timer.schedule(wallDeadline: .now() + max(0, deadline.timeIntervalSinceNow), leeway: .milliseconds(0))
        timer.setEventHandler { MainActor.assumeIsolated { wake() } }
        self.timer = timer
        timer.resume()
    }

    func cancel() {
        timer?.cancel()
        timer = nil
    }
}
