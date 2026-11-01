import Foundation

/// The time an Occurrence is shown as — `"07:00"` — by the Ring window and the panel's notices: its
/// Alarm's time, or, if that Alarm was deleted meanwhile, the Occurrence's own time of day in
/// `calendar`.
func timeLabel(of occurrence: Occurrence, alarms: [Alarm], calendar: Calendar) -> String {
    if let alarm = alarms.first(where: { $0.id == occurrence.alarmID }) {
        return AlarmFormatting.time(alarm.time)
    }
    let components = calendar.dateComponents([.hour, .minute], from: occurrence.date)
    return AlarmFormatting.time(TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0))
}
