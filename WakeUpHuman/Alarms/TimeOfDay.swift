import Foundation

/// A time on the 24-hour clock, to the minute: the time every Occurrence of an Alarm shares.
struct TimeOfDay: Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    /// - Precondition: `hour` is in 0...23 and `minute` in 0...59.
    init(hour: Int, minute: Int) {
        precondition(Self.isValid(hour: hour, minute: minute), "No such time of day: \(hour):\(minute)")
        self.hour = hour
        self.minute = minute
    }

    /// Minutes since midnight, 0...1439.
    var minuteOfDay: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minuteOfDay < rhs.minuteOfDay }

    fileprivate static func isValid(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }
}

extension TimeOfDay: Codable {
    private enum CodingKeys: String, CodingKey {
        case hour
        case minute
    }

    /// An out-of-range time is a decoding error rather than a trap, so a corrupt Alarm list loads
    /// the way any undecodable one does.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)
        guard Self.isValid(hour: hour, minute: minute) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "No such time of day: \(hour):\(minute)"))
        }
        self.init(hour: hour, minute: minute)
    }
}
