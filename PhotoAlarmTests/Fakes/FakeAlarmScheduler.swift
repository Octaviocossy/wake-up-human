import Foundation

@testable import PhotoAlarm

/// Recording `AlarmScheduler`. `oneOffs` and `weekly` hold the System alarms still scheduled (a cancel removes
/// the entry), `cancelled` every id ever cancelled, in order.
final class FakeAlarmScheduler: AlarmScheduler, @unchecked Sendable {
    struct WeeklyRegistration: Equatable, Hashable {
        let id: UUID
        let hour: Int
        let minute: Int
        let weekdays: Set<Locale.Weekday>
    }

    struct SchedulingFailure: Error {}
    struct ReadFailure: Error {}

    private let lock = NSLock()
    private var scheduledOneOffs: [UUID: Date] = [:]
    private var weeklyRegistrations: [WeeklyRegistration] = []
    private var cancelledIDs: [UUID] = []
    private var alertingIDs: Set<UUID> = []
    private var isAuthorized = true
    private var authorizationRequestCount = 0
    private var failsToSchedule = false
    private var failsToRead = false

    var oneOffs: [UUID: Date] { lock.withLock { scheduledOneOffs } }
    var weekly: [WeeklyRegistration] { lock.withLock { weeklyRegistrations } }
    var cancelled: [UUID] { lock.withLock { cancelledIDs } }

    var alerting: Set<UUID> {
        get { lock.withLock { alertingIDs } }
        set { lock.withLock { alertingIDs = newValue } }
    }

    /// How many times the app asked for authorization.
    var authorizationRequests: Int { lock.withLock { authorizationRequestCount } }

    var authorized: Bool {
        get { lock.withLock { isAuthorized } }
        set { lock.withLock { isAuthorized = newValue } }
    }

    /// While true, `scheduleOneOff` and `scheduleWeekly` throw and record nothing.
    var schedulingFails: Bool {
        get { lock.withLock { failsToSchedule } }
        set { lock.withLock { failsToSchedule = newValue } }
    }

    /// While true, `scheduledAlarms` throws, as AlarmKit does when the app is not authorized.
    var readingFails: Bool {
        get { lock.withLock { failsToRead } }
        set { lock.withLock { failsToRead = newValue } }
    }

    func requestAuthorization() async -> Bool {
        lock.withLock {
            authorizationRequestCount += 1
            return isAuthorized
        }
    }

    func scheduleWeekly(id: UUID, hour: Int, minute: Int, weekdays: Set<Locale.Weekday>) async throws {
        try lock.withLock {
            if failsToSchedule { throw SchedulingFailure() }
            weeklyRegistrations.removeAll { $0.id == id }
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
            weeklyRegistrations.removeAll { $0.id == id }
        }
    }

    /// Each System alarm once; one that is alerting is reported as alerting whatever else it is.
    func scheduledAlarms() throws -> [ScheduledSystemAlarm] {
        try lock.withLock {
            if failsToRead { throw ReadFailure() }
            let quiet = Set(scheduledOneOffs.keys).union(weeklyRegistrations.map(\.id)).subtracting(alertingIDs)
            return quiet.map { ScheduledSystemAlarm(id: $0, state: .scheduled) }
                + alertingIDs.map { ScheduledSystemAlarm(id: $0, state: .alerting) }
        }
    }
}
