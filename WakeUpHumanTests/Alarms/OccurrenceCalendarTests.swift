import Foundation
import Testing

@testable import WakeUpHuman

struct OccurrenceCalendarTests {
    private let utc = OccurrenceCalendar(calendar: TestCalendar.utc)

    // 2026-11-02 is a Monday.
    @Test func weekdayAlarmFallsOnTheNextListedWeekday() {
        let alarm = TestCalendar.alarm(7, 0, weekdays: [.wednesday, .friday])
        let mondayNoon = TestCalendar.date(2026, 11, 2, 12)

        #expect(utc.nextOccurrence(of: alarm, after: mondayNoon) == TestCalendar.date(2026, 11, 4, 7))
    }

    @Test func weekdayAlarmWrapsToTheFollowingWeek() {
        let alarm = TestCalendar.alarm(7, 0, weekdays: [.monday])
        let mondayNoon = TestCalendar.date(2026, 11, 2, 12)

        #expect(utc.nextOccurrence(of: alarm, after: mondayNoon) == TestCalendar.date(2026, 11, 9, 7))
    }

    @Test func oneTimeAlarmIsTodayWhenItsTimeIsStillAhead() {
        let alarm = TestCalendar.alarm(7, 0)

        #expect(
            utc.nextOccurrence(of: alarm, after: TestCalendar.date(2026, 11, 2, 6, 59))
                == TestCalendar.date(2026, 11, 2, 7))
    }

    @Test func oneTimeAlarmIsTomorrowWhenItsTimeHasPassed() {
        let alarm = TestCalendar.alarm(7, 0)

        #expect(
            utc.nextOccurrence(of: alarm, after: TestCalendar.date(2026, 11, 2, 7, 1))
                == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func nextOccurrenceIsStrictlyAfterTheGivenDate() {
        let alarm = TestCalendar.alarm(7, 0, weekdays: Set(Weekday.allCases))
        let onTheOccurrence = TestCalendar.date(2026, 11, 2, 7)

        #expect(utc.nextOccurrence(of: alarm, after: onTheOccurrence) == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func occurrencesYieldsOnePerDayForADailyAlarm() {
        let alarm = TestCalendar.alarm(7, 0, weekdays: Set(Weekday.allCases))

        let dates = utc.occurrences(
            of: alarm, after: TestCalendar.date(2026, 11, 2, 7), through: TestCalendar.date(2026, 11, 5, 7))

        #expect(
            dates == [
                TestCalendar.date(2026, 11, 3, 7), TestCalendar.date(2026, 11, 4, 7), TestCalendar.date(2026, 11, 5, 7),
            ])
    }

    @Test func occurrencesIncludesTheEndAndExcludesTheStart() {
        let alarm = TestCalendar.alarm(7, 0, weekdays: Set(Weekday.allCases))
        let day = TestCalendar.date(2026, 11, 2, 7)

        #expect(utc.occurrences(of: alarm, after: day, through: day).isEmpty)
        #expect(utc.occurrences(of: alarm, after: day.addingTimeInterval(-1), through: day) == [day])
    }

    @Test func oneTimeAlarmYieldsAtMostOneOccurrence() {
        let alarm = TestCalendar.alarm(7, 0)

        let dates = utc.occurrences(
            of: alarm, after: TestCalendar.date(2026, 11, 2), through: TestCalendar.date(2026, 11, 9))

        #expect(dates == [TestCalendar.date(2026, 11, 2, 7)])
    }

    @Test func aTimeSkippedByADaylightSavingGapMapsToTheNextExistingTime() {
        // Europe/Madrid springs forward on 2026-03-29: 02:00 becomes 03:00, so 02:30 does not exist.
        let madrid = OccurrenceCalendar(calendar: TestCalendar.madrid)
        let alarm = TestCalendar.alarm(2, 30, weekdays: Set(Weekday.allCases))

        let next = madrid.nextOccurrence(of: alarm, after: TestCalendar.date(2026, 3, 28, 12, in: TestCalendar.madrid))

        #expect(next == TestCalendar.date(2026, 3, 29, 3, in: TestCalendar.madrid))
    }
}
