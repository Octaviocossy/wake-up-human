import Foundation

/// Fires every due Occurrence of an Armed Alarm on time and reports every one missed — and never
/// rings one late (product invariant 5). It decides "late" from the clock at evaluation time, so a
/// timer that fires after System sleep, or a launch after the app was closed, turns into a missed
/// Occurrence instead of a Ring.
@MainActor
final class OccurrenceScheduler {
    /// An Occurrence first seen more than this long after its time is missed, never rung (invariant 5).
    /// Absorbs timer, main-actor and launch latency only; anything coming back from System sleep or
    /// an app launch is virtually always later than this.
    static let onTimeTolerance: TimeInterval = 30
    /// Missed Occurrences older than this are stale and dropped silently, so a long absence yields at
    /// most one missed Occurrence per Alarm.
    static let missedLookback: TimeInterval = 24 * 60 * 60
    static let lastEvaluatedKey = "lastEvaluatedAt"

    /// Every Occurrence due together, in one call (spec decision 15: one Ring).
    var onDue: (@MainActor ([Occurrence]) -> Void)?
    var onMissed: (@MainActor ([MissedOccurrence]) -> Void)?

    private let store: AlarmStore
    private let deadlines: DeadlineScheduling
    private let calendar: OccurrenceCalendar
    private let defaults: UserDefaults
    private let currentDate: @MainActor () -> Date
    private var isEvaluating = false

    init(
        store: AlarmStore,
        deadlines: DeadlineScheduling,
        calendar: OccurrenceCalendar = OccurrenceCalendar(),
        defaults: UserDefaults = .standard,
        currentDate: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.deadlines = deadlines
        self.calendar = calendar
        self.defaults = defaults
        self.currentDate = currentDate
    }

    /// At launch: whatever fell due while the app was not running is missed.
    func start(now: Date) {
        evaluate(now: now, missedCause: .appNotRunning)
    }

    /// A timer fire, a wake or a will-sleep: reports what became due or missed since the last
    /// evaluation, then schedules the next wake.
    func evaluate(now: Date, missedCause: MissedCause = .systemSleep) {
        guard !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }

        // First launch ever: nothing is missed or due. Record the instant so the next launch has a
        // window to look back over.
        guard let last = defaults.object(forKey: Self.lastEvaluatedKey) as? Date else {
            recordEvaluation(at: now)
            scheduleNextWake(after: now)
            return
        }

        let windowStart = max(last, now.addingTimeInterval(-Self.missedLookback))
        var due: [Occurrence] = []
        var missed: [MissedOccurrence] = []
        var spentOneTimeAlarms: Set<UUID> = []
        for alarm in store.alarms where alarm.isArmed {
            let dates = calendar.occurrences(of: alarm, after: windowStart, through: now)
            if alarm.isOneTime, !dates.isEmpty { spentOneTimeAlarms.insert(alarm.id) }
            for date in dates {
                let occurrence = Occurrence(alarmID: alarm.id, date: date)
                if now.timeIntervalSince(date) <= Self.onTimeTolerance {
                    due.append(occurrence)
                } else {
                    missed.append(MissedOccurrence(occurrence: occurrence, cause: missedCause))
                }
            }
        }
        due.sort { ($0.date, $0.alarmID.uuidString) < ($1.date, $1.alarmID.uuidString) }
        missed.sort {
            ($0.occurrence.date, $0.occurrence.alarmID.uuidString) < (
                $1.occurrence.date, $1.occurrence.alarmID.uuidString
            )
        }

        // Persist before calling back, so a callback never sees a stale window.
        recordEvaluation(at: now)
        // A one-time Alarm rings once, then Disarms itself (spec decision 22). A missed one Disarms
        // too, otherwise it would ring a day later, unasked.
        store.disarm(ids: spentOneTimeAlarms)
        if !missed.isEmpty { onMissed?(missed) }
        if !due.isEmpty { onDue?(due) }
        scheduleNextWake(after: now)
    }

    /// The Alarm list changed: reschedule, never look back. An Alarm for 07:00 saved at 07:00:10
    /// must not ring; it waits for its next Occurrence.
    func alarmsDidChange(now: Date) {
        guard !isEvaluating else { return }
        recordEvaluation(at: now)
        scheduleNextWake(after: now)
    }

    /// The system clock or time zone changed: the same as an edit, never look back.
    func clockDidChange(now: Date) {
        alarmsDidChange(now: now)
    }

    private func recordEvaluation(at now: Date) {
        defaults.set(now, forKey: Self.lastEvaluatedKey)
    }

    private func scheduleNextWake(after now: Date) {
        if let upcoming = UpcomingOccurrence.next(in: store.alarms, after: now, calendar: calendar) {
            // The wake reads the clock when it fires — the timer's own time is never trusted.
            deadlines.schedule(at: upcoming.date) { [weak self] in
                guard let self else { return }
                evaluate(now: currentDate())
            }
        } else {
            deadlines.cancel()
        }
    }
}
