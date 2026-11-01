import SwiftUI

/// The menu-bar panel (`docs/design/panel.html`), top to bottom: notices, Bedtime, next alarm,
/// Alarm list, footer.
struct PanelView: View {
    let clock: PanelClock
    let alarmStore: AlarmStore
    let bedtime: BedtimeController
    let notices: NoticeCenter
    let powerSource: IOKitPowerSourceMonitor
    let ringController: RingController
    let loginItem: LoginItemControlling

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NoticesSection(
                clock: clock, notices: notices, alarmStore: alarmStore, bedtime: bedtime, powerSource: powerSource)
            BedtimeSection(bedtime: bedtime)
            NextAlarmRow(clock: clock, alarmStore: alarmStore)
            Divider().overlay(PanelStyle.border)
            AlarmListSection(alarmStore: alarmStore)
            Divider().overlay(PanelStyle.border)
            PanelFooter(clock: clock, ringController: ringController, loginItem: loginItem)
        }
        .padding(PanelStyle.padding)
        .frame(width: PanelStyle.width)
        .background(PanelStyle.background, in: RoundedRectangle(cornerRadius: PanelStyle.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: PanelStyle.cornerRadius).stroke(PanelStyle.border))
        .environment(\.colorScheme, .dark)
    }
}
