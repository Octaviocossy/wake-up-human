import SwiftUI

/// The "Alarmas" header with its "+" button, the Alarm list and the empty state
/// (`docs/design/panel.html`). At most one editor is open at a time.
struct AlarmListSection: View {
    let alarmStore: AlarmStore
    @State private var editing: EditingTarget?

    enum EditingTarget: Equatable {
        case new
        case alarm(UUID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Alarmas")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelStyle.secondaryText)
                Spacer()
                Button {
                    if editing != .new { editing = .new }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelStyle.primaryText)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nueva alarma")
            }
            .padding(.leading, 6)
            .padding(.trailing, 2)

            if editing == .new {
                AlarmEditor(
                    mode: .new,
                    time: TimeOfDay(hour: 7, minute: 0),  // a new Alarm starts at 07:00, no weekday (decision 35)
                    weekdays: [],
                    onSave: { time, weekdays in
                        alarmStore.add(time: time, weekdays: weekdays)
                        editing = nil
                    },
                    onDelete: nil,
                    onCancel: { editing = nil }
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(alarmStore.alarms) { alarm in
                    AlarmRow(
                        alarm: alarm,
                        alarmStore: alarmStore,
                        isEditing: editing == .alarm(alarm.id),
                        onEdit: { editing = .alarm(alarm.id) },
                        onFinishEditing: { editing = nil }
                    )
                }
            }

            if alarmStore.alarms.isEmpty && editing != .new {
                Text("No hay alarmas. Tocá + para agregar una.")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelStyle.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)
            }
        }
    }
}
