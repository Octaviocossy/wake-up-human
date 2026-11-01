import AppKit
import SwiftUI

/// The full-screen Ring window. Covers the main display only (spec decision 38): the display that
/// holds the menu bar, `NSScreen.screens.first` — not `NSScreen.main`, which follows the key window.
/// Opening it for an Occurrence and closing it at the cap belong to the Ring controller (#15).
@MainActor
final class RingWindowController {
    static let confirmationDuration: TimeInterval = 5

    /// Called when the window closes after the confirmation (timeout, key or click). Not called when
    /// the owner closes the window itself with `close()`.
    var onConfirmationClosed: (@MainActor () -> Void)?

    private var panel: RingPanel?
    private var screenObserver: NSObjectProtocol?
    private var inputMonitor: Any?
    private var confirmationTimeout: Task<Void, Never>?
    private var isConfirming = false

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Shows the window with the Typing challenge. Replaces a window that is already showing.
    func show(_ presentation: RingPresentation) {
        tearDown()
        guard let screen = Self.mainDisplay else {
            Log.ring.error("No display to show the Ring window on")
            return
        }

        let panel = RingPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .black
        panel.isOpaque = true
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let hostingController = NSHostingController(rootView: RingView(presentation: presentation))
        hostingController.sizingOptions = []
        panel.contentViewController = hostingController
        panel.setFrame(screen.frame, display: true)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reframe() }
        }

        self.panel = panel
        panel.orderFrontRegardless()
        panel.makeKey()
        // Best effort: activation is cooperative, and the non-activating key panel already
        // receives the keys.
        NSApp.activate()
        Log.ring.info("Ring window shown")
    }

    /// Switches a showing window to the "Alarma apagada" confirmation, which closes after
    /// `confirmationDuration` or on any key or click. Does nothing to a window that is not showing.
    func showDismissed(_ presentation: RingPresentation, rangForSeconds: Int) {
        presentation.showDismissed(rangForSeconds: rangForSeconds)
        guard panel != nil, !isConfirming else { return }
        isConfirming = true

        inputMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.finishConfirmation() }
            // Swallowed, so the key that closes the confirmation does not beep.
            return nil
        }
        confirmationTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.confirmationDuration))
            guard !Task.isCancelled else { return }
            self?.finishConfirmation()
        }
    }

    /// Closes the window without calling `onConfirmationClosed`.
    func close() {
        tearDown()
    }

    private func finishConfirmation() {
        guard isConfirming else { return }
        tearDown()
        onConfirmationClosed?()
    }

    private func tearDown() {
        isConfirming = false
        confirmationTimeout?.cancel()
        confirmationTimeout = nil
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        inputMonitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        if let panel {
            panel.orderOut(nil)
            panel.contentViewController = nil
        }
        panel = nil
    }

    private func reframe() {
        guard let panel, let screen = Self.mainDisplay else { return }
        panel.setFrame(screen.frame, display: true)
    }

    private static var mainDisplay: NSScreen? { NSScreen.screens.first ?? NSScreen.main }
}

/// Non-activating so it can take key status — and the keyboard — even though an `LSUIElement` app is
/// usually not the active app (the Caffeinassy panel pattern). Esc never closes it, and no ⌘ shortcut
/// reaches the app's menus while it is key.
final class RingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {}

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        return event.modifierFlags.contains(.command)
    }
}
