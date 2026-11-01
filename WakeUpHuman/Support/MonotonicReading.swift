import Foundation

/// One reading of the Mac's two monotonic clocks. Setting the system clock or the time zone moves
/// neither, and only the difference between two readings means anything.
struct MonotonicReading: Equatable, Sendable {
    /// Seconds on a clock that keeps counting through System sleep.
    let continuous: TimeInterval
    /// Seconds on a clock that stops while the Mac is in System sleep.
    let uptime: TimeInterval

    /// `CLOCK_MONOTONIC_RAW` counts through System sleep and `CLOCK_UPTIME_RAW` does not. Both run
    /// on the same raw timebase, so the gap between them grows by exactly the time spent asleep.
    static func now() -> MonotonicReading {
        MonotonicReading(continuous: seconds(on: CLOCK_MONOTONIC_RAW), uptime: seconds(on: CLOCK_UPTIME_RAW))
    }

    /// Seconds that really passed since `earlier`, System sleep included.
    func elapsed(since earlier: MonotonicReading) -> TimeInterval {
        continuous - earlier.continuous
    }

    /// Seconds the Mac spent in System sleep since `earlier`.
    func asleep(since earlier: MonotonicReading) -> TimeInterval {
        elapsed(since: earlier) - (uptime - earlier.uptime)
    }

    private static func seconds(on clock: clockid_t) -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(clock)) / 1_000_000_000
    }
}
