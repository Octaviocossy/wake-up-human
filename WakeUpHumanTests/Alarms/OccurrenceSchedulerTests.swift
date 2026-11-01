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

    /// The clocks the scheduler reads on its own. A test sets the wall clock directly — it is read
    /// when a scheduled check runs or the store changes — and moves the monotonic clocks to say
    /// whether the Mac stayed awake or slept in between.
    @MainActor
    final class Clock {
        var now = TestCalendar.date(2026, 11, 2, 6)
        private(set) var monotonic = MonotonicReading(continuous: 0, uptime: 0)

        /// `seconds` pass with the Mac awake: both monotonic clocks advance.
        func passAwake(_ seconds: TimeInterval) {
            monotonic = MonotonicReading(
                continuous: monotonic.continuous + seconds, uptime: monotonic.uptime + seconds)
        }

        /// The Mac spends `seconds` in System sleep: only the continuous clock advances.
        func sleep(_ seconds: TimeInterval) {
            monotonic = MonotonicReading(continuous: monotonic.continuous + seconds, uptime: monotonic.uptime)
        }
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
                monotonicClock: { [clock] in clock.monotonic }
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

        /// The wall-clock timer runs its scheduled check at `date`.
        func runScheduledCheck(at date: Date) {
            clock.now = date
            spy.runScheduledAction()
        }

        /// Before System sleep at `asleepAt`, for `seconds`, without the wake reaching the scheduler.
        func sleep(at asleepAt: Date, for seconds: TimeInterval) {
            scheduler.systemWillSleep(now: asleepAt)
            clock.sleep(seconds)
        }
    }

    private let everyDay = Set(Weekday.allCases)
    // 2026-11-02 is a Monday.
    private let sevenAM = TestCalendar.date(2026, 11, 2, 7)

    private func missed(_ alarm: Alarm, at date: Date, _ cause: MissedCause) -> [[MissedOccurrence]] {
        [[MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: date), cause: cause)]]
    }

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

        fixture.clock.passAwake(3600)
        fixture.runScheduledCheck(at: sevenAM)

        #expect(fixture.recorder.due == [[Occurrence(alarmID: alarm.id, date: sevenAM)]])
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aScheduledCheckWithinTheToleranceIsDue() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.clock.passAwake(3629)
        fixture.runScheduledCheck(at: sevenAM.addingTimeInterval(29))

        #expect(fixture.recorder.due.count == 1)
        #expect(fixture.recorder.missed.isEmpty)
    }

    @Test func aScheduledCheckPastTheToleranceIsMissedBecauseItRanLate() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // The Mac stayed awake; the app's check simply ran 31 s late.
        fixture.clock.passAwake(3631)
        fixture.runScheduledCheck(at: sevenAM.addingTimeInterval(31))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .checkRanLate))
    }

    @Test func aScheduledCheckHoursAfterSystemSleepIsMissedNotRung() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // The Mac slept through 07:00; the wall-clock timer runs its check on wake, an hour late.
        fixture.clock.sleep(2 * 3600)
        fixture.runScheduledCheck(at: TestCalendar.date(2026, 11, 2, 8))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .systemSleep))
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aScheduledCheckSecondsAfterSystemSleepIsMissedNotRung() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))
        fixture.clock.passAwake(3590)

        // Asleep from 06:59:50 to 07:00:15; the timer's check reaches the app before the wake does.
        fixture.sleep(at: TestCalendar.date(2026, 11, 2, 6, 59, 50), for: 25)
        fixture.runScheduledCheck(at: TestCalendar.date(2026, 11, 2, 7, 0, 15))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .systemSleep))
    }

    @Test func aWakeReportsWhatFellDueDuringSleepAsMissedHoweverRecently() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))
        fixture.clock.passAwake(3590)

        // Asleep from 06:59:50 to 07:00:15: 07:00 fell during the sleep, only 15 s ago.
        fixture.sleep(at: TestCalendar.date(2026, 11, 2, 6, 59, 50), for: 25)
        fixture.scheduler.systemDidWake(now: TestCalendar.date(2026, 11, 2, 7, 0, 15))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .systemSleep))
    }

    @Test func aScheduledCheckAfterTheWakeWasReportedRingsOnTime() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 1, 22))
        fixture.clock.passAwake(3600)

        // Asleep from 23:00 to 06:00, then awake until the 07:00 check.
        fixture.sleep(at: TestCalendar.date(2026, 11, 1, 23), for: 7 * 3600)
        fixture.scheduler.systemDidWake(now: TestCalendar.date(2026, 11, 2, 6))
        fixture.clock.passAwake(3600)
        fixture.runScheduledCheck(at: sevenAM)

        #expect(fixture.recorder.due == [[Occurrence(alarmID: alarm.id, date: sevenAM)]])
        #expect(fixture.recorder.missed.isEmpty)
    }

    @Test func aLaunchReportsWhatFellDueWhileTheAppWasClosedAsMissedHoweverRecently() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 1, 23))  // the app is closed after this

        // Relaunched at 07:00:20: 07:00 passed only 20 s ago, but the app was not running then.
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 7, 0, 20))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .appNotRunning))
    }

    @Test func aOneTimeAlarmDisarmsAfterItsDueOccurrence() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.clock.passAwake(3600)
        fixture.runScheduledCheck(at: sevenAM)

        #expect(fixture.recorder.due.count == 1)
        #expect(try #require(fixture.store.alarms.first).isArmed == false)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func aOneTimeAlarmDisarmsAfterAMissedOccurrenceToo() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.sleep(at: TestCalendar.date(2026, 11, 2, 6, 30), for: 9000)
        fixture.scheduler.systemDidWake(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.count == 1)
        #expect(try #require(fixture.store.alarms.first).isArmed == false)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func aDisarmedAlarmNeverYieldsAnOccurrence() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay, isArmed: false)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.clock.passAwake(3600)
        fixture.sleep(at: sevenAM, for: 7200)
        fixture.scheduler.systemDidWake(now: TestCalendar.date(2026, 11, 2, 9))

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
        fixture.clock.passAwake(60)
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
        fixture.clock.passAwake(3600)

        // Ten hours of System sleep; on wake the clock is resynced before the wake is delivered.
        fixture.sleep(at: TestCalendar.date(2026, 11, 1, 23), for: 10 * 3600)
        fixture.scheduler.clockDidChange(now: TestCalendar.date(2026, 11, 2, 9, 0, 2))
        fixture.scheduler.systemDidWake(now: TestCalendar.date(2026, 11, 2, 9, 0, 3))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .systemSleep))
    }

    @Test func aClockChangeSecondsAfterSystemSleepNeverRingsWhatWasSleptThrough() throws {
        let alarm = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let fixture = try Fixture(alarms: [alarm])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))
        fixture.clock.passAwake(3590)

        // Asleep from 06:59:50 to 07:00:15; the clock change reaches the app before the wake does.
        fixture.sleep(at: TestCalendar.date(2026, 11, 2, 6, 59, 50), for: 25)
        fixture.scheduler.clockDidChange(now: TestCalendar.date(2026, 11, 2, 7, 0, 15))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .systemSleep))
    }

    @Test func alarmsDueInTheSameMinuteArriveInOneCall() throws {
        let first = TestCalendar.alarm(7, 0, weekdays: everyDay)
        let second = TestCalendar.alarm(7, 0, weekdays: [.monday])
        let fixture = try Fixture(alarms: [first, second])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.clock.passAwake(3600)
        fixture.runScheduledCheck(at: sevenAM)

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
        fixture.clock.passAwake(3600)

        // Asleep from Sunday 23:00 to Thursday 09:00.
        fixture.sleep(at: TestCalendar.date(2026, 11, 1, 23), for: 82 * 3600)
        fixture.scheduler.systemDidWake(now: TestCalendar.date(2026, 11, 5, 9))

        #expect(fixture.recorder.missed == missed(alarm, at: sevenAM, .systemSleep))
    }

    @Test func evaluatingPersistsTheInstantItRan() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        let now = TestCalendar.date(2026, 11, 2, 6)

        fixture.scheduler.start(now: now)
        #expect(fixture.lastEvaluatedAt == now)

        fixture.clock.passAwake(3600)
        fixture.runScheduledCheck(at: sevenAM)
        #expect(fixture.lastEvaluatedAt == sevenAM)
    }

    @Test func theLastEvaluationIsPersistedBeforeTheCallbacksRun() throws {
        let fixture = try Fixture(alarms: [TestCalendar.alarm(7, 0, weekdays: everyDay)])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))
        var seenInCallback: Date?
        fixture.scheduler.onDue = { _ in seenInCallback = fixture.lastEvaluatedAt }

        fixture.clock.passAwake(3600)
        fixture.runScheduledCheck(at: sevenAM)

        #expect(seenInCallback == sevenAM)
    }
}
