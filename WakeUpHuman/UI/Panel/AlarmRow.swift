import SwiftUI

/// One Alarm: its time and days beside the Armed switch, or its inline editor while being edited
/// (`docs/design/panel.html`). The switch Arms and Disarms for free (spec decision 7).
struct AlarmRow: View {
    let alarm: Alarm
    let alarmStore: AlarmStore
    let isEditing: Bool
    let onEdit: () -> Void
    let onFinishEditing: () -> Void

    var body: some View {
        if isEditing {
            AlarmEditor(
                mode: .edit,
                hour: alarm.hour,
                minute: alarm.minute,
                weekdays: alarm.weekdays,
                onSave: { hour, minute, weekdays in
                    alarmStore.update(id: alarm.id, hour: hour, minute: minute, weekdays: weekdays)
                    onFinishEditing()
                },
                onDelete: {
                    alarmStore.delete(id: alarm.id)
                    onFinishEditing()
                },
                onCancel: onFinishEditing
            )
            .padding(.vertical, 2)
        } else {
            let time = AlarmFormatting.time(hour: alarm.hour, minute: alarm.minute)
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(time)
                            .font(.system(size: 28, weight: .light))
                            .tracking(-0.5)
                            .monospacedDigit()
                            .foregroundStyle(alarm.isArmed ? PanelStyle.primaryText : PanelStyle.tertiaryText)
                        Text(AlarmFormatting.days(alarm.weekdays))
                            .font(.system(size: 12))
                            .foregroundStyle(PanelStyle.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar alarma de las \(time)")

                Toggle(
                    "",
                    isOn: Binding(
                        get: { alarm.isArmed },
                        set: { alarmStore.setArmed($0, id: alarm.id) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(PanelStyle.accent)
                .accessibilityLabel("Alarma de las \(time)")
            }
            .padding(.trailing, 4)
        }
    }
}
