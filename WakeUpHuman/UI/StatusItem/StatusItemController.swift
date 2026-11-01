import AppKit
import Observation

/// Owns the menu-bar status item. Any click toggles the panel. The glyph is a monochrome template
/// image in one of the six states of `docs/design/status-icon.html` (spec decision 32); only the
/// yellow notice dot and the Ring's orange tint are coloured.
@MainActor
final class StatusItemController {
    /// The Bedtime-off notice appears when an Alarm enters its 12-hour window, which changes no
    /// observable property, so the icon is also redrawn on the clock.
    nonisolated static let refreshInterval: TimeInterval = 60
    nonisolated static let refreshTolerance: TimeInterval = 10

    private let statusItem: NSStatusItem
    private let panelController: PanelController
    private let iconInput: @MainActor () -> StatusIconInput
    private let dot = StatusDotView()
    private var refreshTimer: Timer?

    /// `iconInput` reads the app's state; whatever `@Observable` property it reads redraws the icon
    /// when it changes.
    init(panelController: PanelController, iconInput: @escaping @MainActor () -> StatusIconInput) {
        self.panelController = panelController
        self.iconInput = iconInput
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        renderAndObserve()
        startRefreshTimer()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        dot.isHidden = true
        dot.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(dot)
        // Over the glyph's top right corner. The y-offset is "up" in the button's own coordinates.
        let up: CGFloat = button.isFlipped ? -1 : 1
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: StatusDotView.side),
            dot.heightAnchor.constraint(equalToConstant: StatusDotView.side),
            dot.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: 8),
            dot.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: 5 * up),
        ])
    }

    /// Draws the icon for the current state and registers to be told when what it read changes. A
    /// tracking registration fires once, so every change registers the next.
    private func renderAndObserve() {
        let input = withObservationTracking {
            iconInput()
        } onChange: { [weak self] in
            // Called just before the change lands: draw once it has.
            Task { @MainActor in self?.renderAndObserve() }
        }
        render(input)
    }

    private func render(_ input: StatusIconInput) {
        guard let button = statusItem.button else { return }
        let appearance = StatusIcon.appearance(for: input)
        let image = NSImage(
            systemSymbolName: appearance.symbolName, accessibilityDescription: appearance.accessibilityDescription)
        // A template, so the menu bar draws it in its own light or dark colour.
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = appearance.isDimmed
        button.contentTintColor = appearance.isRingingTint ? .systemOrange : nil
        dot.isHidden = !appearance.showsDot
        button.setAccessibilityLabel(appearance.accessibilityDescription)
    }

    private func startRefreshTimer() {
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.render(self.iconInput())
            }
        }
        timer.tolerance = Self.refreshTolerance
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        panelController.toggle(relativeTo: button)
    }
}

/// The notice dot (`docs/design/status-icon.html`): a 6 pt yellow circle inside a 1.5 pt ring in the
/// menu bar's background colour, which keeps it legible over the glyph. Clicks pass through to the button.
private final class StatusDotView: NSView {
    static let dotDiameter: CGFloat = 6
    static let ringWidth: CGFloat = 1.5
    static let side = dotDiameter + 2 * ringWidth

    private let core = CALayer()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        wantsLayer = true
        layer?.cornerRadius = Self.side / 2
        core.frame = CGRect(x: Self.ringWidth, y: Self.ringWidth, width: Self.dotDiameter, height: Self.dotDiameter)
        core.cornerRadius = Self.dotDiameter / 2
        layer?.addSublayer(core)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("StatusDotView is built in code") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        updateColors()
    }

    /// A layer's `CGColor` does not follow the appearance by itself.
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            core.backgroundColor = NSColor.systemYellow.cgColor
        }
    }
}
