import Foundation

@testable import WakeUpHuman

/// Fixed calendars and dates so no test depends on the machine's time zone.
enum TestCalendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static let madrid: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        in calendar: Calendar = utc
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        )!
    }

    static func alarm(
        _ hour: Int, _ minute: Int, weekdays: Set<Weekday> = [], isArmed: Bool = true, id: UUID = UUID()
    ) -> Alarm {
        Alarm(id: id, hour: hour, minute: minute, weekdays: weekdays, isArmed: isArmed)
    }
}
