import Foundation

/// Reports every due Occurrence of an Armed Alarm on time and every missed one, however many — and
/// never rings one late (product invariant 5). It decides "late" from the clock at evaluation time,
/// so a check that runs after System sleep, or a launch after the app was closed, turns into a
/// missed Occurrence instead of a Ring.
@MainActor
final class OccurrenceScheduler {
    /// An Occurrence first seen more than this long after its time is missed, never rung (invariant 5).
    /// Absorbs timer, main-actor and launch latency only; anything coming back from System sleep or
    /// an app launch is virtually always later than this.
    static let onTimeTolerance: TimeInterval = 30
    static let lastEvaluatedKey = "lastEvaluatedAt"

    /// Every Occurrence due together, in one call (spec decision 15: one Ring).
    var onDue: (@MainActor ([Occurrence]) -> Void)?
    /// Every Occurrence missed since the last evaluation, in one call — a long absence included, so
    /// none goes unreported (ADR-0027); the missed notice (#17) may collapse them.
    var onMissed: (@MainActor ([MissedOccurrence]) -> Void)?

    private let store: AlarmStore
    private let deadlines: DeadlineScheduling
    private let calendar: OccurrenceCalendar
    private let defaults: UserDefaults
    private let currentDate: @MainActor () -> Date
    /// Seconds on a clock that keeps counting through System sleep and that setting the system clock
    /// never moves. Only the difference between two readings means anything.
    private let continuousTime: @MainActor () -> TimeInterval
    /// `continuousTime()` when this process last recorded an evaluation; `nil` until it first does.
    private var lastEvaluatedContinuousTime: TimeInterval?
    private var isEvaluating = false

    init(
        store: AlarmStore,
        deadlines: DeadlineScheduling,
        calendar: OccurrenceCalendar = OccurrenceCalendar(),
        defaults: UserDefaults = .standard,
        currentDate: @escaping @MainActor () -> Date = { Date() },
        continuousTime: @escaping @MainActor () -> TimeInterval = { OccurrenceScheduler.systemContinuousTime() }
    ) {
        self.store = store
        self.deadlines = deadlines
        self.calendar = calendar
        self.defaults = defaults
        self.currentDate = currentDate
        self.continuousTime = continuousTime
    }

    /// Darwin's `CLOCK_MONOTONIC` keeps counting while the Mac sleeps and ignores clock changes.
    nonisolated static func systemContinuousTime() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000
    }

    /// At launch: whatever fell due while the app was not running is missed.
    func start(now: Date) {
        evaluate(now: now, missedCause: .appNotRunning)
    }

    /// A scheduled check, a System wake or a will-sleep: reports what became due or missed since the
    /// last evaluation, then schedules the next check.
    func evaluate(now: Date, missedCause: MissedCause = .systemSleep) {
        guard !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }

        // First launch ever (no stored instant): nothing is missed or due. Recording `now` gives the
        // next launch a window to look back over.
        let found = lastEvaluatedAt.map { last in
            occurrences(after: last, through: now, seenAt: now, missedCause: missedCause)
        }
        conclude(found ?? Found(), at: now)
    }

    /// The Alarm list changed: reschedule, never look back. An Alarm for 07:00 saved at 07:00:10
    /// must not ring; it waits for its next Occurrence.
    func alarmsDidChange(now: Date) {
        guard !isEvaluating else { return }
        recordEvaluation(at: now)
        scheduleNextCheck(after: now)
    }

    /// The system clock or time zone changed. Since the last evaluation, the clock has both run
    /// and jumped, and only the time that really passed is evaluated, measured on the continuous
    /// clock. So the Occurrences the Mac slept through are still reported when this change reaches
    /// the app before the wake does, and the Occurrences the clock jumped over are never looked
    /// back on.
    func clockDidChange(now: Date) {
        guard !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }

        var found = Found()
        if let last = lastEvaluatedAt, let lastContinuous = lastEvaluatedContinuousTime {
            // What `now` would read had the clock not been changed.
            let unchangedNow = last.addingTimeInterval(continuousTime() - lastContinuous)
            found = occurrences(
                after: last, through: min(now, unchangedNow), seenAt: unchangedNow, missedCause: .systemSleep)
        }
        conclude(found, at: now)
    }

    /// What one evaluation found.
    private struct Found {
        var due: [Occurrence] = []
        var missed: [MissedOccurrence] = []
        var spentOneTimeAlarms: Set<UUID> = []
    }

    private var lastEvaluatedAt: Date? {
        defaults.object(forKey: Self.lastEvaluatedKey) as? Date
    }

    /// Sorts every Occurrence of an Armed Alarm in (start, end] into due or missed, by how long
    /// before `seenAt` it fell.
    private func occurrences(after start: Date, through end: Date, seenAt: Date, missedCause: MissedCause) -> Found {
        var found = Found()
        for alarm in store.alarms where alarm.isArmed {
            let dates = calendar.occurrences(of: alarm, after: start, through: end)
            if alarm.isOneTime, !dates.isEmpty { found.spentOneTimeAlarms.insert(alarm.id) }
            for date in dates {
                let occurrence = Occurrence(alarmID: alarm.id, date: date)
                if seenAt.timeIntervalSince(date) <= Self.onTimeTolerance {
                    found.due.append(occurrence)
                } else {
                    found.missed.append(MissedOccurrence(occurrence: occurrence, cause: missedCause))
                }
            }
        }
        found.due.sort { ($0.date, $0.alarmID.uuidString) < ($1.date, $1.alarmID.uuidString) }
        found.missed.sort {
            ($0.occurrence.date, $0.occurrence.alarmID.uuidString) < (
                $1.occurrence.date, $1.occurrence.alarmID.uuidString
            )
        }
        return found
    }

    private func conclude(_ found: Found, at now: Date) {
        // Persist before calling back, so a callback never sees a stale window.
        recordEvaluation(at: now)
        // A one-time Alarm rings once, then Disarms itself (spec decision 22). A missed one Disarms
        // too, otherwise it would ring a day later, unasked.
        store.disarm(ids: found.spentOneTimeAlarms)
        if !found.missed.isEmpty { onMissed?(found.missed) }
        if !found.due.isEmpty { onDue?(found.due) }
        scheduleNextCheck(after: now)
    }

    private func recordEvaluation(at now: Date) {
        defaults.set(now, forKey: Self.lastEvaluatedKey)
        lastEvaluatedContinuousTime = continuousTime()
    }

    private func scheduleNextCheck(after now: Date) {
        if let upcoming = UpcomingOccurrence.next(in: store.alarms, after: now, calendar: calendar) {
            // The check reads the clock when it runs — the timer's own time is never trusted.
            deadlines.schedule(at: upcoming.date) { [weak self] in
                guard let self else { return }
                evaluate(now: currentDate())
            }
        } else {
            deadlines.cancel()
        }
    }
}
