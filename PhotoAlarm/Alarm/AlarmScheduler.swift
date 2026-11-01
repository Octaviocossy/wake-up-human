import Foundation

/// A System alarm as the app sees it, detached from `AlarmKit.Alarm`.
struct ScheduledSystemAlarm: Sendable, Equatable {
    enum State: Sendable, Equatable { case scheduled, alerting, other }

    let id: UUID
    let state: State
}

/// Every AlarmKit call goes through this protocol so mission logic can be tested with a fake.
protocol AlarmScheduler: Sendable {
    /// True when AlarmKit is authorized; asks the user on the first call.
    func requestAuthorization() async -> Bool
    /// Weekly System alarm for an Alarm: hour:minute on each given weekday.
    func scheduleWeekly(id: UUID, hour: Int, minute: Int, weekdays: Set<Locale.Weekday>) async throws
    /// One-off System alarm at an absolute date (a Follow-up, or a debug alarm).
    func scheduleOneOff(id: UUID, at date: Date) async throws
    func cancel(id: UUID) throws
    func scheduledAlarms() throws -> [ScheduledSystemAlarm]
}
