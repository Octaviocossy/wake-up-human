import AppKit

/// The composition root: builds every object and wires them together. Nothing else creates
/// long-lived objects.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelClock: PanelClock?
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?
    private var alarmStore: AlarmStore?
    private var occurrenceScheduler: OccurrenceScheduler?
    private var systemObservers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests launch this app: build nothing, so a test run never touches the Mac.
        guard !AppEnvironment.isRunningTests else { return }

        let alarmStore = AlarmStore()
        let scheduler = OccurrenceScheduler(store: alarmStore, deadlines: DispatchDeadlineScheduler())
        // Here both only log: the Ring subscribes to `onDue` (#15), the missed notice to `onMissed` (#17).
        scheduler.onDue = { occurrences in Log.alarms.info("Due: \(occurrences.count) Occurrence(s)") }
        scheduler.onMissed = { missed in Log.alarms.notice("Missed: \(missed.count) Occurrence(s)") }
        alarmStore.onChange = { [weak scheduler] in scheduler?.alarmsDidChange(now: Date()) }
        self.alarmStore = alarmStore
        occurrenceScheduler = scheduler
        observeSystem(scheduler)
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
        for observer in systemObservers {
            observer.center.removeObserver(observer.token)
        }
        systemObservers.removeAll()
    }

    /// Re-evaluates the Occurrences around System sleep and wake, and reschedules when the system
    /// clock or time zone changes. A wake evaluates late, so what fell due during the sleep is
    /// reported as missed and never rung (invariant 5).
    @MainActor
    private func observeSystem(_ scheduler: OccurrenceScheduler) {
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default

        systemObservers.append(
            (
                workspace,
                workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
                    [weak scheduler] _ in
                    MainActor.assumeIsolated { scheduler?.evaluate(now: Date()) }
                }
            ))
        systemObservers.append(
            (
                workspace,
                workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
                    [weak scheduler] _ in
                    MainActor.assumeIsolated { scheduler?.evaluate(now: Date(), missedCause: .systemSleep) }
                }
            ))
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            systemObservers.append(
                (
                    center,
                    center.addObserver(forName: name, object: nil, queue: .main) { [weak scheduler] _ in
                        MainActor.assumeIsolated { scheduler?.clockDidChange(now: Date()) }
                    }
                ))
        }
    }
}
