import Foundation
import Observation

/// The panel's notices (glossary › Notice). Missed and unattended-Ring notices are events: they are
/// recorded, persisted in `UserDefaults` as Codable JSON, and stay until acknowledged, so a relaunch
/// never loses "your Alarm did not ring". The Bedtime ones are computed from live state by
/// `derived` and clear themselves (spec decision 25).
@MainActor
@Observable
final class NoticeCenter {
    static let pendingKey = "pendingNotices"
    /// An Armed Alarm due within this long, with Bedtime off, raises the Bedtime-off notice (spec decision 25).
    nonisolated static let bedtimeWarningWindow: TimeInterval = 12 * 60 * 60

    /// Oldest first, which is the panel's order.
    private(set) var pending: [PendingNotice]

    @ObservationIgnored private let defaults: UserDefaults

    /// Undecodable stored data starts empty and is logged, never a crash.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pending = Self.load(from: defaults)
    }

    /// Records one notice per cause in `missed`, ordered by each cause's earliest Occurrence. A
    /// notice lists the distinct times of its Occurrences, ascending; a long absence that missed the
    /// same Alarm on several days names its time once.
    func recordMissed(_ missed: [MissedOccurrence], timeLabel: (Occurrence) -> String, now: Date) {
        let byCause = Dictionary(grouping: missed, by: \.cause)
        let causes = byCause.keys.sorted { lhs, rhs in
            (Self.earliest(byCause[lhs] ?? []), lhs.rawValue) < (Self.earliest(byCause[rhs] ?? []), rhs.rawValue)
        }
        guard !causes.isEmpty else { return }
        for cause in causes {
            let times = (byCause[cause] ?? []).map { timeLabel($0.occurrence) }
            pending.append(
                PendingNotice(
                    id: UUID(), kind: .missed(alarmTimes: Self.ascending(times), cause: cause), createdAt: now))
        }
        persist()
    }

    /// Records the notice of a Ring that nobody Dismissed: the times of every Occurrence it covered,
    /// ascending, and when it stopped.
    func recordUnattended(
        occurrences: [Occurrence], endedAt: Date, timeLabel: (Occurrence) -> String, now: Date
    ) {
        guard !occurrences.isEmpty else { return }
        let times = Self.ascending(occurrences.map(timeLabel))
        pending.append(
            PendingNotice(id: UUID(), kind: .unattended(alarmTimes: times, endedAt: endedAt), createdAt: now))
        persist()
    }

    /// "Entendido": removes the notice. Does nothing for an unknown `id`.
    func acknowledge(id: UUID) {
        guard pending.contains(where: { $0.id == id }) else { return }
        pending.removeAll { $0.id == id }
        persist()
    }

    /// The live notices for this state, in panel order: Bedtime off with an Alarm due soon, then
    /// Bedtime on battery. A pure function of its arguments, so it needs no storage and cannot go stale.
    static func derived(
        bedtimeOn: Bool, upcoming: UpcomingOccurrence?, onBattery: Bool, now: Date
    ) -> [DerivedNotice] {
        var notices: [DerivedNotice] = []
        if !bedtimeOn, let upcoming, upcoming.date.timeIntervalSince(now) <= bedtimeWarningWindow {
            notices.append(.bedtimeOffWithAlarmSoon(upcoming))
        }
        if bedtimeOn && onBattery { notices.append(.bedtimeOnBattery) }
        return notices
    }

    // MARK: - Private

    private static func earliest(_ missed: [MissedOccurrence]) -> Date {
        missed.map(\.occurrence.date).min() ?? .distantFuture
    }

    /// Distinct times, ascending. `"HH:mm"` sorts as text.
    private static func ascending(_ times: [String]) -> [String] {
        Array(Set(times)).sorted()
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(pending), forKey: Self.pendingKey)
        } catch {
            Log.alarms.error("Could not save the notices: \(error.localizedDescription)")
        }
    }

    private static func load(from defaults: UserDefaults) -> [PendingNotice] {
        guard let data = defaults.data(forKey: pendingKey) else { return [] }
        do {
            return try JSONDecoder().decode([PendingNotice].self, from: data)
        } catch {
            Log.alarms.error("Could not read the notices, starting empty: \(error.localizedDescription)")
            return []
        }
    }
}
