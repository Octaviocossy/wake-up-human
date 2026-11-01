import AppKit
import SwiftUI

/// A borderless, non-activating panel hosting the SwiftUI `PanelView`. Positioning, dismissal and
/// Esc are ours to write — a popover or `MenuBarExtra` brings focus and Dock bugs in an
/// `LSUIElement` app (spec decision 21).
@MainActor
final class PanelController {
    private let panel: WakeUpHumanPanel
    private let clock: PanelClock
    private var outsideClickMonitor: Any?
    private var tickTimer: Timer?

    init(clock: PanelClock, rootView: PanelView) {
        self.clock = clock
        panel = WakeUpHumanPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelStyle.width, height: 100),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hostingController
        panel.onCancel = { [weak self] in self?.close() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(relativeTo button: NSStatusBarButton) {
        isVisible ? close() : show(relativeTo: button)
    }

    func show(relativeTo button: NSStatusBarButton) {
        clock.tick()
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        panel.layoutIfNeeded()
        position(relativeTo: button)
        panel.orderFrontRegardless()
        panel.makeKey()
        startTicking()
        startWatchingForOutsideClicks()
    }

    func close() {
        stopTicking()
        stopWatchingForOutsideClicks()
        panel.orderOut(nil)
    }

    /// Centred under the status item button, clamped to the screen.
    private func position(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        var origin = NSPoint(x: buttonRect.midX - size.width / 2, y: buttonRect.minY - size.height - 6)
        if let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
    }

    /// The panel's only timer, and only while the panel can be seen.
    private func startTicking() {
        tickTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.clock.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func startWatchingForOutsideClicks() {
        stopWatchingForOutsideClicks()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func stopWatchingForOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }
}

/// A borderless panel refuses key status by default, which would leave Esc and text fields dead.
final class WakeUpHumanPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
