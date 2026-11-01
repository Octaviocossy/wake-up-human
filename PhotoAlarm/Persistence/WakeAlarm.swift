import Foundation
import SwiftData

/// An Alarm: a wake-up time plus at least one weekday. Its AlarmKit registration is a System alarm.
@Model
final class WakeAlarm {
    /// Also the ID of its weekly System alarm, so no mapping table is needed.
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    /// Calendar weekday numbers, 1 = Sunday … 7 = Saturday. Stored as numbers so nothing depends on
    /// `Locale.Weekday`'s raw representation.
    var weekdayNumbers: [Int]
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(), hour: Int, minute: Int, weekdayNumbers: [Int], isEnabled: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdayNumbers = weekdayNumbers
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var weekdays: Set<Locale.Weekday> {
        Set(weekdayNumbers.compactMap(Self.weekday(for:)))
    }

    /// 1 → Sunday … 7 → Saturday; anything else is not a weekday.
    static func weekday(for number: Int) -> Locale.Weekday? {
        switch number {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
    }
}

/// An Alarm detached from SwiftData, so it can cross into the async reconcile without sharing a model object.
struct WakeAlarmSnapshot: Sendable, Equatable {
    let id: UUID
    let hour: Int
    let minute: Int
    let weekdays: Set<Locale.Weekday>
    let isEnabled: Bool
}

extension WakeAlarm {
    var snapshot: WakeAlarmSnapshot {
        WakeAlarmSnapshot(id: id, hour: hour, minute: minute, weekdays: weekdays, isEnabled: isEnabled)
    }
}
