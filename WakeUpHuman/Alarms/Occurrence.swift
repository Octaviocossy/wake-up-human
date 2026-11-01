import Foundation

/// One due date-and-time of an Armed Alarm (glossary › Occurrence).
struct Occurrence: Hashable, Codable, Sendable {
    let alarmID: UUID
    let date: Date
}

/// Why an Occurrence was missed — the panel's missed notice words it differently (#17).
enum MissedCause: String, Codable, Sendable {
    case systemSleep  // the Mac was asleep (or the app otherwise saw it too late)
    case appNotRunning  // the app was not running at that time
}

struct MissedOccurrence: Hashable, Codable, Sendable {
    let occurrence: Occurrence
    let cause: MissedCause
}
