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

    /// What `alarmsDidChange` reads as "now" when the store changes; a test moves it.
    @MainActor
    final class Clock {
        var now = Date()
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

        init() {
            store = AlarmStore(defaults: suite.defaults)
            scheduler = OccurrenceScheduler(
                store: store,
                deadlines: spy,
                calendar: OccurrenceCalendar(calendar: TestCalendar.utc),
                defaults: suite.defaults,
                currentDate: { [clock] in clock.now }
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

    // 2026-11-02 is a Monday.
    private let sevenAM = TestCalendar.date(2026, 11, 2, 7)

    @Test func firstLaunchReportsNothingAndSchedulesTheNextOccurrence() {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: [])

        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == sevenAM)
    }

    @Test func theWakeAtTheDueInstantReportsTheOccurrenceAndSchedulesTheNext() {
        let fixture = Fixture()
        let alarm = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.clock.now = sevenAM
        fixture.spy.deliverWake()

        #expect(fixture.recorder.due == [[Occurrence(alarmID: alarm.id, date: sevenAM)]])
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aWakeThatFiresHoursLateAfterSystemSleepIsMissedNotRung() {
        let fixture = Fixture()
        let alarm = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // The Mac slept through 07:00; the wall-clock timer fires on wake, an hour late.
        fixture.clock.now = TestCalendar.date(2026, 11, 2, 8)
        fixture.spy.deliverWake()

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .systemSleep)]
            ])
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func anOccurrenceSeenWithinTheToleranceIsDue() {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM.addingTimeInterval(29))

        #expect(fixture.recorder.due.count == 1)
        #expect(fixture.recorder.missed.isEmpty)
    }

    @Test func anOccurrenceSeenAfterTheToleranceIsMissedAndNeverDue() throws {
        let fixture = Fixture()
        let alarm = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM.addingTimeInterval(31))

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .systemSleep)]
            ])
    }

    @Test func anOccurrenceThatPassedWhileTheAppWasClosedIsMissedWithThatCause() {
        let fixture = Fixture()
        let alarm = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 1, 23))  // the app is closed after this

        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(
            fixture.recorder.missed == [
                [MissedOccurrence(occurrence: Occurrence(alarmID: alarm.id, date: sevenAM), cause: .appNotRunning)]
            ])
    }

    @Test func aOneTimeAlarmDisarmsAfterItsDueOccurrence() throws {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: [])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM)

        #expect(fixture.recorder.due.count == 1)
        #expect(try #require(fixture.store.alarms.first).isArmed == false)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func aOneTimeAlarmDisarmsAfterAMissedOccurrenceToo() throws {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: [])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.count == 1)
        #expect(try #require(fixture.store.alarms.first).isArmed == false)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func aDisarmedAlarmNeverYieldsAnOccurrence() {
        let fixture = Fixture()
        let alarm = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.store.setArmed(false, id: alarm.id)
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM)
        fixture.scheduler.evaluate(now: TestCalendar.date(2026, 11, 2, 9))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == nil)
    }

    @Test func anEditNeverLooksBack() {
        let fixture = Fixture()
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // 07:00:10: an Alarm for 07:00 is added ten seconds after its time.
        fixture.clock.now = sevenAM.addingTimeInterval(10)
        fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func aClockChangeNeverLooksBack() {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        // The clock is set from 06:00 to 07:30: the 07:00 Occurrence is not reported.
        fixture.scheduler.clockDidChange(now: TestCalendar.date(2026, 11, 2, 7, 30))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.isEmpty)
        #expect(fixture.spy.currentDeadline == TestCalendar.date(2026, 11, 3, 7))
    }

    @Test func alarmsDueInTheSameMinuteArriveInOneCall() {
        let fixture = Fixture()
        let first = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        let second = fixture.store.add(hour: 7, minute: 0, weekdays: [.monday])
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))

        fixture.scheduler.evaluate(now: sevenAM)

        #expect(fixture.recorder.due.count == 1)
        #expect(Set(fixture.recorder.due[0].map(\.alarmID)) == [first.id, second.id])
    }

    @Test func aLongAbsenceYieldsAtMostOneMissedOccurrencePerAlarm() {
        let fixture = Fixture()
        let alarm = fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 10, 23, 12))  // ten days before

        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 12))

        #expect(fixture.recorder.due.isEmpty)
        #expect(fixture.recorder.missed.count == 1)
        #expect(fixture.recorder.missed[0].map(\.occurrence.alarmID) == [alarm.id])
    }

    @Test func evaluatingPersistsTheInstantItRan() {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        let now = TestCalendar.date(2026, 11, 2, 6)

        fixture.scheduler.start(now: now)
        #expect(fixture.lastEvaluatedAt == now)

        fixture.scheduler.evaluate(now: sevenAM)
        #expect(fixture.lastEvaluatedAt == sevenAM)
    }

    @Test func theLastEvaluationIsPersistedBeforeTheCallbacksRun() {
        let fixture = Fixture()
        fixture.store.add(hour: 7, minute: 0, weekdays: Set(Weekday.allCases))
        fixture.scheduler.start(now: TestCalendar.date(2026, 11, 2, 6))
        var seenInCallback: Date?
        fixture.scheduler.onDue = { _ in seenInCallback = fixture.lastEvaluatedAt }

        fixture.scheduler.evaluate(now: sevenAM)

        #expect(seenInCallback == sevenAM)
    }
}
