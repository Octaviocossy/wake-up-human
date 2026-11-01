import Foundation
import Observation

/// Owns the Ring lifecycle (glossary › Ring), from a due Occurrence to its end. A Ring ends only
/// through `dismiss` — its Typing challenge was solved — or `capReached` — its 60-minute unattended
/// cap ran out (invariant 4). No other method ends one, and none offers a snooze (spec decision 13).
///
/// While a Ring sounds it holds exactly two power calls, both released when it ends: a display
/// assertion that keeps the display on and a user-activity declaration that lights a dark one
/// (spec decision 3, invariant 6).
@MainActor
@Observable
final class RingController {
    /// The Ring sounding now; `nil` when none is.
    private(set) var session: RingSession?
    var isRinging: Bool { session != nil }

    /// Hooks for later slices: Bedtime ends when a Ring starts (#16); the status icon is redrawn and
    /// an unattended Ring is recorded when one ends (#17).
    @ObservationIgnored var onRingStarted: (@MainActor () -> Void)?
    @ObservationIgnored var onRingEnded: (@MainActor (RingOutcome) -> Void)?

    /// What the Ring window shows for the current Ring. Kept after a Dismiss until the next Ring.
    @ObservationIgnored private var presentation: RingPresentation?

    @ObservationIgnored private let alarmStore: AlarmStore
    @ObservationIgnored private let tone: SoundPlaying
    @ObservationIgnored private let volume: RingVolumeController
    @ObservationIgnored private let displayAssertion: PowerAssertionControlling
    @ObservationIgnored private let displayWaker: DisplayWaking
    @ObservationIgnored private let window: RingWindowPresenting
    @ObservationIgnored private let capDeadline: DeadlineScheduling
    @ObservationIgnored private let makeChallenge: @MainActor () -> TypingChallenge
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let currentDate: @MainActor () -> Date

    init(
        alarmStore: AlarmStore,
        tone: SoundPlaying,
        volume: RingVolumeController,
        displayAssertion: PowerAssertionControlling,
        displayWaker: DisplayWaking,
        window: RingWindowPresenting,
        capDeadline: DeadlineScheduling,
        makeChallenge: @escaping @MainActor () -> TypingChallenge,
        calendar: Calendar = .current,
        currentDate: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.alarmStore = alarmStore
        self.tone = tone
        self.volume = volume
        self.displayAssertion = displayAssertion
        self.displayWaker = displayWaker
        self.window = window
        self.capDeadline = capDeadline
        self.makeChallenge = makeChallenge
        self.calendar = calendar
        self.currentDate = currentDate
        // The ramp reports every step; the window shows it for the Ring sounding now.
        volume.onStateChange = { [weak self] state in
            self?.presentation?.volume = Self.volumeStatus(state)
        }
    }

    /// Starts a Ring for `occurrences`, or — while one sounds — lets them join it: one Ring at a time,
    /// and one Dismiss ends every Occurrence it covers (spec decision 15).
    func ring(_ occurrences: [Occurrence], now: Date) {
        guard !occurrences.isEmpty else { return }
        if var session {
            let added = session.join(occurrences)
            guard !added.isEmpty else { return }
            self.session = session
            presentation?.alarmTimes = alarmTimes(of: session)
            Log.ring.info("\(added.count) Occurrence(s) joined the Ring sounding now")
            return
        }
        start(RingSession(occurrences: occurrences, startedAt: now), now: now)
    }

    /// Ends the Ring because its Typing challenge was solved (glossary › Dismiss): the volume and mute
    /// go back to what they were (spec decision 16) and the window confirms it (spec decision 37).
    /// Does nothing unless a Ring is sounding **and** its challenge is solved — invariant 4.
    func dismiss(now: Date) {
        guard let session, let presentation, presentation.progress.isSolved else { return }
        tearDown()
        window.showDismissed(presentation, rangForSeconds: max(0, Int(now.timeIntervalSince(session.startedAt))))
        self.session = nil
        Log.ring.info("Ring Dismissed")
        onRingEnded?(.dismissed(occurrences: session.occurrences, startedAt: session.startedAt, endedAt: now))
    }

