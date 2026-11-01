import Foundation
import Testing

@testable import WakeUpHuman

struct MonotonicReadingTests {
    private let earlier = MonotonicReading(continuous: 1000, uptime: 400)

    @Test func elapsedCountsSystemSleep() {
        let later = MonotonicReading(continuous: 1090, uptime: 430)

        #expect(later.elapsed(since: earlier) == 90)
    }

    @Test func asleepIsTheTimeTheUptimeClockDidNotCount() {
        let later = MonotonicReading(continuous: 1090, uptime: 430)

        #expect(later.asleep(since: earlier) == 60)
    }

    @Test func asleepIsZeroWhenBothClocksAdvancedTogether() {
        let later = MonotonicReading(continuous: 1030, uptime: 430)

        #expect(later.asleep(since: earlier) == 0)
    }
}
