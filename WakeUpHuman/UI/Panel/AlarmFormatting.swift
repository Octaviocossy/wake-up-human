import Foundation

/// The panel's Spanish labels for Alarms, ported from the prototype's script
/// (`docs/design/panel.html`: `fmt`, `daysLabel`, `whenLabel`, `inLabel`, the editor `hint`).
/// They are product content, which S20 does not govern (ADR-0024); the copy is the prototype's,
/// which governs copy where the spec is silent (spec decision 34).
enum AlarmFormatting {
    /// The Spanish labels of one weekday.
    struct WeekdayLabels: Equatable, Sendable {
        /// The editor chip's one-letter label.
        let letter: String
        /// The full name: the chip's accessibility label.
        let name: String
        /// The abbreviation the day lists and `whenLabel` use.
        let abbreviation: String
    }

    /// Every label of `weekday`, from one table.
    static func labels(of weekday: Weekday) -> WeekdayLabels {
        switch weekday {
        case .monday: WeekdayLabels(letter: "L", name: "Lunes", abbreviation: "lun")
        case .tuesday: WeekdayLabels(letter: "M", name: "Martes", abbreviation: "mar")
        case .wednesday: WeekdayLabels(letter: "X", name: "Miércoles", abbreviation: "mié")
        case .thursday: WeekdayLabels(letter: "J", name: "Jueves", abbreviation: "jue")
        case .friday: WeekdayLabels(letter: "V", name: "Viernes", abbreviation: "vie")
        case .saturday: WeekdayLabels(letter: "S", name: "Sábado", abbreviation: "sáb")
        case .sunday: WeekdayLabels(letter: "D", name: "Domingo", abbreviation: "dom")
        }
    }

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
        let list = weekdays.sorted().map { labels(of: $0).abbreviation }.joined(separator: ", ")
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
        return Weekday(rawValue: calendar.component(.weekday, from: date)).map { labels(of: $0).abbreviation } ?? ""
    }

    /// The time left, rounded **up** to whole minutes: `"en 8 h 14 min"`, `"en 14 min"`.
    static func countdown(from now: Date, to date: Date) -> String {
        let minutes = max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        return hours > 0 ? "en \(hours) h \(rest) min" : "en \(rest) min"
    }
}
