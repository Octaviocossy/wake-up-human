import Foundation

/// The Spanish copy of the panel's notices (`docs/design/panel.html`, "With notices" and "Bedtime on
/// battery"). Pure functions, so the wording is tested without a view. Product content, which S20
/// does not govern (ADR-0024).
enum NoticeFormatting {
    static let acknowledgeLabel = "Entendido"
    static let activateBedtimeLabel = "Activar modo dormir"

    // MARK: Missed Occurrence

    /// "No sonó la alarma de las 06:15", "No sonaron las alarmas de las 06:15 y 07:00".
    static func missedTitle(times: [String]) -> String {
        times.count == 1
            ? "No sonó la alarma de las \(RingFormatting.list(times))"
            : "No sonaron las alarmas de las \(RingFormatting.list(times))"
    }

    /// Names why the Occurrence was missed; every cause ends on the rule that it never rings late
    /// (invariant 5).
    static func missedBody(cause: MissedCause) -> String {
        let reason =
            switch cause {
            case .systemSleep: "A esa hora la Mac estaba dormida."
            case .appNotRunning: "A esa hora la app no estaba abierta."
            case .checkRanLate: "A esa hora la app no respondió."
            }
        return reason + " Una alarma perdida no suena tarde."
    }

    // MARK: Unattended Ring

    /// "La alarma de las 08:30 sonó sin respuesta", "Las alarmas de las 08:30 y 08:35 sonaron sin respuesta".
    static func unattendedTitle(times: [String]) -> String {
        times.count == 1
            ? "La alarma de las \(RingFormatting.list(times)) sonó sin respuesta"
            : "Las alarmas de las \(RingFormatting.list(times)) sonaron sin respuesta"
    }

    /// "Sonó los 60 minutos, hasta las 09:30, y se calló sola."
    static func unattendedBody(endedAt: Date, calendar: Calendar) -> String {
        "Sonó los \(RingFormatting.defaultCapMinutes) minutos, hasta las "
            + "\(RingFormatting.clock(endedAt, calendar: calendar)), y se calló sola."
    }

    // MARK: Bedtime off with an Alarm due soon

    static let bedtimeOffTitle = "Modo dormir apagado"

    /// "Hay una alarma mañana 07:00. Sin el modo dormir la Mac puede dormirse y la alarma no sonar."
    static func bedtimeOffBody(upcoming: UpcomingOccurrence, now: Date, calendar: Calendar) -> String {
        let when = AlarmFormatting.whenLabel(of: upcoming.date, now: now, calendar: calendar)
        let time = AlarmFormatting.time(upcoming.alarm.time)
        return "Hay una alarma \(when) \(time). Sin el modo dormir la Mac puede dormirse y la alarma no sonar."
    }

    // MARK: Bedtime on battery

    static let batteryTitle = "Modo dormir a batería"
    static let batteryBody = "Enchufá la Mac. Sin corriente puede dormirse igual y la alarma no sonar."
}
