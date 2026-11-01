import Foundation
import Testing

@testable import WakeUpHuman

struct UpcomingOccurrenceTests {
    private let utc = OccurrenceCalendar(calendar: TestCalendar.utc)
    private let now = TestCalendar.date(2026, 11, 2, 22, 46)

    @Test func picksTheEarliestOccurrenceAmongArmedAlarms() {
        let later = TestCalendar.alarm(8, 30)
        let earlier = TestCalendar.alarm(6, 15)

        let upcoming = UpcomingOccurrence.next(in: [later, earlier], after: now, calendar: utc)

        #expect(upcoming == UpcomingOccurrence(alarm: earlier, date: TestCalendar.date(2026, 11, 3, 6, 15)))
    }

    @Test func ignoresDisarmedAlarms() {
        let disarmed = TestCalendar.alarm(6, 15, isArmed: false)
        let armed = TestCalendar.alarm(8, 30)

        let upcoming = UpcomingOccurrence.next(in: [disarmed, armed], after: now, calendar: utc)

        #expect(upcoming?.alarm.id == armed.id)
    }

    @Test func isNilWhenNoAlarmIsArmed() {
        let disarmed = TestCalendar.alarm(6, 15, isArmed: false)

        #expect(UpcomingOccurrence.next(in: [disarmed], after: now, calendar: utc) == nil)
        #expect(UpcomingOccurrence.next(in: [], after: now, calendar: utc) == nil)
    }
}
