import SwiftUI

/// The "Modo dormir" block (`docs/design/panel.html`): the Bedtime switch, the rain slider and the
/// requirement the Mac must meet. The slider dims while Bedtime is off but stays adjustable
/// (spec decision 35).
struct BedtimeSection: View {
    @Bindable var bedtime: BedtimeController
    /// Bumped on every switch change, so the body re-reads `isOn` even when nothing changed: a refused
    /// assertion leaves Bedtime off, and the switch must snap back instead of claiming otherwise.
    @State private var switchChanges = 0

    var body: some View {
        let _ = switchChanges
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(bedtime.isOn ? PanelStyle.bedtime : Color.white.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Modo dormir")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PanelStyle.primaryText)
                    Text(bedtime.isOn ? "Activo · lluvia sonando" : "Apagado")
                        .font(.system(size: 12))
                        .foregroundStyle(PanelStyle.secondaryText)
                }
                Spacer(minLength: 0)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { bedtime.isOn },
                        set: { isOn in
                            if isOn { bedtime.turnOn() } else { bedtime.turnOff() }
                            switchChanges += 1
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(PanelStyle.bedtime)
                .accessibilityLabel("Modo dormir")
            }

            HStack(spacing: 8) {
                Image(systemName: "cloud.rain")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 199 / 255, green: 199 / 255, blue: 204 / 255))  // #c7c7cc
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text("Lluvia")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 199 / 255, green: 199 / 255, blue: 204 / 255))
                    .frame(width: 38, alignment: .leading)
                Slider(value: $bedtime.rainVolume, in: 0...1)
                    .tint(PanelStyle.bedtime)
                    .accessibilityLabel("Volumen de la lluvia")
                Text("\(Int((bedtime.rainVolume * 100).rounded())) %")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(PanelStyle.secondaryText)
                    .frame(width: 42, alignment: .trailing)
            }
            .opacity(bedtime.isOn ? 1 : 0.55)

            Text("Mantiene la Mac despierta para que la alarma suene. Dejala con la tapa abierta y enchufada.")
                .font(.system(size: 12))
                .foregroundStyle(PanelStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelStyle.card, in: RoundedRectangle(cornerRadius: 10))
    }
}
