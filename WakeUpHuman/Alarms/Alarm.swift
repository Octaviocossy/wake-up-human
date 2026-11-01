import Foundation

/// A wake-up time plus the weekdays it repeats on (glossary › Alarm). No weekday = a one-time
/// Alarm: it rings once, at the next Occurrence of its time, then Disarms itself (spec decision 22).
struct Alarm: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var hour: Int  // 0...23
    var minute: Int  // 0...59
    var weekdays: Set<Weekday>
    var isArmed: Bool

    var isOneTime: Bool { weekdays.isEmpty }
    var minuteOfDay: Int { hour * 60 + minute }
}
