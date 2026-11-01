import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct OccurrenceSchedulerTests {
    /// Collects what the scheduler reports.
    @MainActor
    final class Recorder {
        var due: [[Occurrence]] = []
        var missed: [[MissedOccurrence]] = []
    }

    /// The clocks the scheduler reads on its own: the wall clock when a scheduled check runs or the
    /// store changes, and the continuous clock — which counts through System sleep and ignores
    /// clock changes — on a clock change. A test moves them.
    @MainActor
    final class Clock {
        var now = TestCalendar.date(2026, 11, 2, 6)
        var continuous: TimeInterval = 0
    }

    /// Everything one test needs: a store, a spy timer, a scheduler and its recorder, all on a
    /// throwaway `UserDefaults` suite and a fixed UTC calendar.
    @MainActor
    struct Fixture {
        let suite = TestDefaults()
        let store: AlarmStore
        let spy = DeadlineSchedulerSpy()
        let scheduler: OccurrenceScheduler
        let recorder = Recorder()
        let clock = Clock()

        /// `alarms` are already saved when the app launches, so they never reach the scheduler as an
        /// edit and no evaluation is stored before the test's own.
        init(alarms: [Alarm] = []) throws {
            if !alarms.isEmpty {
                suite.defaults.set(try JSONEncoder().encode(alarms), forKey: AlarmStore.defaultsKey)
            }
            store = AlarmStore(defaults: suite.defaults)
            scheduler = OccurrenceScheduler(
                store: store,
                deadlines: spy,
                calendar: OccurrenceCalendar(calendar: TestCalendar.utc),
                defaults: suite.defaults,
                currentDate: { [clock] in clock.now },
                continuousTime: { [clock] in clock.continuous }
            )
            let recorder = recorder
            scheduler.onDue = { recorder.due.append($0) }
            scheduler.onMissed = { recorder.missed.append($0) }
            let scheduler = scheduler
            let clock = clock
            store.onChange = { scheduler.alarmsDidChange(now: clock.now) }
        }

        var lastEvaluatedAt: Date? {
            suite.defaults.object(forKey: OccurrenceScheduler.lastEvaluatedKey) as? Date
        }
    }

    private let everyDay = Set(Weekday.allCases)
    // 2026-11-02 is a Monday.
    private let sevenAM = TestCalendar.date(2026, 11, 2, 7)

    @Test func firstLaunchReportsNothingAndSchedulesTheNextOccurrence() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        #expect(fixture.lastEvaluatedAt == nil)

        // Today's 07:00 has already passed, but a first launch has no window to look back over.
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func theCheckAtTheDueInstantReportsTheOccurrenceAndSchedulesTheNext() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.clock.now = sevenAM
        fixture.spy.runScheduledAction()

        #expect(fixture.recorder.due == [[Occurrence(alarmID: alarm.id, date: sevenAM)]])
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aCheckThatRunsHoursLateAfterSystemSleepIsMissedNotRung() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // The Mac slept through 07:00; the wall-clock timer runs its check on wake, an hour late.
        fixture.clock.now = TestCalendar.date(2026, 11, 2, 8)
        fixture.spy.runScheduledAction()

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .systemSleep)]
            ])
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func anOccurrenceSeenWithinTheToleranceIsDue() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM.addingTimeInterval(29))

        #expect(fixture.recorder.due.count == 1)
        #expect(fixture.recorder.missed.isEmpty)
    }

    @Test func anOccurrenceSeenAfterTheToleranceIsMissedAndNeverDue() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM.addingTimeInterval(31))

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .systemSleep)]
            ])
    }

    @Test func anOccurrenceThatPassedWhileTheAppWasClosedIsMissedWithThatCause() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 1, 23))  // the app is closed after this

        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .appNotRunning)]
            ])
    }

    @Test func aOneTimeAlarmDisarmsAfterItsDueOccurrence() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM)

        #expect(fixture.recorder.due.count == 1)
        #expect(try #require(fixture.store.alarms.first).isArmed == false)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func aOneTimeAlarmDisarmsAfterAMissedOccurrenceToo() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.count == 1)
        #expect(try #require(fixture.store.alarms.first).isArmed == false)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func aDisarmedAlarmNeverYieldsAnOccurrence() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay, isArmed: false)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM)
        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func anEditNeverLooksBack() throws {
        let fixture = try Fixture()
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // 07:00:10: an Alarm for 07:00 is added ten seconds after its time.
        fixture.clock.now = sevenAM.addingTimeInterval(10)
        fixture.store.add(time: TimeOfDay(hour: 7, minute: 0), weekdays: everyDay)

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aClockChangeNeverLooksBackOverTheTimeItSkipped() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // A minute later the clock is set from 06:01 to 07:30: the 07:00 it skipped is not reported.
        fixture.clock.continuous += 60
        fixture.scheduler.clockDidChange(now: TestCalendar.date(2026, 11, 2, 7, 30))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.lastEvaluatedAt == TestCalendar.date(2026, 11, 2, 7, 30))
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aClockChangeThatArrivesBeforeTheWakeStillReportsWhatWasSleptThrough() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 1, 22))
        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 1, 23))  // will-sleep

        // Ten hours of System sleep; on wake the clock is resynced before the wake is delivered.
        fixture.clock.continuous += 10 * 3600
        fixture.scheduler.clockDidChange(now: TestCalendar.date(2026, 11, 2, 9, 0, 2))
        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 2, 9, 0, 3), missedCause: .systemSleep)

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .systemSleep)]
            ])
    }

    @Test func alarmsDueInTheSameMinuteArriveInOneCall() throws {
        let first = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let second = TestCalendar.alarm(7, 0, weekdays: [.monday])
        let fixture = try Fixture(alarms: [first, second])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM)

        #expect(fixture.recorder.due.count == 1)
        #expect(Set(fixture.recorder.due[0].map(\.alarmID)) == [first.id, second.id])
    }

    @Test func aLongAbsenceReportsEveryMissedOccurrenceInOneCall() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 10, 23, 12))  // ten days before

        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 12))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.count == 1)
        #expect(
            fixture.recorder.missed.first?.map(\.occurrence.date)
                == (24...31).map { TestCalendar.date(2026, 10, $0, 7) }
                + (1...2).map { TestCalendar.date(2026, 11, $0, 7) })
    }

    @Test func anOccurrenceSleptThroughMoreThanADayAgoIsStillReported() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: [.monday])
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 1, 22))
        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 1, 23))  // will-sleep, Sunday

        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 5, 9), missedCause: .systemSleep)  // Thursday

        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .systemSleep)]
            ])
    }

    @Test func evaluatingPersistsTheInstantItRan() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        let now = TestCalendar.date(2026, 11, 2, 6)

        fixture.scheduler.start(now: now)
        #expect(fixture.lastEvaluatedAt == now)

        fixture.scheduler.evaluate(now: sevenAM)
        #expect(fixture.lastEvaluatedAt == sevenAM)
    }

    @Test func theLastEvaluationIsPersistedBeforeTheCallbacksRun() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))
        var seenInCallback: Date?
        fixture.scheduler.onDue = { _ in seenInCallback = fixture.lastEvaluatedAt }

        fixture.scheduler.evaluate(now: sevenAM)

        #expect(seenInCallback == sevenAM)
    }
}
