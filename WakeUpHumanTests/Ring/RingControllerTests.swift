import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct RingControllerTests {
    /// What the Ring controller reports and draws, and the clock it reads when the window or the cap
    /// timer calls back.
    @MainActor
    final class Recorder {
        var now: Date
        var startedCount = 0
        var outcomes: [RingOutcome] = []
        var challengesDrawn = 0

        init(now: Date) {
            self.now = now
        }
    }

    private let suite = TestDefaults()
    private let start = TestCalendar.date(2026, 11, 2, 7)
    private let userVolume = VolumeSnapshot(deviceUID: "speaker-uid", volume: 0.35, isMuted: true)
    private let challenge = TypingChallenge(words: ["mesa", "camino", "verde", "pan", "ventana", "nube"])

    private let store: AlarmStore
    private let tone = SoundPlayerFake()
    private let systemVolume: SystemVolumeFake
    private let ticker = TickerSpy()
    private let ringVolume: RingVolumeController
    private let assertion = PowerAssertionStub()
    private let waker = DisplayWakerSpy()
    private let window = RingWindowSpy()
    private let cap = DeadlineSchedulerSpy()
    private let recorder: Recorder
    private let controller: RingController
    /// The Occurrences of an Alarm at 07:00 and one at 07:05, the same morning.
    private let seven: Occurrence
    private let sevenFive: Occurrence

    init() {
        store = AlarmStore(defaults: suite.defaults)
        let sevenAlarm = store.add(time: TimeOfDay(hour: 7, minute: 0), weekdays: [])
        let sevenFiveAlarm = store.add(time: TimeOfDay(hour: 7, minute: 5), weekdays: [])
        seven = Occurrence(alarmID: sevenAlarm.id, date: start)
        sevenFive = Occurrence(alarmID: sevenFiveAlarm.id, date: TestCalendar.date(2026, 11, 2, 7, 5))

        systemVolume = SystemVolumeFake(currentSnapshot: userVolume)
        ringVolume = RingVolumeController(volume: systemVolume, ticker: ticker, defaults: suite.defaults)
        let recorder = Recorder(now: start)
        let challenge = challenge
        controller = RingController(
            alarmStore: store,
            tone: tone,
            volume: ringVolume,
            displayAssertion: assertion,
            displayWaker: waker,
            window: window,
            capDeadline: cap,
            makeChallenge: {
                recorder.challengesDrawn += 1
                return challenge
            },
            calendar: TestCalendar.utc,
            currentDate: { recorder.now }
        )
        controller.onRingStarted = { recorder.startedCount += 1 }
        controller.onRingEnded = { recorder.outcomes.append($0) }
        self.recorder = recorder
    }

    /// Types the whole target into the Ring window at `now`, as the user would.
    private func solve(at now: Date) throws {
        recorder.now = now
        let presentation = try #require(window.shown.last)
        presentation.insert(challenge.target)
    }

    // MARK: Starting a Ring

    @Test func startingARingShowsOneWindowWithTheAlarmTimeAndStartsTheToneOnce() throws {
        controller.ring([seven], now: start)

        let presentation = try #require(window.shown.first)
        #expect(window.shown.count == 1)
        #expect(presentation.alarmTimes == ["07:00"])
        #expect(presentation.challenge == challenge)
        #expect(presentation.startedAt == start)
        #expect(tone.startCount == 1)
        #expect(tone.isPlaying)
        #expect(recorder.startedCount == 1)
        #expect(controller.isRinging)
        #expect(controller.session?.occurrences == [seven])
    }

    @Test func startingARingWakesTheDisplayAndHoldsTheDisplayAssertion() {
        controller.ring([seven], now: start)

        #expect(waker.wakeCount == 1)
        #expect(assertion.acquireCount == 1)
        #expect(assertion.isHeld)
    }

    @Test func startingARingUnmutesAndStartsTheRamp() throws {
        controller.ring([seven], now: start)

        let presentation = try #require(window.shown.first)
        #expect(systemVolume.setMutedCalls.contains(false))
        #expect(ticker.isRunning)
        #expect(presentation.volume == .ramping(percent: 35, secondsToMax: 30))
    }

    @Test func startingARingSchedulesTheCapAnHourLater() throws {
        controller.ring([seven], now: start)

        let presentation = try #require(window.shown.first)
        #expect(cap.currentDeadline == start.addingTimeInterval(3_600))
        #expect(presentation.capEndsAt == start.addingTimeInterval(3_600))
    }

    @Test func theWindowFollowsTheVolumeRamp() throws {
        controller.ring([seven], now: start)

        ringVolume.tick(now: start.addingTimeInterval(12))

        let presentation = try #require(window.shown.first)
        #expect(presentation.volume == .ramping(percent: 61, secondsToMax: 18))
    }

    @Test func ringingWithNoOccurrencesStartsNothing() {
        controller.ring([], now: start)

        #expect(!controller.isRinging)
        #expect(window.shown.isEmpty)
        #expect(tone.startCount == 0)
        #expect(recorder.startedCount == 0)
    }

    @Test func aDeletedAlarmShowsItsOccurrenceTime() throws {
        let orphan = Occurrence(alarmID: UUID(), date: TestCalendar.date(2026, 11, 2, 6, 45))

        controller.ring([orphan], now: start)

        let presentation = try #require(window.shown.first)
        #expect(presentation.alarmTimes == ["06:45"])
    }

    @Test func aRefusedDisplayAssertionStillRings() {
        assertion.acquireSucceeds = false

        controller.ring([seven], now: start)

        #expect(window.shown.count == 1)
        #expect(tone.isPlaying)
        #expect(cap.currentDeadline != nil)
    }

    @Test func aToneThatFailsToStartStillShowsTheWindowAndSchedulesTheCap() {
        tone.startError = SoundPlayerFake.StartFailure()

        controller.ring([seven], now: start)

        #expect(window.shown.count == 1)
        #expect(cap.currentDeadline == start.addingTimeInterval(3_600))
        #expect(controller.isRinging)
    }

    // MARK: Joining

    @Test func anOccurrenceDueDuringARingJoinsIt() throws {
        controller.ring([seven], now: start)

        controller.ring([sevenFive], now: start.addingTimeInterval(300))

        let presentation = try #require(window.shown.first)
        #expect(window.shown.count == 1)
        #expect(tone.startCount == 1)
        #expect(presentation.alarmTimes == ["07:00", "07:05"])
        #expect(recorder.startedCount == 1)
        #expect(cap.scheduledDeadlines == [start.addingTimeInterval(3_600)])
        #expect(controller.session?.occurrences == [seven, sevenFive])
    }

    // MARK: Dismiss

    @Test func solvingTheChallengeDismissesTheRingAndGivesEverythingBack() throws {
        controller.ring([seven], now: start)
        controller.ring([sevenFive], now: start.addingTimeInterval(300))

        try solve(at: start.addingTimeInterval(395))

        #expect(tone.stopCount == 1)
        #expect(!tone.isPlaying)
        #expect(systemVolume.restoredSnapshots == [userVolume])
        #expect(assertion.releaseCount == 1)
        #expect(!assertion.isHeld)
        #expect(waker.releaseCount == 1)
        #expect(cap.currentDeadline == nil)
        #expect(window.dismissedWith == [395])
        #expect(window.closeCount == 0)
        #expect(
            recorder.outcomes == [
                .dismissed(
                    occurrences: [seven, sevenFive], startedAt: start, endedAt: start.addingTimeInterval(395))
            ])
        #expect(!controller.isRinging)
    }

    @Test func dismissBeforeTheChallengeIsSolvedDoesNothing() throws {
        controller.ring([seven], now: start)
        let presentation = try #require(window.shown.first)
        presentation.insert("mesa cam")

        controller.dismiss(now: start.addingTimeInterval(30))

        #expect(controller.isRinging)
        #expect(tone.isPlaying)
        #expect(window.dismissedWith.isEmpty)
        #expect(recorder.outcomes.isEmpty)
    }

    @Test func aRingAfterADismissedOneDrawsAFreshChallenge() throws {
        controller.ring([seven], now: start)
        try solve(at: start.addingTimeInterval(60))

        controller.ring([sevenFive], now: start.addingTimeInterval(300))

        #expect(recorder.challengesDrawn == 2)
        #expect(window.shown.count == 2)
        #expect(window.shown.last?.typed == "")
        #expect(recorder.startedCount == 2)
        #expect(controller.session?.occurrences == [sevenFive])
    }

    // MARK: Unattended cap

    @Test func theCapEndsAnUnattendedRingWithoutAConfirmation() {
        controller.ring([seven], now: start)
        recorder.now = start.addingTimeInterval(3_600)

        cap.runScheduledAction()

        #expect(!tone.isPlaying)
        #expect(systemVolume.restoredSnapshots == [userVolume])
        #expect(assertion.releaseCount == 1)
        #expect(!assertion.isHeld)
        #expect(waker.releaseCount == 1)
        #expect(cap.currentDeadline == nil)
        #expect(window.closeCount == 1)
        #expect(window.dismissedWith.isEmpty)
        #expect(
            recorder.outcomes == [
                .unattended(occurrences: [seven], startedAt: start, endedAt: start.addingTimeInterval(3_600))
            ])
        #expect(!controller.isRinging)
    }

    @Test func aCapCheckBeforeTheCapWaitsForItAgain() {
        controller.ring([seven], now: start)
        recorder.now = start.addingTimeInterval(1_800)

        cap.runScheduledAction()

        #expect(controller.isRinging)
        #expect(tone.isPlaying)
        #expect(cap.currentDeadline == start.addingTimeInterval(3_600))
        #expect(recorder.outcomes.isEmpty)
    }

    // MARK: Nothing else ends a Ring

    @Test func dismissAndCapReachedDoNothingWhenNotRinging() {
        controller.dismiss(now: start)
        controller.capReached(now: start.addingTimeInterval(3_600))

        #expect(recorder.outcomes.isEmpty)
        #expect(tone.stopCount == 0)
        #expect(systemVolume.restoredSnapshots.isEmpty)
        #expect(assertion.releaseCount == 0)
        #expect(waker.releaseCount == 0)
        #expect(window.dismissedWith.isEmpty)
        #expect(window.closeCount == 0)
    }

    @Test func terminatingDuringARingGivesBackTheVolumeAndPowerWithoutEndingIt() {
        controller.ring([seven], now: start)

        controller.applicationWillTerminate()

        #expect(!tone.isPlaying)
        #expect(systemVolume.restoredSnapshots == [userVolume])
        #expect(assertion.releaseCount == 1)
        #expect(!assertion.isHeld)
        #expect(waker.releaseCount == 1)
        #expect(cap.currentDeadline == nil)
        #expect(recorder.outcomes.isEmpty)
    }
}
