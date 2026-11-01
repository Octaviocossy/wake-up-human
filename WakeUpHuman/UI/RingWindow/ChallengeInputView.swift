import AppKit
import SwiftUI

/// The Typing challenge's input. It is not a text field: it only understands key presses, so there
/// is nothing to paste into and nowhere to drop text (spec decision 5). A real `NSTextField` would
/// need its field editor patched for ⌘V, "Paste and Match Style", Services and drag and drop.
struct ChallengeInputView: NSViewRepresentable {
    let target: String
    let typed: String
    let onInsert: @MainActor (String) -> Void
    let onDeleteBackward: @MainActor () -> Void
    let onPasteAttempt: @MainActor () -> Void

    func makeNSView(context: Context) -> ChallengeKeyCaptureView {
        let view = ChallengeKeyCaptureView()
        configure(view)
        return view
    }

    func updateNSView(_ view: ChallengeKeyCaptureView, context: Context) {
        configure(view)
    }

    private func configure(_ view: ChallengeKeyCaptureView) {
        view.onInsert = onInsert
        view.onDeleteBackward = onDeleteBackward
        view.onPasteAttempt = onPasteAttempt
        view.setAccessibilityLabel("Texto para apagar la alarma: \(target)")
        view.setAccessibilityValue(typed)
    }
}

final class ChallengeKeyCaptureView: NSView {
    private static let deleteKeyCode: UInt16 = 51

    var onInsert: @MainActor (String) -> Void = { _ in }
    var onDeleteBackward: @MainActor () -> Void = {}
    var onPasteAttempt: @MainActor () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.textField)
        // No `registerForDraggedTypes`: a drop has nowhere to land.
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ChallengeKeyCaptureView is created in code only")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    /// Takes the keyboard back if a click ever moved it elsewhere.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        // Never `super`: no beep and no text system.
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) || modifiers.contains(.control) {
            if modifiers.contains(.command), event.charactersIgnoringModifiers == "v" {
                onPasteAttempt()
            }
            return
        }
        if event.keyCode == Self.deleteKeyCode {
            onDeleteBackward()
            return
        }
        // Return, Tab, Esc and the arrow and function keys carry no letter and are dropped here.
        // A ⌥-composed accent arrives as a letter and simply evaluates as wrong.
        guard let characters = event.characters else { return }
        let typed = characters.filter { $0.isLetter || $0 == " " }
        if !typed.isEmpty { onInsert(typed) }
    }

    /// Every ⌘ equivalent is ours while the Ring window is key, so no shortcut acts in it.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command) else { return false }
        if event.charactersIgnoringModifiers == "v" { onPasteAttempt() }
        return true
    }
}
