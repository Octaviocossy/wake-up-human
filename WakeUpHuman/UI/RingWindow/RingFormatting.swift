import Foundation

/// The Spanish copy of the Ring window (`docs/design/ring-window.html`). Pure functions, so the
/// wording is tested without a window.
enum RingFormatting {
    static let defaultCapMinutes = 60

    /// "Sonando · alarma de las 07:00", "Sonando · 07:00 y 07:05", "Sonando · 07:00, 07:05 y 07:10".
    static func status(alarmTimes: [String]) -> String {
        switch alarmTimes.count {
        case 0:
            return "Sonando"
        case 1:
            return "Sonando · alarma de las \(alarmTimes[0])"
        default:
            return "Sonando · \(list(alarmTimes))"
        }
    }

    /// The chip announcing an Occurrence that joined the Ring; `nil` while only one has rung.
    static func joined(alarmTimes: [String]) -> String? {
        guard alarmTimes.count > 1, let last = alarmTimes.last else { return nil }
        return "Se sumó la alarma de las \(last)"
    }

    /// "Sonando hace 5:52": minutes unpadded, seconds padded.
    static func elapsed(_ seconds: Int) -> String {
        "Sonando hace \(minutes(seconds)):\(twoDigits(seconds % 60))"
    }

    /// "07:00".
    static func clock(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return "\(twoDigits(components.hour ?? 0)):\(twoDigits(components.minute ?? 0))"
    }

    static func progress(completed: Int) -> String {
        "\(completed) de \(TypingChallenge.wordCount) palabras"
    }

    /// The volume row of the bottom bar; `nil` hides it.
    static func volume(_ status: VolumeStatus) -> String? {
        switch status {
        case .unknown:
            return nil
        case .ramping(let percent, let secondsToMax):
            return "Volumen del sistema \(percent) % · al máximo en \(secondsToMax) s"
        case .atMaximum:
            return "Volumen del sistema al máximo"
        case .unavailable:
            return "No se puede controlar el volumen de esta salida"
        }
    }

    /// "Se calla sola a las 08:00 · tope de 60 min".
    static func cap(endsAt: Date, calendar: Calendar, minutes: Int = defaultCapMinutes) -> String {
        "Se calla sola a las \(clock(endsAt, calendar: calendar)) · tope de \(minutes) min"
    }

    static func pasteHint(rejected: Bool) -> String {
        rejected ? "No se puede pegar: tipealo" : "Pegar está bloqueado"
    }

    /// "Sonó 5 min 52 s" — how long the Ring sounded, shown once it is Dismissed.
    static func rangFor(_ seconds: Int) -> String {
        "Sonó \(minutes(seconds)) min \(seconds % 60) s"
    }

    /// "07:00" → "07:00"; "07:00", "07:05" → "07:00 y 07:05"; three or more → "07:00, 07:05 y 07:10".
    /// Shared with the panel's notices (`NoticeFormatting`).
    static func list(_ times: [String]) -> String {
        guard let last = times.last else { return "" }
        guard times.count > 1 else { return last }
        return times.dropLast().joined(separator: ", ") + " y " + last
    }

    private static func minutes(_ seconds: Int) -> Int { max(seconds, 0) / 60 }

    private static func twoDigits(_ value: Int) -> String {
        let value = max(value, 0)
        return value < 10 ? "0\(value)" : "\(value)"
    }
}
