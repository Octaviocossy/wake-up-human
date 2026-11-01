import Foundation
import Testing

@testable import WakeUpHuman

struct RingSessionTests {
    private let start = TestCalendar.date(2026, 11, 2, 7)
    private let first = Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, 7))
    private let second = Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, 7, 5))
    private let third = Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, 7, 10))

    @Test func capEndsAnHourAfterTheStart() {
        let session = RingSession(occurrences: [first], startedAt: start)

        #expect(session.capEndsAt == start.addingTimeInterval(3_600))
    }

    @Test func initOrdersByDateAndDropsDuplicates() {
        let session = RingSession(occurrences: [second, first, second], startedAt: start)

        #expect(session.occurrences == [first, second])
    }

    @Test func joinAddsOnlyNewOccurrencesAndReturnsThem() {
        var session = RingSession(occurrences: [first], startedAt: start)

        let added = session.join([first, second])

        #expect(added == [second])
        #expect(session.occurrences == [first, second])
    }

    @Test func joinKeepsDateOrder() {
        var session = RingSession(occurrences: [second], startedAt: start)

        _ = session.join([third, first])

        #expect(session.occurrences == [first, second, third])
    }

    @Test func joiningOnlyCoveredOccurrencesAddsNothing() {
        var session = RingSession(occurrences: [first, second], startedAt: start)

        let added = session.join([second])

        #expect(added.isEmpty)
        #expect(session.occurrences == [first, second])
    }

    @Test func joinNeverMovesTheCap() {
        var session = RingSession(occurrences: [first], startedAt: start)

        _ = session.join([second])

        #expect(session.startedAt == start)
        #expect(session.capEndsAt == start.addingTimeInterval(RingSession.unattendedCap))
    }
}
