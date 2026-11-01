import AppKit

/// The composition root: builds every object and wires them together. Nothing else creates
/// long-lived objects.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelClock: PanelClock?
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests launch this app: build nothing, so a test run never touches the Mac.
        guard !AppEnvironment.isRunningTests else { return }

        let panelClock = PanelClock()
        let panelController = PanelController(clock: panelClock, rootView: PanelView(clock: panelClock))
        self.panelClock = panelClock
        self.panelController = panelController
        statusItemController = StatusItemController(panelController: panelController)
        Log.app.info("Wake Up Human launched")
    }
}
