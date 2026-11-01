import SwiftUI

/// Edits one Alarm's time and weekdays, or creates a new one when `alarm` is nil. Nothing is stored until Save,
/// so Cancel discards every change.
struct AlarmEditorView: View {
    let model: AlarmListModel
    let alarm: WakeAlarm?

    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    @State private var weekdayNumbers: Set<Int>
    @State private var isSaving = false

    init(model: AlarmListModel, alarm: WakeAlarm?) {
        self.model = model
        self.alarm = alarm
        let components = DateComponents(hour: alarm?.hour ?? 7, minute: alarm?.minute ?? 0)
        _time = State(initialValue: Calendar.current.date(from: components) ?? .now)
        _weekdayNumbers = State(initialValue: Set(alarm?.weekdayNumbers ?? []))
    }

    private var canSave: Bool {
        AlarmRules.canSave(weekdayNumbers: Array(weekdayNumbers))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                Section {
                    HStack(spacing: 6) {
                        ForEach(AlarmRules.weekOrder(firstWeekday: Calendar.current.firstWeekday), id: \.self) {
                            weekdayButton($0)
                        }
                    }
                } header: {
                    Text("Repeat")
                } footer: {
                    if !canSave {
                        Text("Choose at least one weekday.")
                    }
                }
            }
            .navigationTitle(alarm == nil ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func weekdayButton(_ number: Int) -> some View {
        let isChosen = weekdayNumbers.contains(number)
        return Button {
            if isChosen {
                weekdayNumbers.remove(number)
            } else {
                weekdayNumbers.insert(number)
            }
        } label: {
            Text(Calendar.current.shortWeekdaySymbols[number - 1])
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isChosen ? Color.white : Color.primary)
                .background(isChosen ? Color.accentColor : Color.secondary.opacity(0.15), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[number - 1])
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        isSaving = true
        Task {
            let saved = await model.save(
                alarm, hour: components.hour ?? 0, minute: components.minute ?? 0,
                weekdayNumbers: Array(weekdayNumbers))
            isSaving = false
            if saved { dismiss() }
        }
    }
}
