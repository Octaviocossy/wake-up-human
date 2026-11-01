import SwiftUI

/// The inline editor for a new or an existing Alarm (`docs/design/panel.html`, "Inline editing"):
/// a time field, seven weekday chips, the repeat hint and the buttons. It edits a draft; nothing
/// reaches the store until "Agregar" or "Guardar".
struct AlarmEditor: View {
    enum Mode {
        case new
        case edit
    }

    let mode: Mode
    let onSave: (_ time: TimeOfDay, _ weekdays: Set<Weekday>) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var time: Date
    @State private var weekdays: Set<Weekday>

    init(
        mode: Mode,
        time: TimeOfDay,
        weekdays: Set<Weekday>,
        onSave: @escaping (_ time: TimeOfDay, _ weekdays: Set<Weekday>) -> Void,
        onDelete: (() -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _time = State(
            initialValue: Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())
                ?? Date())
        _weekdays = State(initialValue: weekdays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(mode == .new ? "Nueva alarma" : "Hora")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelStyle.secondaryText)
                Spacer()
                DatePicker("Hora", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .environment(\.locale, Locale(identifier: "es_ES"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Días")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelStyle.secondaryText)
                HStack(spacing: 0) {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        dayChip(weekday)
                        if weekday != Weekday.allCases.last { Spacer(minLength: 0) }
                    }
                }
                Text(AlarmFormatting.repeatHint(weekdays))
                    .font(.system(size: 12))
                    .foregroundStyle(PanelStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let onDelete {
                    Button("Eliminar", action: onDelete)
                        .buttonStyle(EditorButtonStyle(fill: .clear, foreground: EditorColors.delete, padding: 8))
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                }
                Button("Cancelar", action: onCancel)
                    .buttonStyle(EditorButtonStyle(fill: Color.white.opacity(0.12), foreground: PanelStyle.primaryText))
                Button(mode == .new ? "Agregar" : "Guardar", action: save)
                    .buttonStyle(
                        EditorButtonStyle(fill: PanelStyle.accent, foreground: EditorColors.onAccent, weight: .semibold)
                    )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColors.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(EditorColors.cardOutline))
    }

    private func dayChip(_ weekday: Weekday) -> some View {
        let isOn = weekdays.contains(weekday)
        let labels = AlarmFormatting.labels(of: weekday)
        return Button {
            if isOn { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
        } label: {
            Text(labels.letter)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? EditorColors.onAccent : PanelStyle.primaryText)
                .frame(width: 38, height: 38)
                .background(isOn ? PanelStyle.accent : PanelStyle.card, in: Circle())
                .overlay(Circle().stroke(isOn ? PanelStyle.accent : Color.white.opacity(0.18)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(labels.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        onSave(TimeOfDay(hour: components.hour ?? 7, minute: components.minute ?? 0), weekdays)
    }
}

/// Colours only the editor uses (`docs/design/panel.html`), kept here so `PanelStyle` — which every
/// slice touching the panel shares — stays untouched.
private enum EditorColors {
    /// The editing card: rgba(255,255,255,0.07) with an accent outline at 50 %, one shade above
    /// `PanelStyle.card` so the card being edited stands out. The prototype governs colour where
    /// the spec is silent (spec decision 34).
    static let card = Color.white.opacity(0.07)
    static let cardOutline = PanelStyle.accent.opacity(0.5)
    static let delete = Color(red: 255 / 255, green: 105 / 255, blue: 97 / 255)  // #ff6961
    static let onAccent = Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)  // #1d1d1f
}

/// The editor's 28 pt rounded buttons.
private struct EditorButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color
    var weight: Font.Weight = .medium
    var padding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(foreground)
            .padding(.horizontal, padding)
            .frame(height: 28)
            .background(fill, in: RoundedRectangle(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}
