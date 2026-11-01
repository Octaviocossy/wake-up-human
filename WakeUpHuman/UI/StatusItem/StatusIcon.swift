import Foundation

/// What the status icon is derived from: the app's state, nothing else.
struct StatusIconInput: Equatable, Sendable {
    var isRinging: Bool
    var bedtimeOn: Bool
    var anyAlarmArmed: Bool
    /// Any pending or derived notice (glossary › Notice).
    var hasPendingNotice: Bool
}

/// How the status icon looks for one `StatusIconInput`.
struct StatusIconAppearance: Equatable, Sendable {
    let symbolName: String
    /// Drawn dimmed: nothing is Armed.
    let isDimmed: Bool
    /// Tinted orange while a Ring sounds; every other state keeps the monochrome template glyph.
    let isRingingTint: Bool
    /// The yellow dot over the glyph's top right corner.
    let showsDot: Bool
    let accessibilityDescription: String
}

/// The six states of `docs/design/status-icon.html` (spec decision 32), as a pure mapping. The glyph
/// is the first of four by priority — ringing, Bedtime on, an Alarm Armed, nothing Armed — and a
/// pending notice adds the dot on top of any of them except a Ring, which already fills the icon.
enum StatusIcon {
    static let accessibilityName = "Wake Up Human"
    static let pendingNoticeSuffix = " · aviso pendiente"

    static func appearance(for input: StatusIconInput) -> StatusIconAppearance {
        let symbolName: String
        let state: String
        var isDimmed = false
        if input.isRinging {
            symbolName = "alarm.fill"
            state = "sonando"
        } else if input.bedtimeOn {
            symbolName = "moon.fill"
            state = "modo dormir activo"
        } else if input.anyAlarmArmed {
            symbolName = "alarm"
            state = "alarma armada"
        } else {
            symbolName = "alarm"
            state = "sin alarmas armadas"
            isDimmed = true
        }
        return StatusIconAppearance(
            symbolName: symbolName,
            isDimmed: isDimmed,
            isRingingTint: input.isRinging,
            showsDot: input.hasPendingNotice && !input.isRinging,
            accessibilityDescription: "\(accessibilityName) — \(state)"
                + (input.hasPendingNotice ? pendingNoticeSuffix : "")
        )
    }
}
