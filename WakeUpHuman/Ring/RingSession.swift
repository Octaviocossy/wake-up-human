import Foundation

/// One Ring: the Occurrences it covers — the first plus any that joined it — and its unattended cap
/// (glossary › Ring).
struct RingSession: Equatable, Sendable {
    /// An unattended Ring stops by itself this long after it started (spec decision 14).
    static let unattendedCap: TimeInterval = 60 * 60

    /// Ascending by date — Occurrences at the same instant in a stable order — with no duplicates.
    private(set) var occurrences: [Occurrence]
    let startedAt: Date
    var capEndsAt: Date { startedAt.addingTimeInterval(Self.unattendedCap) }

    init(occurrences: [Occurrence], startedAt: Date) {
        self.occurrences = Self.ordered(Set(occurrences))
        self.startedAt = startedAt
    }

    /// Adds the Occurrences the Ring does not cover yet (spec decision 15: an Occurrence due during a
    /// Ring joins it) and returns the ones actually added, in the same order.
    mutating func join(_ new: [Occurrence]) -> [Occurrence] {
        let added = Self.ordered(Set(new).subtracting(occurrences))
        if !added.isEmpty { occurrences = Self.ordered(Set(occurrences).union(added)) }
        return added
    }

    /// Chronological; the scheduler's tie-break for Occurrences at the same instant.
    private static func ordered(_ occurrences: Set<Occurrence>) -> [Occurrence] {
        occurrences.sorted { ($0.date, $0.alarmID.uuidString) < ($1.date, $1.alarmID.uuidString) }
    }
}

/// How a Ring ended — the only two ways one can (invariant 4).
enum RingOutcome: Equatable, Sendable {
    /// Its Typing challenge was solved.
    case dismissed(occurrences: [Occurrence], startedAt: Date, endedAt: Date)
    /// Its unattended cap ran out (spec decision 14).
    case unattended(occurrences: [Occurrence], startedAt: Date, endedAt: Date)
}
