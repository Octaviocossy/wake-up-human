import Foundation

/// One due date-and-time of an Armed Alarm (glossary › Occurrence).
struct Occurrence: Hashable, Codable, Sendable {
    let alarmID: UUID
    let date: Date
}

/// Why an Occurrence was missed — the panel's missed notice words each cause differently (#17).
enum MissedCause: String, Codable, Sendable {
    /// The Mac was in System sleep when it fell due, or was still waking from it.
    case systemSleep
    /// The app was not running when it fell due.
    case appNotRunning
    /// The app was running and the Mac awake, but the check that found it ran more than
    /// `OccurrenceScheduler.onTimeTolerance` late — the app's main thread stalled.
    case checkRanLate
}

struct MissedOccurrence: Hashable, Codable, Sendable {
    let occurrence: Occurrence
    let cause: MissedCause
}
