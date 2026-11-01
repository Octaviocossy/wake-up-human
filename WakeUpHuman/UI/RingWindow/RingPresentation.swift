import Foundation
import Observation

/// What the Ring window shows about the system volume. Driven by the Ring controller (#15) from the
/// volume ramp (#13).
enum VolumeStatus: Equatable, Sendable {
    case unknown
    case ramping(percent: Int, secondsToMax: Int)
    case atMaximum
    case unavailable
}

/// What the Ring window shows, driven by the Ring controller (#15). Owns the typed text.
@MainActor
@Observable
final class RingPresentation {
    enum Phase: Equatable {
        case ringing
        case dismissed(rangForSeconds: Int)
    }

    /// How far past the target the typed text may grow; anything beyond is dropped.
    static let maximumExtraCharacters = 10
    static let pasteHintDuration: TimeInterval = 1.8

    let challenge: TypingChallenge
    let startedAt: Date
    let capEndsAt: Date
    /// "07:00"; #15 appends a joined Occurrence's time.
    var alarmTimes: [String]
    /// #15 updates it from the volume ramp (#13).
    var volume: VolumeStatus = .unknown
    private(set) var typed = ""
    private(set) var progress: ChallengeProgress
    private(set) var phase: Phase = .ringing
    private(set) var pasteRejectedAt: Date?
    /// Called once, the moment the typed text matches (no Enter — spec decision 33).
    @ObservationIgnored var onSolved: (@MainActor () -> Void)?
    @ObservationIgnored private var hasReportedSolved = false

    init(challenge: TypingChallenge, alarmTimes: [String], startedAt: Date, capEndsAt: Date) {
        self.challenge = challenge
        self.alarmTimes = alarmTimes
        self.startedAt = startedAt
        self.capEndsAt = capEndsAt
        progress = challenge.evaluate("")
    }

    /// Appends `text` lowercased, newlines dropped, stopping at `target.count + maximumExtraCharacters`.
    func insert(_ text: String) {
        guard phase == .ringing else { return }
        let incoming = text.lowercased().filter { !$0.isNewline }
        let room = challenge.target.count + Self.maximumExtraCharacters - typed.count
        guard room > 0, !incoming.isEmpty else { return }
        typed += incoming.prefix(room)
        refresh()
    }

    func deleteBackward() {
        guard phase == .ringing, !typed.isEmpty else { return }
        typed.removeLast()
        refresh()
    }

    /// Records a paste or drop attempt; the view shows the hint for `pasteHintDuration`.
    func rejectPaste(now: Date = Date()) {
        pasteRejectedAt = now
    }

    func isShowingPasteHint(now: Date) -> Bool {
        guard let pasteRejectedAt else { return false }
        return now < pasteRejectedAt.addingTimeInterval(Self.pasteHintDuration)
    }

    func showDismissed(rangForSeconds: Int) {
        phase = .dismissed(rangForSeconds: rangForSeconds)
    }

    private func refresh() {
        progress = challenge.evaluate(typed)
        if progress.isSolved, !hasReportedSolved {
            hasReportedSolved = true
            onSolved?()
        }
    }
}
