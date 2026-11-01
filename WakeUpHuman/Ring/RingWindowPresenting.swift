/// The Ring window as the Ring controller sees it, so the lifecycle can be tested without AppKit.
@MainActor
protocol RingWindowPresenting: AnyObject {
    /// Shows the window with the Typing challenge, replacing one already showing.
    func show(_ presentation: RingPresentation)
    /// Switches to the "Alarma apagada" confirmation, which closes itself (spec decision 37).
    func showDismissed(_ presentation: RingPresentation, rangForSeconds: Int)
    /// Closes the window with no confirmation.
    func close()
}

extension RingWindowController: RingWindowPresenting {}
