import Foundation
import SwiftData
import Testing

@testable import PhotoAlarm

@MainActor
struct AlarmListModelTests {
    /// Owns the container so the context stays valid for the whole test.
    @MainActor
    private struct Fixture {
        let directory: URL
        let container: ModelContainer
        let scheduler: FakeAlarmScheduler
        let model: AlarmListModel

        init(targetObjectRegistered: Bool = true) throws {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let scheduler = FakeAlarmScheduler()
            let loop = WakeUpLoop(store: MissionStateStore(directory: directory), scheduler: scheduler)
            let container = try AppModelContainer.make(inMemory: true)
            if targetObjectRegistered {
                try TargetObjectRepository(context: container.mainContext)
                    .replace(with: [Data([1]), Data([2]), Data([3])], testPassedAt: Date(timeIntervalSince1970: 1_000))
            }
            self.directory = directory
            self.container = container
            self.scheduler = scheduler
            model = AlarmListModel(
                context: container.mainContext, scheduler: scheduler,
                sync: AlarmSync(scheduler: scheduler, loop: loop))
        }

        var context: ModelContext { container.mainContext }

        func storedAlarms() throws -> [WakeAlarm] {
            try context.fetch(FetchDescriptor<WakeAlarm>())
        }

        /// A stored Alarm, disabled unless `enabled`.
        func insertAlarm(hour: Int = 7, minute: Int = 0, weekdayNumbers: [Int] = [2, 6], enabled: Bool = false)
            throws -> WakeAlarm
        {
            let alarm = WakeAlarm(hour: hour, minute: minute, weekdayNumbers: weekdayNumbers, isEnabled: enabled)
            context.insert(alarm)
            try context.save()
            return alarm
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    // MARK: Enabling

    @Test func enablingAnAlarmRegistersItsWeeklySystemAlarm() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let alarm = try fixture.insertAlarm(hour: 6, minute: 45, weekdayNumbers: [2, 6])

        await fixture.model.setEnabled(alarm, to: true)

        #expect(alarm.isEnabled)
        #expect(fixture.model.enableBlock == nil)
        #expect(
            fixture.scheduler.weekly == [.init(id: alarm.id, hour: 6, minute: 45, weekdays: [.monday, .friday])])
    }

    @Test func withoutATargetObjectEnablingIsRefusedAndAuthorizationIsNotAsked() async throws {
        let fixture = try Fixture(targetObjectRegistered: false)
        defer { fixture.cleanUp() }
        let alarm = try fixture.insertAlarm()

        await fixture.model.setEnabled(alarm, to: true)

        #expect(!alarm.isEnabled)
        #expect(fixture.model.enableBlock == .targetObjectNotRegistered)
        #expect(fixture.scheduler.authorizationRequests == 0)
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    @Test func withoutAuthorizationEnablingIsRefused() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.scheduler.authorized = false
        let alarm = try fixture.insertAlarm()

        await fixture.model.setEnabled(alarm, to: true)

        #expect(!alarm.isEnabled)
        #expect(fixture.model.enableBlock == .notAuthorized)
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    @Test func aRefusalIsClearedByTheNextSuccessfulChange() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.scheduler.authorized = false
        let alarm = try fixture.insertAlarm()
        await fixture.model.setEnabled(alarm, to: true)
        fixture.scheduler.authorized = true

        await fixture.model.setEnabled(alarm, to: true)

        #expect(alarm.isEnabled)
        #expect(fixture.model.enableBlock == nil)
    }

    @Test func disablingAnAlarmCancelsItsSystemAlarm() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let alarm = try fixture.insertAlarm()
        await fixture.model.setEnabled(alarm, to: true)

        await fixture.model.setEnabled(alarm, to: false)

        #expect(!alarm.isEnabled)
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    @Test func anAlarmThatCannotBeRegisteredIsReported() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.scheduler.schedulingFails = true
        let alarm = try fixture.insertAlarm()

        await fixture.model.setEnabled(alarm, to: true)

        #expect(fixture.model.failedAlarmIDs == [alarm.id])
    }

    // MARK: Saving

    @Test func aNewAlarmStartsEnabledWhenTheGatePasses() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let saved = await fixture.model.save(nil, hour: 7, minute: 10, weekdayNumbers: [3, 5, 3])

        #expect(saved)
        let stored = try #require(try fixture.storedAlarms().first)
        #expect(stored.isEnabled)
        #expect(stored.weekdayNumbers == [3, 5])
        #expect(
            fixture.scheduler.weekly == [.init(id: stored.id, hour: 7, minute: 10, weekdays: [.tuesday, .thursday])])
    }

    @Test func aNewAlarmStartsDisabledWhenTheGateBlocks() async throws {
        let fixture = try Fixture(targetObjectRegistered: false)
        defer { fixture.cleanUp() }

        let saved = await fixture.model.save(nil, hour: 7, minute: 10, weekdayNumbers: [2])

        #expect(saved)
        let stored = try #require(try fixture.storedAlarms().first)
        #expect(!stored.isEnabled)
        #expect(fixture.model.enableBlock == .targetObjectNotRegistered)
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    @Test func anAlarmWithNoWeekdayIsNotSaved() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let saved = await fixture.model.save(nil, hour: 7, minute: 10, weekdayNumbers: [])

        #expect(!saved)
        #expect(try fixture.storedAlarms().isEmpty)
    }

    @Test func editingAnEnabledAlarmRegistersItAgainWithTheNewSchedule() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let alarm = try fixture.insertAlarm(hour: 6, minute: 0, weekdayNumbers: [2])
        await fixture.model.setEnabled(alarm, to: true)

        await fixture.model.save(alarm, hour: 8, minute: 30, weekdayNumbers: [7, 1])

        #expect(try fixture.storedAlarms().count == 1)
        #expect(alarm.isEnabled)
        #expect(alarm.weekdayNumbers == [1, 7])
        #expect(
            fixture.scheduler.weekly == [.init(id: alarm.id, hour: 8, minute: 30, weekdays: [.sunday, .saturday])])
    }

    @Test func editingADisabledAlarmKeepsItDisabled() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let alarm = try fixture.insertAlarm()

        await fixture.model.save(alarm, hour: 9, minute: 0, weekdayNumbers: [4])

        #expect(!alarm.isEnabled)
        #expect(alarm.hour == 9)
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    // MARK: Deleting

    @Test func deletingAnAlarmCancelsItsSystemAlarm() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let doomed = try fixture.insertAlarm()
        let kept = try fixture.insertAlarm(hour: 9)
        await fixture.model.setEnabled(doomed, to: true)
        await fixture.model.setEnabled(kept, to: true)
        let doomedID = doomed.id

        await fixture.model.delete([doomed])

        #expect(try fixture.storedAlarms().map(\.id) == [kept.id])
        #expect(fixture.scheduler.weekly.map(\.id) == [kept.id])
        #expect(fixture.scheduler.cancelled.contains(doomedID))
    }
}
