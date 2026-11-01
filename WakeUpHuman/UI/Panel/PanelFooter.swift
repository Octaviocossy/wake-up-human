import AppKit
import SwiftUI

/// The panel's last row (`docs/design/panel.html`): "Salir" on the left, its ⌘Q hint on the right.
/// Slice #17 adds the launch-at-login row above it and disables Quit while a Ring sounds, so the
/// footer stays a view of its own.
struct PanelFooter: View {
    var body: some View {
        HStack {
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Salir")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelStyle.primaryText)
                    .padding(.horizontal, 6)
                    .frame(height: 26)
                    .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            Spacer()
            Text("⌘Q")
                .font(.system(size: 12))
                .foregroundStyle(PanelStyle.secondaryText)
                .padding(.trailing, 6)
        }
        .padding(.horizontal, 2)
    }
}
