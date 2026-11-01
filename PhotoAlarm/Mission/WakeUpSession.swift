import Foundation

/// The alarm button a Ring ended through. Both arm a Follow-up (spec decision 15); only the intent's
/// `supportedModes` differs.
enum RingExit: String, Codable, Sendable {
    case stop
    case takePhoto
}

/// One occurrence of an Alarm, from its first Ring until its Mission is completed or its Follow-up
/// window closes (`.agents/ubiquitous-language.md`). Persisted in `MissionStateStore` (invariant 2).
struct WakeUpSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// The System alarm whose Ring opened the session (an Alarm's weekly registration, or a debug alarm).
    let openingAlarmID: UUID
    let firstRingAt: Date
    /// Every Follow-up ever armed for this session, including postponed replacements.
    var followUpIDs: [UUID] = []
    var pendingFollowUpID: UUID?
    /// Counts toward `MissionPolicy.followUpCap`; postponing does not increment it.
    var followUpsArmed = 0
    var failedChecks = 0
    var fallbackSolved = 0
    var completedAt: Date?
    var abandonedAt: Date?

    var windowEnd: Date { firstRingAt.addingTimeInterval(MissionPolicy.followUpWindow) }
    var isClosed: Bool { completedAt != nil || abandonedAt != nil }
    func isOpen(at now: Date) -> Bool { !isClosed && now < windowEnd }
    var isFallbackUnlocked: Bool { failedChecks >= MissionPolicy.fallbackUnlockFailures }
}

/// Everything the app persists about missions.
struct MissionState: Codable, Equatable, Sendable {
    var sessions: [WakeUpSession] = []
}
