import Foundation
import SwiftData
import Testing

@testable import PhotoAlarm

struct WakeAlarmTests {
    @Test func numbersOneToSevenMapToSundayThroughSaturday() {
        let expected: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        #expect((1...7).map(WakeAlarm.weekday(for:)) == expected)
    }

    @Test func numbersOutsideOneToSevenAreNotWeekdays() {
        #expect([-1, 0, 8, 100].allSatisfy { WakeAlarm.weekday(for: $0) == nil })
    }

    @Test func anAlarmDropsOutOfRangeNumbersFromItsWeekdays() {
        let alarm = WakeAlarm(hour: 7, minute: 30, weekdayNumbers: [2, 0, 6, 9, 2])

        #expect(alarm.weekdays == [.monday, .friday])
    }

    @Test func aSnapshotCarriesTheAlarmsScheduleAndState() {
        let id = UUID()
        let alarm = WakeAlarm(id: id, hour: 6, minute: 45, weekdayNumbers: [1, 7], isEnabled: true)

        #expect(
            alarm.snapshot
                == WakeAlarmSnapshot(id: id, hour: 6, minute: 45, weekdays: [.sunday, .saturday], isEnabled: true))
    }

    @Test func aNewAlarmIsDisabledUntilSaidOtherwise() {
        #expect(WakeAlarm(hour: 7, minute: 0, weekdayNumbers: [2]).isEnabled == false)
    }

    @MainActor
    @Test func anAlarmSurvivesBeingStoredAndFetchedBack() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let id = UUID()
        container.mainContext.insert(
            WakeAlarm(id: id, hour: 5, minute: 15, weekdayNumbers: [2, 3, 4], isEnabled: true))
        try container.mainContext.save()

        let stored = try #require(try container.mainContext.fetch(FetchDescriptor<WakeAlarm>()).first)

        #expect(stored.id == id)
        #expect(stored.hour == 5)
        #expect(stored.minute == 15)
        #expect(stored.weekdayNumbers == [2, 3, 4])
        #expect(stored.isEnabled)
    }
}
