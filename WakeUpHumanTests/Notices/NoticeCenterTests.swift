import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct NoticeCenterTests {
    private let suite = TestDefaults()
    private let calendar = TestCalendar.utc
    private let now = TestCalendar.date(2026, 11, 2, 7, 5)

    private func center() -> NoticeCenter {
        NoticeCenter(defaults: suite.defaults)
    }

    private func missed(_ hour: Int, _ minute: Int, day: Int = 2, _ cause: MissedCause) -> MissedOccurrence {
        MissedOccurrence(
            occurrence: Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, day, hour, minute)),
            cause: cause)
    }

    private func occurrence(_ hour: Int, _ minute: Int) -> Occurrence {
        Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, hour, minute))
    }

    /// The label of an Occurrence whose Alarm no longer exists: its own time of day.
    private func label(_ occurrence: Occurrence) -> String {
        timeLabel(of: occurrence, alarms: [], calendar: calendar)
    }

    // MARK: Recording

    @Test func recordMissedCreatesOneNoticePerCauseWithAscendingTimes() {
        let notices = center()

        notices.recordMissed(
            [missed(7, 0, .systemSleep), missed(8, 0, .appNotRunning), missed(6, 15, .systemSleep)],
            timeLabel: label, now: now)

        #expect(
            notices.pending.map(\.kind) == [
                .missed(alarmTimes: ["06:15", "07:00"], cause: .systemSleep),
                .missed(alarmTimes: ["08:00"], cause: .appNotRunning),
            ])
        #expect(notices.pending.allSatisfy { $0.createdAt == now })
    }

    @Test func recordMissedOrdersTheNoticesByEachCausesEarliestOccurrence() {
        let notices = center()

        notices.recordMissed(
            [missed(9, 0, .systemSleep), missed(6, 0, .appNotRunning)], timeLabel: label, now: now)

        #expect(
            notices.pending.map(\.kind) == [
                .missed(alarmTimes: ["06:00"], cause: .appNotRunning),
                .missed(alarmTimes: ["09:00"], cause: .systemSleep),
            ])
    }

    @Test func recordMissedNamesAnAlarmMissedOnSeveralDaysOnce() {
        let notices = center()

        notices.recordMissed(
            [missed(7, 0, day: 1, .appNotRunning), missed(7, 0, day: 2, .appNotRunning)],
            timeLabel: label, now: now)

        #expect(notices.pending.map(\.kind) == [.missed(alarmTimes: ["07:00"], cause: .appNotRunning)])
    }

    @Test func recordMissedWithNothingMissedRecordsNothing() {
        let notices = center()

        notices.recordMissed([], timeLabel: label, now: now)

        #expect(notices.pending.isEmpty)
        #expect(suite.defaults.data(forKey: NoticeCenter.pendingKey) == nil)
    }

    @Test func recordUnattendedStoresTheTimesAndTheEnd() {
        let notices = center()
        let endedAt = TestCalendar.date(2026, 11, 2, 9, 30)

        notices.recordUnattended(
            occurrences: [occurrence(8, 35), occurrence(8, 30)], endedAt: endedAt, timeLabel: label, now: endedAt)

        #expect(notices.pending.map(\.kind) == [.unattended(alarmTimes: ["08:30", "08:35"], endedAt: endedAt)])
        #expect(notices.pending.first?.createdAt == endedAt)
    }

    @Test func recordUnattendedWithNoOccurrencesRecordsNothing() {
        let notices = center()

        notices.recordUnattended(occurrences: [], endedAt: now, timeLabel: label, now: now)

        #expect(notices.pending.isEmpty)
    }

    @Test func noticesAreKeptOldestFirst() {
        let notices = center()

        notices.recordMissed([missed(6, 15, .systemSleep)], timeLabel: label, now: now)
        notices.recordUnattended(occurrences: [occurrence(8, 30)], endedAt: now, timeLabel: label, now: now)

        #expect(
            notices.pending.map(\.kind) == [
                .missed(alarmTimes: ["06:15"], cause: .systemSleep),
                .unattended(alarmTimes: ["08:30"], endedAt: now),
            ])
    }

    // MARK: Persistence

    @Test func pendingNoticesSurviveAFreshCenterOnTheSameSuite() {
        let notices = center()
        notices.recordMissed([missed(6, 15, .systemSleep)], timeLabel: label, now: now)
        notices.recordUnattended(occurrences: [occurrence(8, 30)], endedAt: now, timeLabel: label, now: now)

        let relaunched = center()

        #expect(relaunched.pending == notices.pending)
        #expect(relaunched.pending.count == 2)
    }

    @Test func acknowledgeRemovesOneNoticeAndPersists() throws {
        let notices = center()
        notices.recordMissed([missed(6, 15, .systemSleep)], timeLabel: label, now: now)
        notices.recordUnattended(occurrences: [occurrence(8, 30)], endedAt: now, timeLabel: label, now: now)
        let first = try #require(notices.pending.first)
        let second = try #require(notices.pending.last)

        notices.acknowledge(id: first.id)

        #expect(notices.pending == [second])
        #expect(center().pending == [second])
    }

    @Test func acknowledgingAnUnknownNoticeChangesNothing() {
        let notices = center()
        notices.recordMissed([missed(6, 15, .systemSleep)], timeLabel: label, now: now)

        notices.acknowledge(id: UUID())

        #expect(notices.pending.count == 1)
    }

    @Test func undecodableDataLoadsAsEmptyAndIsReplacedByTheNextRecord() {
        suite.defaults.set(Data("not json".utf8), forKey: NoticeCenter.pendingKey)

        let notices = center()
        #expect(notices.pending.isEmpty)

        notices.recordMissed([missed(6, 15, .systemSleep)], timeLabel: label, now: now)
        #expect(center().pending.count == 1)
    }

    // MARK: Derived notices

    private let seven = TestCalendar.alarm(7, 0)

    private func upcoming(in interval: TimeInterval) -> UpcomingOccurrence {
        UpcomingOccurrence(alarm: seven, date: now.addingTimeInterval(interval))
    }

    private let minute: TimeInterval = 60
    private let hour: TimeInterval = 3600

    @Test func bedtimeOffWithAnAlarmJustInsideTheWindowGivesTheBedtimeOffNotice() {
        let soon = upcoming(in: 11 * hour + 59 * minute)

        let derived = NoticeCenter.derived(bedtimeOn: false, upcoming: soon, onBattery: false, now: now)

        #expect(derived == [.bedtimeOffWithAlarmSoon(soon)])
    }

    @Test func anAlarmExactlyAtTheEdgeOfTheWindowStillCounts() {
        let edge = upcoming(in: NoticeCenter.bedtimeWarningWindow)

        #expect(
            NoticeCenter.derived(bedtimeOn: false, upcoming: edge, onBattery: false, now: now)
                == [.bedtimeOffWithAlarmSoon(edge)])
    }

    @Test func anAlarmJustOutsideTheWindowGivesNoNotice() {
        let later = upcoming(in: 12 * hour + minute)

        #expect(NoticeCenter.derived(bedtimeOn: false, upcoming: later, onBattery: false, now: now).isEmpty)
    }

    @Test func bedtimeOnGivesNoBedtimeOffNotice() {
        let soon = upcoming(in: hour)

        #expect(NoticeCenter.derived(bedtimeOn: true, upcoming: soon, onBattery: false, now: now).isEmpty)
    }

    @Test func noUpcomingOccurrenceGivesNoBedtimeOffNotice() {
        #expect(NoticeCenter.derived(bedtimeOn: false, upcoming: nil, onBattery: false, now: now).isEmpty)
    }

    @Test func theBatteryNoticeNeedsBedtimeOn() {
        #expect(
            NoticeCenter.derived(bedtimeOn: true, upcoming: nil, onBattery: true, now: now) == [.bedtimeOnBattery])
        #expect(NoticeCenter.derived(bedtimeOn: false, upcoming: nil, onBattery: true, now: now).isEmpty)
        #expect(NoticeCenter.derived(bedtimeOn: true, upcoming: nil, onBattery: false, now: now).isEmpty)
    }

    @Test func bedtimeOffOnBatteryGivesOnlyTheBedtimeOffNotice() {
        let soon = upcoming(in: hour)

        #expect(
            NoticeCenter.derived(bedtimeOn: false, upcoming: soon, onBattery: true, now: now)
                == [.bedtimeOffWithAlarmSoon(soon)])
    }
}
