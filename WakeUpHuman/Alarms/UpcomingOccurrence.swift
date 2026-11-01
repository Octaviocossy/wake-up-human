import Foundation

/// The next Occurrence among Armed Alarms — the panel's "Próxima alarma" row, and the
/// Bedtime-off notice (#17), which warns about an Armed Alarm due within 12 hours.
struct UpcomingOccurrence: Equatable, Sendable {
    let alarm: Alarm
    let date: Date

    static func next(in alarms: [Alarm], after now: Date, calendar: OccurrenceCalendar) -> UpcomingOccurrence? {
        alarms.filter(\.isArmed)
            .compactMap { alarm in
                calendar.nextOccurrence(of: alarm, after: now).map { UpcomingOccurrence(alarm: alarm, date: $0) }
            }
            .min { $0.date < $1.date }
    }
}
