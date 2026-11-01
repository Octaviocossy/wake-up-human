import Foundation

/// The numbers behind the re-alarm loop and the Fallback (spec decisions 3, 5, 16 and 21).
enum MissionPolicy {
    /// How long after a Ring ends through Stop or "Take photo" its Follow-up sounds.
    static let followUpInterval: TimeInterval = 60
    /// Follow-ups armed per Wake-up session; postponing one does not count.
    static let followUpCap = 20
    /// From a session's first Ring until it is abandoned.
    static var followUpWindow: TimeInterval { followUpInterval * Double(followUpCap) }
    /// Failed Photo checks in one session before the Fallback unlocks.
    static let fallbackUnlockFailures = 5
    /// Consecutive correct answers that complete the Fallback.
    static let fallbackProblemCount = 15
    /// How often the mission screen, while in the foreground, pushes the pending Follow-up forward.
    static let postponeTick: TimeInterval = 30
    /// How long a finished session stays in the store.
    static let retention: TimeInterval = 7 * 24 * 3600
}
