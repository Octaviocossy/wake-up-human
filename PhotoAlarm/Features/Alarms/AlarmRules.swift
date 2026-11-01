import Foundation

/// The rules an Alarm must satisfy, as pure functions (spec decisions 7 and 9).
enum AlarmRules {
    /// Every Alarm repeats on at least one weekday: there are no one-off Alarms (decision 9). A number that is
    /// not a weekday does not count, so an Alarm can never be saved with nothing to schedule.
    static func canSave(weekdayNumbers: [Int]) -> Bool {
        weekdayNumbers.contains { WakeAlarm.weekday(for: $0) != nil }
    }

    enum EnableBlock: Equatable {
        case targetObjectNotRegistered
        case notAuthorized
    }

    /// Why an Alarm cannot be enabled yet, or nil when it can. No Alarm is enabled until the Target object is
    /// registered (decision 7), and that is checked first: the user is not asked for AlarmKit permission for an
    /// Alarm that could not be enabled anyway.
    static func enableBlock(isTargetRegistered: Bool, isAuthorized: Bool) -> EnableBlock? {
        if !isTargetRegistered { return .targetObjectNotRegistered }
        if !isAuthorized { return .notAuthorized }
        return nil
    }

    /// The seven calendar weekday numbers in the order a week is shown, starting at `firstWeekday`
    /// (`Calendar.firstWeekday`, 1 = Sunday).
    static func weekOrder(firstWeekday: Int) -> [Int] {
        let first = (firstWeekday - 1 + 7) % 7
        return (0..<7).map { (first + $0) % 7 + 1 }
    }
}
