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
    private var systemEvents: SystemEventObserver?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests launch this app: build nothing, so a test run never touches the Mac.
        guard !AppEnvironment.isRunningTests else { return }

        let alarmStore = AlarmStore()
        let scheduler = OccurrenceScheduler(store: alarmStore, deadlines: DispatchDeadlineScheduler())
        // Built before the scheduler starts: a launch inside the on-time tolerance can ring at once.
        let ringController = makeRingController(alarmStore: alarmStore)
        scheduler.onDue = { [weak ringController] occurrences in ringController?.ring(occurrences, now: Date()) }
        // Here it only logs: the missed notice subscribes to `onMissed` (#17).
        scheduler.onMissed = { missed in Log.alarms.notice("Missed: \(missed.count) Occurrence(s)") }
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
            rootView: PanelView(clock: panelClock, alarmStore: alarmStore)
        )
        self.panelClock = panelClock
        self.panelController = panelController
        statusItemController = StatusItemController(panelController: panelController)
        Log.app.info("Wake Up Human launched")
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        // A Ring cut short by quitting still gives the volume back and releases its power calls.
        ringController?.applicationWillTerminate()
        systemEvents?.stop()
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
