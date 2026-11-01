import SwiftUI

/// The menu-bar panel (`docs/design/panel.html`). Sections are added by later slices in the
/// prototype's order, top to bottom: notices (#17), Bedtime (#16), next alarm, Alarm list, footer.
struct PanelView: View {
    let clock: PanelClock
    let alarmStore: AlarmStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NextAlarmRow(clock: clock, alarmStore: alarmStore)
            Divider().overlay(PanelStyle.border)
            AlarmListSection(alarmStore: alarmStore)
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
