import Foundation
import Testing

@testable import WakeUpHuman

struct OccurrenceTimeLabelTests {
    private let calendar = TestCalendar.utc

    @Test func anOccurrenceReadsAsItsAlarmsTime() {
        let alarm = TestCalendar.alarm(7, 5)
        let occurrence = Occurrence(alarmID: alarm.id, date: TestCalendar.date(2026, 11, 2, 7, 5))

        #expect(timeLabel(of: occurrence, alarms: [alarm], calendar: calendar) == "07:05")
    }

    @Test func aDeletedAlarmsOccurrenceReadsAsItsOwnTimeOfDay() {
        let occurrence = Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, 6, 45))

        #expect(timeLabel(of: occurrence, alarms: [], calendar: calendar) == "06:45")
    }

    @Test func theOccurrenceTimeOfDayFollowsTheCalendarsTimeZone() {
        let occurrence = Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, 6, 45))

        // Madrid is UTC+1 in November.
        #expect(timeLabel(of: occurrence, alarms: [], calendar: TestCalendar.madrid) == "07:45")
    }
}
