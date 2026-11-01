import Foundation

/// The panel's Spanish labels for Alarms, ported from the prototype's script
/// (`docs/design/panel.html`: `fmt`, `daysLabel`, `whenLabel`, `inLabel`, the editor `hint`).
/// They are product content, which S20 does not govern (ADR-0024); the copy is the prototype's,
/// which governs copy where the spec is silent (spec decision 34).
enum AlarmFormatting {
    /// The editor's day chips, Monday-first: the one-letter label, and the full name that is the
    /// chip's accessibility label.
    static let chips: [(weekday: Weekday, letter: String, name: String)] = [
        (.monday, "L", "Lunes"),
        (.tuesday, "M", "Martes"),
        (.wednesday, "X", "Miércoles"),
        (.thursday, "J", "Jueves"),
        (.friday, "V", "Viernes"),
        (.saturday, "S", "Sábado"),
        (.sunday, "D", "Domingo"),
    ]

    private static let abbreviations: [Weekday: String] = [
        .monday: "lun", .tuesday: "mar", .wednesday: "mié", .thursday: "jue",
        .friday: "vie", .saturday: "sáb", .sunday: "dom",
    ]

    private static let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    private static let weekend: Set<Weekday> = [.saturday, .sunday]

    /// Zero-padded 24-hour time: `"07:00"`.
    static func time(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    /// The row's second line: `"Una vez"`, `"Todos los días"`, `"Lun a vie"`, `"Sáb y dom"`, or the
    /// Monday-first abbreviations (`"Lun, mié, vie"`).
    static func days(_ weekdays: Set<Weekday>) -> String {
        if weekdays.isEmpty { return "Una vez" }
        if weekdays.count == Weekday.allCases.count { return "Todos los días" }
        if weekdays == workdays { return "Lun a vie" }
        if weekdays == weekend { return "Sáb y dom" }
        let list = weekdays.sorted().compactMap { abbreviations[$0] }.joined(separator: ", ")
        return list.prefix(1).uppercased() + list.dropFirst()
    }

    /// The editor's hint under the day chips.
    static func repeatHint(_ weekdays: Set<Weekday>) -> String {
        weekdays.isEmpty
            ? "Sin días: suena una vez y se desarma sola."
            : "Se repite: " + days(weekdays).lowercased() + "."
    }

    /// `"hoy"`, `"mañana"`, or the weekday abbreviation, relative to `now`.
    static func whenLabel(of date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "hoy" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
            calendar.isDate(date, inSameDayAs: tomorrow)
        {
            return "mañana"
        }
        return Weekday(rawValue: calendar.component(.weekday, from: date)).flatMap { abbreviations[$0] } ?? ""
    }

    /// The time left, rounded **up** to whole minutes: `"en 8 h 14 min"`, `"en 14 min"`.
    static func countdown(from now: Date, to date: Date) -> String {
        let minutes = max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        return hours > 0 ? "en \(hours) h \(rest) min" : "en \(rest) min"
    }
}
