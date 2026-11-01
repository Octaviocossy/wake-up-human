import Foundation

/// A wake-up time plus the weekdays it repeats on (glossary › Alarm). No weekday = a one-time
/// Alarm: it rings once, at the next Occurrence of its time, then Disarms itself (spec decision 22).
struct Alarm: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var time: TimeOfDay
    var weekdays: Set<Weekday>
    var isArmed: Bool

    var isOneTime: Bool { weekdays.isEmpty }
}
