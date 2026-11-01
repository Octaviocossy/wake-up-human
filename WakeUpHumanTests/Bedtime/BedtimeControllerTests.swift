import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct BedtimeControllerTests {
    private let suite = TestDefaults()
    private let rain = RainPlayerFake()
    private let assertion = PowerAssertionStub()
    private let controller: BedtimeController

    init() {
        controller = BedtimeController(
            rain: rain, assertion: assertion, settings: BedtimeSettings(defaults: suite.defaults))
    }

    // MARK: Turning on and off

    @Test func bedtimeStartsOffWithNothingHeldAndNothingPlaying() {
        #expect(!controller.isOn)
        #expect(!assertion.isHeld)
        #expect(assertion.acquireCount == 0)
        #expect(rain.startCount == 0)
    }

    @Test func turningOnAcquiresOnceStartsTheRainOnceAndSetsIsOn() {
        controller.turnOn()

        #expect(controller.isOn)
        #expect(assertion.acquireCount == 1)
        #expect(assertion.isHeld)
        #expect(rain.startCount == 1)
        #expect(rain.isPlaying)
    }

    @Test func turningOnWhileOnDoesNothing() {
        controller.turnOn()
        controller.turnOn()

        #expect(assertion.acquireCount == 1)
        #expect(rain.startCount == 1)
    }

    @Test func turningOffStopsTheRainAndReleasesTheAssertion() {
        controller.turnOn()

        controller.turnOff()

        #expect(!controller.isOn)
        #expect(rain.stopCount == 1)
        #expect(!rain.isPlaying)
        #expect(assertion.releaseCount == 1)
        #expect(!assertion.isHeld)
    }

    @Test func aSecondTurnOffDoesNothing() {
        controller.turnOn()
        controller.turnOff()

        controller.turnOff()

        #expect(rain.stopCount == 1)
        #expect(assertion.releaseCount == 1)
    }

    @Test func turningOffWhenNeverOnTouchesNothing() {
        controller.turnOff()

        #expect(rain.stopCount == 0)
        #expect(assertion.releaseCount == 0)
    }

    @Test func bedtimeCanBeTurnedOnAgainAfterBeingTurnedOff() {
        controller.turnOn()
        controller.turnOff()

        controller.turnOn()

        #expect(controller.isOn)
        #expect(assertion.isHeld)
        #expect(rain.startCount == 2)
    }

    // MARK: Refusals and failures

    @Test func aRefusedAssertionLeavesBedtimeOffAndNeverStartsTheRain() {
        assertion.acquireSucceeds = false

        controller.turnOn()

        #expect(!controller.isOn)
        #expect(!assertion.isHeld)
        #expect(rain.startCount == 0)
    }

    @Test func aRefusedAssertionCanBeRetriedOnceTheSystemAllowsIt() {
        assertion.acquireSucceeds = false
        controller.turnOn()
        assertion.acquireSucceeds = true

        controller.turnOn()

        #expect(controller.isOn)
        #expect(assertion.isHeld)
        #expect(rain.isPlaying)
    }

    @Test func aRainThatFailsToStartKeepsBedtimeOnWithTheAssertionHeld() {
        rain.startError = RainPlayerFake.StartFailure()

        controller.turnOn()

        #expect(controller.isOn)
        #expect(assertion.isHeld)
        #expect(rain.startCount == 1)
        #expect(!rain.isPlaying)
    }

    @Test func turningOffAfterAFailedRainStartStillReleasesTheAssertion() {
        rain.startError = RainPlayerFake.StartFailure()
        controller.turnOn()

        controller.turnOff()

        #expect(!controller.isOn)
        #expect(!assertion.isHeld)
    }

    // MARK: The assertion is held exactly while Bedtime is on (invariant 6)

    @Test func theAssertionIsHeldExactlyWhileBedtimeIsOn() {
        #expect(!assertion.isHeld)
        controller.turnOn()
        #expect(assertion.isHeld == controller.isOn)
        controller.turnOff()
        #expect(assertion.isHeld == controller.isOn)
        #expect(!assertion.isHeld)
    }

    // MARK: Rain volume

    @Test func theRainVolumeStartsAtTheStoredValueAndIsAppliedToTheRainAtInit() {
        let suite = TestDefaults()
        BedtimeSettings(defaults: suite.defaults).rainVolume = 0.35
        let rain = RainPlayerFake()

        let controller = BedtimeController(
            rain: rain, assertion: PowerAssertionStub(), settings: BedtimeSettings(defaults: suite.defaults))

        #expect(controller.rainVolume == 0.35)
        #expect(rain.volume == 0.35)
    }

    @Test func theRainVolumeDefaultsToSixtyPercent() {
        #expect(controller.rainVolume == 0.6)
        #expect(rain.volume == 0.6)
    }

    @Test func changingTheRainVolumePersistsItAndSetsTheRainVolume() {
        controller.rainVolume = 0.8

        #expect(rain.volume == 0.8)
        #expect(BedtimeSettings(defaults: suite.defaults).rainVolume == 0.8)
    }

    @Test func theRainVolumeIsClamped() {
        controller.rainVolume = 1.7

        #expect(controller.rainVolume == 1)
        #expect(rain.volume == 1)
        #expect(BedtimeSettings(defaults: suite.defaults).rainVolume == 1)
    }

    @Test func theRainVolumeCanBeChangedWhileBedtimeIsOff() {
        controller.rainVolume = 0.2

        #expect(!controller.isOn)
        #expect(rain.volume == 0.2)
        #expect(rain.startCount == 0)
    }

    // MARK: A Ring replaces Bedtime (spec decision 9)

    @Test func endingForARingStopsTheRainAndReleasesTheAssertion() {
        controller.turnOn()

        controller.endForRing()

        #expect(!controller.isOn)
        #expect(rain.stopCount == 1)
        #expect(assertion.releaseCount == 1)
        #expect(!assertion.isHeld)
    }

    @Test func endingForARingWhileOffDoesNothing() {
        controller.endForRing()

        #expect(rain.stopCount == 0)
        #expect(assertion.releaseCount == 0)
    }

    @Test func aRingReplacesBedtimeAndItStaysOffAfterTheRingIsDismissed() throws {
        let start = TestCalendar.date(2026, 11, 2, 7)
        let challenge = TypingChallenge(words: ["mesa", "camino", "verde", "pan", "ventana", "nube"])
        let store = AlarmStore(defaults: suite.defaults)
        let alarm = store.add(time: TimeOfDay(hour: 7, minute: 0), weekdays: [])
        let ringAssertion = PowerAssertionStub()
        let window = RingWindowSpy()
        let ringController = RingController(
            alarmStore: store,
            tone: SoundPlayerFake(),
            volume: RingVolumeController(
                volume: SystemVolumeFake(
                    currentSnapshot: VolumeSnapshot(deviceUID: "speaker-uid", volume: 0.35, isMuted: false)),
                ticker: TickerSpy(),
                defaults: suite.defaults
            ),
            displayAssertion: ringAssertion,
            displayWaker: DisplayWakerSpy(),
            window: window,
            capDeadline: DeadlineSchedulerSpy(),
            makeChallenge: { challenge },
            calendar: TestCalendar.utc,
            currentDate: { start }
        )
        ringController.onRingStarted = { [controller] in controller.endForRing() }
        controller.turnOn()
        #expect(assertion.isHeld)
        #expect(rain.isPlaying)

        ringController.ring([Occurrence(alarmID: alarm.id, date: start)], now: start)

        #expect(ringController.isRinging)
        #expect(!controller.isOn)
        #expect(!assertion.isHeld)
        #expect(assertion.releaseCount == 1)
        #expect(!rain.isPlaying)
        #expect(rain.stopCount == 1)
        // The Ring holds its own display assertion, not Bedtime's.
        #expect(ringAssertion.isHeld)

        let presentation = try #require(window.shown.last)
        presentation.insert(challenge.target)

        #expect(!ringController.isRinging)
        #expect(!controller.isOn)
        #expect(!assertion.isHeld)
        #expect(!rain.isPlaying)
        #expect(assertion.acquireCount == 1)
        #expect(rain.startCount == 1)
    }
}
