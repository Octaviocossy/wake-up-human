/// A day an Alarm repeats on. Raw values are `Calendar` weekday numbers (1 = Sunday); `allCases`
/// is Monday-first, the order the panel shows (L M X J V S D).
enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    /// Position in the Monday-first week, 0...6.
    var mondayFirstIndex: Int { Self.allCases.firstIndex(of: self)! }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.mondayFirstIndex < rhs.mondayFirstIndex }
}
