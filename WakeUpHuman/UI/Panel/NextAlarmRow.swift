import SwiftUI

/// "Próxima alarma: mañana 07:00 … en 8 h 14 min" (`docs/design/panel.html`). Reads `clock.now`,
/// which the panel advances every second while it is visible, so the countdown is live
/// (spec decision 35).
struct NextAlarmRow: View {
    let clock: PanelClock
    let alarmStore: AlarmStore

    var body: some View {
        let calendar = OccurrenceCalendar()
        let upcoming = UpcomingOccurrence.next(in: alarmStore.alarms, after: clock.now, calendar: calendar)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Próxima alarma:")
                .foregroundStyle(PanelStyle.secondaryText)
            if let upcoming {
                Text(
                    AlarmFormatting.whenLabel(of: upcoming.date, now: clock.now, calendar: calendar.calendar)
                        + " "
                        + AlarmFormatting.time(upcoming.alarm.time)
                )
                .fontWeight(.medium)
                .foregroundStyle(PanelStyle.primaryText)
                Spacer(minLength: 0)
                Text(AlarmFormatting.countdown(from: clock.now, to: upcoming.date))
                    .font(.system(size: 12))
                    // Secondary, not tertiary: the prototype colours the countdown #a1a1a6, and it
                    // governs colour where the spec is silent (spec decision 34).
                    .foregroundStyle(PanelStyle.secondaryText)
            } else {
                Text("ninguna")
                    .fontWeight(.medium)
                    .foregroundStyle(PanelStyle.primaryText)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: 13))
        .monospacedDigit()
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
