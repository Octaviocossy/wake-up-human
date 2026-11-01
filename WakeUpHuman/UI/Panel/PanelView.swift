import SwiftUI

/// The menu-bar panel (`docs/design/panel.html`). Sections are added by later slices in the
/// prototype's order, top to bottom: notices, Bedtime, next alarm, Alarm list, footer.
struct PanelView: View {
    let clock: PanelClock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Placeholder until the Alarm list lands (slice #11).
            Text("Wake Up Human")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelStyle.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(PanelStyle.border)
            PanelFooter()
        }
        .padding(PanelStyle.padding)
        .frame(width: PanelStyle.width)
        .background(PanelStyle.background, in: RoundedRectangle(cornerRadius: PanelStyle.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: PanelStyle.cornerRadius).stroke(PanelStyle.border))
        .environment(\.colorScheme, .dark)
    }
}
