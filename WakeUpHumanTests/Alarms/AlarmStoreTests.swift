import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct AlarmStoreTests {
    private let suite = TestDefaults()

    @Test func addArmsTheAlarm() {
        let store = AlarmStore(defaults: suite.defaults)

        let alarm = store.add(hour: 7, minute: 0, weekdays: [.monday])

        #expect(alarm.isArmed)
        #expect(store.alarms == [alarm])
    }

    @Test func addKeepsTheListSortedByTime() {
        let store = AlarmStore(defaults: suite.defaults)

        store.add(hour: 8, minute: 30, weekdays: [])
        store.add(hour: 6, minute: 15, weekdays: [])
        store.add(hour: 7, minute: 0, weekdays: [])

        #expect(store.alarms.map(\.minuteOfDay) == [375, 420, 510])
    }

    @Test func updateChangesTheTimeAndDaysAndReArmsTheAlarm() throws {
        let store = AlarmStore(defaults: suite.defaults)
        let alarm = store.add(hour: 7, minute: 0, weekdays: [])
        store.setArmed(false, id: alarm.id)

        store.update(id: alarm.id, hour: 9, minute: 5, weekdays: [.saturday, .sunday])

        let updated = try #require(store.alarms.first)
        #expect(updated.id == alarm.id)
        #expect(updated.hour == 9)
        #expect(updated.minute == 5)
        #expect(updated.weekdays == [.saturday, .sunday])
        #expect(updated.isArmed)
    }

    @Test func updateReSortsTheList() {
        let store = AlarmStore(defaults: suite.defaults)
        let first = store.add(hour: 6, minute: 0, weekdays: [])
        store.add(hour: 7, minute: 0, weekdays: [])

        store.update(id: first.id, hour: 9, minute: 0, weekdays: [])

        #expect(store.alarms.map(\.hour) == [7, 9])
    }

    @Test func setArmedArmsAndDisarms() throws {
        let store = AlarmStore(defaults: suite.defaults)
        let alarm = store.add(hour: 7, minute: 0, weekdays: [])

        store.setArmed(false, id: alarm.id)
        #expect(try #require(store.alarms.first).isArmed == false)

        store.setArmed(true, id: alarm.id)
        #expect(try #require(store.alarms.first).isArmed)
    }

    @Test func deleteRemovesTheAlarm() {
        let store = AlarmStore(defaults: suite.defaults)
        let kept = store.add(hour: 6, minute: 0, weekdays: [])
        let removed = store.add(hour: 7, minute: 0, weekdays: [])

        store.delete(id: removed.id)

        #expect(store.alarms == [kept])
    }

    @Test func disarmSwitchesOffOnlyTheGivenAlarms() {
        let store = AlarmStore(defaults: suite.defaults)
        let first = store.add(hour: 6, minute: 0, weekdays: [])
        let second = store.add(hour: 7, minute: 0, weekdays: [])

        store.disarm(ids: [first.id])

        #expect(store.alarms.first { $0.id == first.id }?.isArmed == false)
        #expect(store.alarms.first { $0.id == second.id }?.isArmed == true)
    }

    @Test func theListRoundTripsThroughAFreshStoreOnTheSameDefaults() {
        let store = AlarmStore(defaults: suite.defaults)
        store.add(hour: 7, minute: 0, weekdays: [.monday, .friday])
        let disarmed = store.add(hour: 8, minute: 30, weekdays: [])
        store.setArmed(false, id: disarmed.id)

        let reloaded = AlarmStore(defaults: suite.defaults)

        #expect(reloaded.alarms == store.alarms)
    }

    @Test func undecodableDataLoadsAsAnEmptyList() {
        suite.defaults.set(Data("not json".utf8), forKey: AlarmStore.defaultsKey)

        let store = AlarmStore(defaults: suite.defaults)

        #expect(store.alarms.isEmpty)
    }

    @Test func onChangeFiresOncePerMutation() {
        let store = AlarmStore(defaults: suite.defaults)
        var changes = 0
        store.onChange = { changes += 1 }

        let alarm = store.add(hour: 7, minute: 0, weekdays: [])
        #expect(changes == 1)
        store.update(id: alarm.id, hour: 8, minute: 0, weekdays: [])
        #expect(changes == 2)
        store.setArmed(false, id: alarm.id)
        #expect(changes == 3)
        store.disarm(ids: [alarm.id])  // already Disarmed: nothing changed
        #expect(changes == 3)
        store.delete(id: alarm.id)
        #expect(changes == 4)
        store.delete(id: alarm.id)  // already gone
        #expect(changes == 4)
    }

    @Test func onChangeSeesTheMutationAlreadyPersisted() {
        let store = AlarmStore(defaults: suite.defaults)
        var persistedCountAtChange: Int?
        store.onChange = {
            persistedCountAtChange = AlarmStore(defaults: suite.defaults).alarms.count
        }

        store.add(hour: 7, minute: 0, weekdays: [])

        #expect(persistedCountAtChange == 1)
    }
}
