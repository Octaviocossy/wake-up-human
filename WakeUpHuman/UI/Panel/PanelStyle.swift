import SwiftUI

/// Colours and metrics of the prototype (`docs/design/`). One place, so every panel section and
/// the Ring window match.
enum PanelStyle {
    static let width: CGFloat = 340
    static let padding: CGFloat = 10
    static let cornerRadius: CGFloat = 14
    static let background = Color(red: 42 / 255, green: 42 / 255, blue: 46 / 255).opacity(0.95)
    static let border = Color.white.opacity(0.12)
    static let card = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.08)
    static let primaryText = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)  // #f5f5f7
    static let secondaryText = Color(red: 161 / 255, green: 161 / 255, blue: 166 / 255)  // #a1a1a6
    static let tertiaryText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)  // #8e8e93
    static let accent = Color(red: 255 / 255, green: 159 / 255, blue: 10 / 255)  // #ff9f0a — Alarms, Ring
    static let bedtime = Color(red: 94 / 255, green: 92 / 255, blue: 230 / 255)  // #5e5ce6
    static let warning = Color(red: 255 / 255, green: 214 / 255, blue: 10 / 255)  // #ffd60a — notices
    static let danger = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)  // #ff453a
}
