import AppKit

/// Owns the menu-bar status item. Any click toggles the panel. The glyph is a monochrome template
/// image; slice #17 replaces the placeholder with the six states of `docs/design/status-icon.html`.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let panelController: PanelController

    init(panelController: PanelController) {
        self.panelController = panelController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        let image = NSImage(systemSymbolName: "alarm", accessibilityDescription: "Wake Up Human")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = true  // "no Alarm Armed" — the only state this skeleton can know
    }

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        panelController.toggle(relativeTo: button)
    }
}