    /// Ends the Ring because nobody Dismissed it within its unattended cap (spec decision 14). The
    /// window closes with no confirmation: nobody is there to read it. Does nothing unless a Ring is
    /// sounding; a check that runs before the cap — the timer is never trusted — waits for it again.
    func capReached(now: Date) {
        guard let session else { return }
        guard now >= session.capEndsAt else {
            scheduleCap(at: session.capEndsAt)
            return
        }
        tearDown()
        window.close()
        self.session = nil
        Log.ring.notice("Ring stopped unattended after its cap")
        onRingEnded?(.unattended(occurrences: session.occurrences, startedAt: session.startedAt, endedAt: now))
    }

    /// The app is quitting (logout, shutdown) mid-Ring: give back the volume and release both power
    /// calls. Not an ending of the Ring, so `onRingEnded` is not called.
    func applicationWillTerminate() {
        guard isRinging else { return }
        tearDown()
        session = nil
        Log.ring.notice("The app terminated during a Ring")
    }

    // MARK: - Private

    private func start(_ session: RingSession, now: Date) {
        self.session = session
        // Bedtime's rain stops before the alarm sounds (#16).
        onRingStarted?()

        displayWaker.wake()
        if !displayAssertion.acquire() {
            Log.ring.error("The display assertion was refused; the display may sleep during the Ring")
        }
        // The volume is borrowed before the tone starts, so the tone never plays at a level the
        // snapshot has not recorded yet.
        volume.begin(now: now)
        do {
            try tone.start()
        } catch {
            // The window and the volume ramp still run: the Ring must stay Dismissable.
            Log.ring.fault("The alarm tone failed to start: \(String(describing: error), privacy: .public)")
        }

        let presentation = RingPresentation(
            challenge: makeChallenge(),
            alarmTimes: alarmTimes(of: session),
            startedAt: now,
            capEndsAt: session.capEndsAt
        )
        presentation.volume = Self.volumeStatus(volume.state)
        presentation.onSolved = { [weak self] in
            guard let self else { return }
            dismiss(now: currentDate())
        }
        self.presentation = presentation
        window.show(presentation)

        scheduleCap(at: session.capEndsAt)
        Log.ring.info("Ring started for \(session.occurrences.count) Occurrence(s)")
    }

    private func scheduleCap(at deadline: Date) {
        // The check reads the clock when it runs — the timer's own time is never trusted.
        capDeadline.schedule(at: deadline) { [weak self] in
            guard let self else { return }
            capReached(now: currentDate())
        }
    }

    /// Stops everything a Ring holds: the tone, the borrowed volume, both power calls and the cap.
    private func tearDown() {
        tone.stop()
        volume.end()
        displayAssertion.release()
        displayWaker.release()
        capDeadline.cancel()
    }

    /// The time of each Occurrence the Ring covers, in date order: its Alarm's time, or — if the
    /// Alarm was deleted meanwhile — the Occurrence's own time of day.
    private func alarmTimes(of session: RingSession) -> [String] {
        session.occurrences.map { occurrence in
            if let alarm = alarmStore.alarms.first(where: { $0.id == occurrence.alarmID }) {
                return AlarmFormatting.time(alarm.time)
            }
            let components = calendar.dateComponents([.hour, .minute], from: occurrence.date)
            return AlarmFormatting.time(TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0))
        }
    }

    private static func volumeStatus(_ state: RingVolumeController.State) -> VolumeStatus {
        switch state {
        case .idle: .unknown
        case .ramping(let percent, let secondsToMax): .ramping(percent: percent, secondsToMax: secondsToMax)
        case .atMaximum: .atMaximum
        case .unavailable: .unavailable
        }
    }
}
