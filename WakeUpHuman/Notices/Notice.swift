import Foundation

/// A notice that stays until the user acknowledges it ("Entendido") — persisted across launches
/// (glossary › Notice).
struct PendingNotice: Codable, Equatable, Identifiable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        /// Occurrences that fell due while the app could not ring them, for one `cause`; the times
        /// are ascending, as `"06:15"`, `"07:00"`.
        case missed(alarmTimes: [String], cause: MissedCause)
        /// A Ring that ran out its unattended cap; the times are those of the Occurrences it covered.
        case unattended(alarmTimes: [String], endedAt: Date)
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
}

/// A notice computed from the current state; it clears itself when the state changes, so it is never
/// stored.
enum DerivedNotice: Equatable, Sendable {
    /// Bedtime is off and an Armed Alarm is due within `NoticeCenter.bedtimeWarningWindow`.
    case bedtimeOffWithAlarmSoon(UpcomingOccurrence)
    /// Bedtime is on and the Mac runs on battery.
    case bedtimeOnBattery
}
