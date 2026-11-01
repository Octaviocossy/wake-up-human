import Foundation

/// Calendar math for Occurrences. Ignores `isArmed`; callers filter.
struct OccurrenceCalendar: Sendable {
    /// `.autoupdatingCurrent`, so Occurrences follow the Mac into a new time zone.
    var calendar: Calendar = .autoupdatingCurrent

    /// The first Occurrence of `alarm` strictly after `date`.
    func nextOccurrence(of alarm: Alarm, after date: Date) -> Date? {
        let time = alarm.time
        if alarm.isOneTime {
            return next(after: date, matching: DateComponents(hour: time.hour, minute: time.minute, second: 0))
        }
        return alarm.weekdays.compactMap { weekday in
            next(
                after: date,
                matching: DateComponents(hour: time.hour, minute: time.minute, second: 0, weekday: weekday.rawValue)
            )
        }.min()
    }

    /// Every Occurrence of `alarm` in (start, end], ascending. A one-time Alarm yields at most one.
    func occurrences(of alarm: Alarm, after start: Date, through end: Date) -> [Date] {
        var result: [Date] = []
        var cursor = start
        while let next = nextOccurrence(of: alarm, after: cursor), next <= end {
            result.append(next)
            if alarm.isOneTime { break }
            cursor = next
        }
        return result
    }

    private func next(after date: Date, matching components: DateComponents) -> Date? {
        // `.nextTime`: a time that does not exist on a DST-change day maps to the next existing time.
        calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
}
