import Foundation
import SwiftData
import Testing

@testable import PhotoAlarm

struct AlarmSyncTests {
    /// A sync over a fake scheduler and a `WakeUpLoop` on a unique temporary store.
    private struct Fixture {
        let directory: URL
        let clock: TestClock
        let scheduler: FakeAlarmScheduler
        let loop: WakeUpLoop
        let sync: AlarmSync

        init() {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let clock = TestClock()
            let scheduler = FakeAlarmScheduler()
            let loop = WakeUpLoop(
                store: MissionStateStore(directory: directory), scheduler: scheduler, now: { clock.now })
            self.directory = directory
            self.clock = clock
            self.scheduler = scheduler
            self.loop = loop
            sync = AlarmSync(scheduler: scheduler, loop: loop)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func alarm(
        _ id: UUID = UUID(), hour: Int = 7, minute: Int = 0,
        weekdays: Set<Locale.Weekday> = [.monday, .friday], enabled: Bool = true
    ) -> WakeAlarmSnapshot {
        WakeAlarmSnapshot(id: id, hour: hour, minute: minute, weekdays: weekdays, isEnabled: enabled)
    }

    // MARK: Enabled Alarms

    @Test func everyEnabledAlarmIsScheduledWeeklyWithItsOwnIDTimeAndWeekdays() async {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let weekdayAlarm = alarm(hour: 6, minute: 30, weekdays: [.monday, .tuesday, .wednesday])
        let weekendAlarm = alarm(hour: 9, minute: 5, weekdays: [.saturday, .sunday])

        let report = await fixture.sync.reconcile([weekdayAlarm, weekendAlarm])

        #expect(report == AlarmSync.Report(scheduled: [weekdayAlarm.id, weekendAlarm.id]))
        #expect(
            Set(fixture.scheduler.weekly)
                == [
                    .init(id: weekdayAlarm.id, hour: 6, minute: 30, weekdays: [.monday, .tuesday, .wednesday]),
                    .init(id: weekendAlarm.id, hour: 9, minute: 5, weekdays: [.saturday, .sunday]),
                ])
    }

    @Test func anAlreadyRegisteredAlarmIsCancelledAndScheduledAgainWithItsCurrentTime() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let id = UUID()
        try await fixture.scheduler.scheduleWeekly(id: id, hour: 6, minute: 0, weekdays: [.monday])

        let report = await fixture.sync.reconcile([alarm(id, hour: 7, minute: 15, weekdays: [.friday])])

        #expect(fixture.scheduler.weekly == [.init(id: id, hour: 7, minute: 15, weekdays: [.friday])])
        #expect(fixture.scheduler.cancelled == [id])
        #expect(report == AlarmSync.Report(scheduled: [id]))
    }

    @Test func reconcilingTwiceLeavesTheSameRegistrations() async {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let alarms = [alarm(hour: 6), alarm(hour: 8, weekdays: [.sunday])]

        let first = await fixture.sync.reconcile(alarms)
        let afterFirst = Set(fixture.scheduler.weekly)
        let second = await fixture.sync.reconcile(alarms)

        #expect(Set(fixture.scheduler.weekly) == afterFirst)
        #expect(fixture.scheduler.weekly.count == 2)
        #expect(second == first)
    }

    // MARK: System alarms nothing owns

    @Test func aDisabledAlarmsSystemAlarmIsCancelled() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let id = UUID()
        try await fixture.scheduler.scheduleWeekly(id: id, hour: 7, minute: 0, weekdays: [.monday])

        let report = await fixture.sync.reconcile([alarm(id, enabled: false)])

