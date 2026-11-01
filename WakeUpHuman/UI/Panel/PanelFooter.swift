import AppKit
import SwiftUI

/// The panel's last rows (`docs/design/panel.html`): the launch-at-login switch with its live
/// status (spec decisions 18 and 36), then "Salir" on the left with its ⌘Q hint on the right.
/// "Salir" is unavailable while a Ring sounds (spec decisions 6 and 36, invariant 4): a disabled
/// button's shortcut is inert too, so ⌘Q does nothing either. Force Quit stays available.
struct PanelFooter: View {
    let clock: PanelClock
    let ringController: RingController
    let loginItem: LoginItemControlling
    /// Bumped on every switch change, so the body re-reads the status even when nothing else changed:
    /// the status is read live from the system, so no observable property announces it.
    @State private var switchChanges = 0

    var body: some View {
        // The panel's clock ticks once a second while it is visible: reading it re-reads the status,
        // so a change made in System Settings shows up live.
        let _ = clock.now
        let _ = switchChanges
        let status = loginItem.status
        VStack(alignment: .leading, spacing: 0) {
            launchAtLoginRow(status: status)
            quitRow
        }
        .padding(.horizontal, 2)
    }

    private func launchAtLoginRow(status: LoginItemStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Abrir al iniciar sesión")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelStyle.primaryText)
                Spacer(minLength: 0)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { status == .enabled },
                        set: { setLaunchAtLogin($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(PanelStyle.accent)
                .disabled(status == .unavailable)
                .accessibilityLabel("Abrir al iniciar sesión")
            }
            .frame(height: 26)
            switch status {
            case .requiresApproval:
                HStack(spacing: 8) {
                    Text("Falta aprobarlo en Configuración del Sistema")
                        .font(.system(size: 12))
                        .foregroundStyle(PanelStyle.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Abrir") { loginItem.openSystemSettings() }
                        .controlSize(.small)
                }
                .padding(.bottom, 2)
            case .unavailable:
                Text("Disponible con la app instalada en Aplicaciones")
                    .font(.system(size: 12))
                    .foregroundStyle(PanelStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            case .enabled, .disabled:
                EmptyView()
            }
        }
        .padding(.horizontal, 6)
    }

    private var quitRow: some View {
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
            .disabled(ringController.isRinging)
            Spacer()
            Text("⌘Q")
                .font(.system(size: 12))
                .foregroundStyle(PanelStyle.secondaryText)
                .padding(.trailing, 6)
        }
        .opacity(ringController.isRinging ? 0.4 : 1)
    }

    /// A failure is logged and never alerts: the switch snaps back to what the system reports.
    private func setLaunchAtLogin(_ isOn: Bool) {
        do {
            if isOn { try loginItem.register() } else { try loginItem.unregister() }
        } catch {
            Log.app.error("Could not switch launch at login \(isOn ? "on" : "off"): \(error.localizedDescription)")
        }
        switchChanges += 1
    }
}
