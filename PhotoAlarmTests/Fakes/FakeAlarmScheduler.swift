import Foundation

@testable import PhotoAlarm

/// Recording `AlarmScheduler`. `oneOffs` holds the one-off System alarms still scheduled (a cancel removes
/// its entry), `cancelled` every id ever cancelled, in order.
final class FakeAlarmScheduler: AlarmScheduler, @unchecked Sendable {
    struct WeeklyRegistration: Equatable {
        let id: UUID
        let hour: Int
        let minute: Int
        let weekdays: Set<Locale.Weekday>
    }

    struct SchedulingFailure: Error {}

    private let lock = NSLock()
    private var scheduledOneOffs: [UUID: Date] = [:]
    private var weeklyRegistrations: [WeeklyRegistration] = []
    private var cancelledIDs: [UUID] = []
    private var alertingIDs: Set<UUID> = []
    private var isAuthorized = true
    private var failsToSchedule = false

    var oneOffs: [UUID: Date] { lock.withLock { scheduledOneOffs } }
    var weekly: [WeeklyRegistration] { lock.withLock { weeklyRegistrations } }
    var cancelled: [UUID] { lock.withLock { cancelledIDs } }

    var alerting: Set<UUID> {
        get { lock.withLock { alertingIDs } }
        set { lock.withLock { alertingIDs = newValue } }
    }

    var authorized: Bool {
        get { lock.withLock { isAuthorized } }
        set { lock.withLock { isAuthorized = newValue } }
    }

    /// While true, `scheduleOneOff` throws and records nothing.
    var schedulingFails: Bool {
        get { lock.withLock { failsToSchedule } }
        set { lock.withLock { failsToSchedule = newValue } }
    }

    func requestAuthorization() async -> Bool {
        authorized
    }

    func scheduleWeekly(id: UUID, hour: Int, minute: Int, weekdays: Set<Locale.Weekday>) async throws {
        lock.withLock {
            weeklyRegistrations.append(
                WeeklyRegistration(id: id, hour: hour, minute: minute, weekdays: weekdays))
        }
    }

    func scheduleOneOff(id: UUID, at date: Date) async throws {
        try lock.withLock {
            if failsToSchedule { throw SchedulingFailure() }
            scheduledOneOffs[id] = date
        }
    }

    func cancel(id: UUID) throws {
        lock.withLock {
            cancelledIDs.append(id)
            scheduledOneOffs[id] = nil
        }
    }

    func scheduledAlarms() throws -> [ScheduledSystemAlarm] {
        lock.withLock {
            let scheduled = scheduledOneOffs.keys.map { ScheduledSystemAlarm(id: $0, state: .scheduled) }
            let ringing = alertingIDs.map { ScheduledSystemAlarm(id: $0, state: .alerting) }
            return scheduled + ringing
        }
    }
}