        #expect(fixture.scheduler.weekly.isEmpty)
        #expect(report == AlarmSync.Report(cancelled: [id]))
    }

    @Test func aDeletedAlarmsSystemAlarmIsCancelled() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let id = UUID()
        try await fixture.scheduler.scheduleWeekly(id: id, hour: 7, minute: 0, weekdays: [.monday])

        let report = await fixture.sync.reconcile([])

        #expect(fixture.scheduler.weekly.isEmpty)
        #expect(report.cancelled == [id])
    }

    @Test func anOrphanSystemAlarmIsCancelled() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let orphan = UUID()
        try await fixture.scheduler.scheduleOneOff(id: orphan, at: fixture.clock.now.addingTimeInterval(60))

        let report = await fixture.sync.reconcile([])

        #expect(fixture.scheduler.oneOffs.isEmpty)
        #expect(report.cancelled == [orphan])
    }

    // MARK: Open Wake-up sessions and Rings

    @Test func theFollowUpOfAnOpenSessionIsLeftUntouched() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        try await fixture.loop.ringEnded(systemAlarmID: UUID(), via: .stop)
        let pending = try await fixture.loop.pendingFollowUpIDs()
        let followUp = try #require(pending.first)
        let scheduledFor = try #require(fixture.scheduler.oneOffs[followUp])
        let orphan = UUID()
        try await fixture.scheduler.scheduleOneOff(id: orphan, at: scheduledFor)

        let report = await fixture.sync.reconcile([alarm()])

        #expect(fixture.scheduler.oneOffs[followUp] == scheduledFor)
        #expect(!fixture.scheduler.cancelled.contains(followUp))
        #expect(report.cancelled == [orphan])
    }

    @Test func anAlertingSystemAlarmIsNeitherCancelledNorScheduledAgain() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let ringing = UUID()
        try await fixture.scheduler.scheduleWeekly(id: ringing, hour: 6, minute: 0, weekdays: [.monday])
        let ringingFollowUp = UUID()
        fixture.scheduler.alerting = [ringing, ringingFollowUp]

        let report = await fixture.sync.reconcile([alarm(ringing, hour: 7, minute: 30)])

        #expect(fixture.scheduler.cancelled.isEmpty)
        #expect(fixture.scheduler.weekly == [.init(id: ringing, hour: 6, minute: 0, weekdays: [.monday])])
        #expect(report == AlarmSync.Report())
    }

    // MARK: Failures

    @Test func anAlarmThatCannotBeScheduledIsReportedAsFailed() async {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        fixture.scheduler.schedulingFails = true
        let enabled = alarm()

        let report = await fixture.sync.reconcile([enabled, alarm(enabled: false)])

        #expect(report == AlarmSync.Report(failed: [enabled.id]))
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    @Test func anEnabledAlarmWithNoWeekdayFailsWithoutReachingAlarmKit() async {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let empty = alarm(weekdays: [])

        let report = await fixture.sync.reconcile([empty])

        #expect(report == AlarmSync.Report(failed: [empty.id]))
        #expect(fixture.scheduler.weekly.isEmpty)
    }

    @Test func whenAlarmKitCannotBeReadNothingIsCancelledOrScheduled() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let orphan = UUID()
        try await fixture.scheduler.scheduleOneOff(id: orphan, at: fixture.clock.now.addingTimeInterval(60))
        fixture.scheduler.readingFails = true
        let enabled = alarm()

        let report = await fixture.sync.reconcile([enabled])

        #expect(report == AlarmSync.Report(failed: [enabled.id]))
        #expect(fixture.scheduler.cancelled.isEmpty)
        #expect(fixture.scheduler.weekly.isEmpty)
        #expect(fixture.scheduler.oneOffs.keys.contains(orphan))
    }

    @Test func whenTheMissionStateCannotBeReadUnownedSystemAlarmsAreLeftAlone() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: MissionStateStore(directory: fixture.directory).fileURL)
        let mightBeAFollowUp = UUID()
        try await fixture.scheduler.scheduleOneOff(
            id: mightBeAFollowUp, at: fixture.clock.now.addingTimeInterval(60))
        let enabled = alarm()

        let report = await fixture.sync.reconcile([enabled])

        #expect(report == AlarmSync.Report(scheduled: [enabled.id]))
        #expect(fixture.scheduler.oneOffs.keys.contains(mightBeAFollowUp))
        #expect(fixture.scheduler.cancelled.isEmpty)
    }

    // MARK: Stored Alarms

    @MainActor
    @Test func reconcilingAContextRegistersTheStoredEnabledAlarmsOnly() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let enabled = WakeAlarm(hour: 6, minute: 20, weekdayNumbers: [2, 4], isEnabled: true)
        context.insert(enabled)
        context.insert(WakeAlarm(hour: 8, minute: 0, weekdayNumbers: [3], isEnabled: false))
        try context.save()

        let report = try await fixture.sync.reconcile(in: context)

        #expect(report == AlarmSync.Report(scheduled: [enabled.id]))
        #expect(
            fixture.scheduler.weekly == [.init(id: enabled.id, hour: 6, minute: 20, weekdays: [.monday, .wednesday])])
    }
}
