@testable import WakeUpHuman

/// Stands in for the Ring window: records what the Ring controller asked of it and shows nothing.
@MainActor
final class RingWindowSpy: RingWindowPresenting {
    /// Every presentation passed to `show`, in order.
    private(set) var shown: [RingPresentation] = []
    /// The rung seconds of every `showDismissed`, in order.
    private(set) var dismissedWith: [Int] = []
    private(set) var closeCount = 0

    func show(_ presentation: RingPresentation) {
        shown.append(presentation)
    }

    func showDismissed(_ presentation: RingPresentation, rangForSeconds: Int) {
        dismissedWith.append(rangForSeconds)
    }

    func close() {
        closeCount += 1
    }
}
