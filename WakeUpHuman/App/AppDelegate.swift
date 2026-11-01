import AppKit

/// The composition root: builds every object and wires them together. Nothing else creates
/// long-lived objects.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelClock: PanelClock?
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?
    private var alarmStore: AlarmStore?
    private var occurrenceScheduler: OccurrenceScheduler?
    private var ringController: RingController?
    private var bedtimeController: BedtimeController?
    private var noticeCenter: NoticeCenter?
    private var powerSource: IOKitPowerSourceMonitor?
    private var loginItem: SMAppServiceLoginItem?
    private var systemEvents: SystemEventObserver?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests launch this app: build nothing, so a test run never touches the Mac.
        guard !AppEnvironment.isRunningTests else { return }

        let alarmStore = AlarmStore()
        // Built before the scheduler starts: its launch evaluation can report missed Occurrences at once.
        let notices = NoticeCenter()
        noticeCenter = notices
        let powerSource = IOKitPowerSourceMonitor()
        self.powerSource = powerSource
        let loginItem = SMAppServiceLoginItem()
        self.loginItem = loginItem
        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem)
        let scheduler = OccurrenceScheduler(store: alarmStore, deadlines: DispatchDeadlineScheduler())
        // Built before the scheduler starts: a launch inside the on-time tolerance can ring at once.
        let ringController = makeRingController(alarmStore: alarmStore)
        // Bedtime starts off at every launch. A Ring replaces it (spec decision 9), so it is wired
        // before the scheduler starts.
        let bedtime = BedtimeController(
            rain: RainSound(),
            assertion: IOKitPowerAssertion(kind: .preventSystemSleep, name: "Wake Up Human — Bedtime")
        )
        ringController.onRingStarted = { [weak bedtime] in bedtime?.endForRing() }
        // A Ring nobody Dismissed leaves a notice behind (spec decision 14).
        ringController.onRingEnded = { [notices, alarmStore] outcome in
            guard case .unattended(let occurrences, _, let endedAt) = outcome else { return }
            notices.recordUnattended(
                occurrences: occurrences, endedAt: endedAt,
                timeLabel: { timeLabel(of: $0, alarms: alarmStore.alarms, calendar: .current) }, now: Date())
        }
        bedtimeController = bedtime
        scheduler.onDue = { [weak ringController] occurrences in ringController?.ring(occurrences, now: Date()) }
        // An Occurrence missed while the Mac slept or the app was closed never rings late (invariant 5);
        // the panel says so instead.
        scheduler.onMissed = { [notices, alarmStore] missed in
            Log.alarms.notice("Missed: \(missed.count) Occurrence(s)")
            notices.recordMissed(
                missed, timeLabel: { timeLabel(of: $0, alarms: alarmStore.alarms, calendar: .current) }, now: Date())
        }
        self.ringController = ringController
        alarmStore.onChange = { [weak scheduler] in scheduler?.alarmsDidChange(now: Date()) }
        self.alarmStore = alarmStore
        occurrenceScheduler = scheduler
        // Around System sleep: whatever fell due during it is reported as missed on wake, and never
        // rung (invariant 5).
        systemEvents = SystemEventObserver(
            willSleep: { [weak scheduler] in scheduler?.systemWillSleep(now: Date()) },
            didWake: { [weak scheduler] in scheduler?.systemDidWake(now: Date()) },
            clockDidChange: { [weak scheduler] in scheduler?.clockDidChange(now: Date()) }
        )
        scheduler.start(now: Date())

        let panelClock = PanelClock()
        let panelController = PanelController(
            clock: panelClock,
            rootView: PanelView(
                clock: panelClock, alarmStore: alarmStore, bedtime: bedtime, notices: notices,
                powerSource: powerSource, ringController: ringController, loginItem: loginItem)
        )
        self.panelClock = panelClock
        self.panelController = panelController
        statusItemController = StatusItemController(panelController: panelController) {
            [alarmStore, ringController, bedtime, notices, powerSource] in
            Self.statusIconInput(
                alarmStore: alarmStore, ringController: ringController, bedtime: bedtime, notices: notices,
                powerSource: powerSource, now: Date())
        }
        Log.app.info("Wake Up Human launched")
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        // A Ring cut short by quitting still gives the volume back and releases its power calls.
        ringController?.applicationWillTerminate()
        // Termination never leaves the keep-awake assertion held or the rain playing.
        bedtimeController?.turnOff()
        systemEvents?.stop()
        powerSource?.stop()
    }

    /// What the status icon shows: a Ring, Bedtime, an Armed Alarm, and whether any notice — pending
    /// or derived — waits. Every `@Observable` property read here redraws the icon when it changes.
    @MainActor
    private static func statusIconInput(
        alarmStore: AlarmStore, ringController: RingController, bedtime: BedtimeController,
        notices: NoticeCenter, powerSource: IOKitPowerSourceMonitor, now: Date
    ) -> StatusIconInput {
        let derived = NoticeCenter.derived(
            bedtimeOn: bedtime.isOn,
            upcoming: UpcomingOccurrence.next(in: alarmStore.alarms, after: now, calendar: OccurrenceCalendar()),
            onBattery: powerSource.isOnBattery,
            now: now
        )
        return StatusIconInput(
            isRinging: ringController.isRinging,
            bedtimeOn: bedtime.isOn,
            anyAlarmArmed: alarmStore.alarms.contains(where: \.isArmed),
            hasPendingNotice: !notices.pending.isEmpty || !derived.isEmpty
        )
    }

    /// The Ring stack: the tone, the borrowed volume, the display's power calls, the window and the
    /// unattended cap.
    @MainActor
    private func makeRingController(alarmStore: AlarmStore) -> RingController {
        let ringVolume = RingVolumeController(volume: CoreAudioSystemVolume())
        // A Ring cut short by Force Quit or a crash gives the volume back now.
        ringVolume.restorePendingIfNeeded()
        let wordList: WordList
        do {
            wordList = try WordList.bundled()
        } catch {
            Log.ring.fault("Bundled word list failed to load: \(String(describing: error)); using the fallback")
            wordList = .fallback
        }
        return RingController(
            alarmStore: alarmStore,
            tone: AlarmTone(),
            volume: ringVolume,
            displayAssertion: IOKitPowerAssertion(kind: .preventDisplaySleep, name: "Wake Up Human — Ring"),
            displayWaker: IOKitDisplayWaker(),
            window: RingWindowController(),
            capDeadline: DispatchDeadlineScheduler(),
            makeChallenge: { TypingChallenge.draw(from: wordList) }
        )
    }
}
