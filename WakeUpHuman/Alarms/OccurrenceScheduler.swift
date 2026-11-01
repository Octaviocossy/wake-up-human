import Foundation

/// Reports every due Occurrence of an Armed Alarm on time and every missed one, however many — and
/// never rings one late (product invariant 5). Only a check the app ran on its own, with the Mac
/// awake since the previous evaluation, can find an Occurrence due. Whatever a launch, a System wake
/// or a check after System sleep finds is missed, however recently it fell.
@MainActor
final class OccurrenceScheduler {
    /// An Occurrence that the app's own check finds more than this long after its time is missed,
    /// never rung (invariant 5). It absorbs timer and main-actor latency only, and never applies
    /// after a launch or System sleep.
    nonisolated static let onTimeTolerance: TimeInterval = 30
    /// Less System sleep than this between two evaluations counts as none. The two monotonic clocks
    /// are read nanoseconds apart, and a real System sleep lasts several seconds at least.
    static let sleepThreshold: TimeInterval = 1
    static let lastEvaluatedKey = "lastEvaluatedAt"

    /// Every Occurrence due together, in one call (spec decision 15: one Ring).
    var onDue: (@MainActor ([Occurrence]) -> Void)?
    /// Every Occurrence missed since the last evaluation, in one call. A long absence is included,
    /// so none goes unreported (ADR-0027); the missed notice (#17) may collapse them.
    var onMissed: (@MainActor ([MissedOccurrence]) -> Void)?

    private let store: AlarmStore
    private let deadlines: DeadlineScheduling
    private let calendar: OccurrenceCalendar
    private let defaults: UserDefaults
    private let currentDate: @MainActor () -> Date
    private let monotonicClock: @MainActor () -> MonotonicReading
    /// `monotonicClock()` when this process last recorded an evaluation; `nil` until it first does.
    private var lastEvaluatedReading: MonotonicReading?
    private var isEvaluating = false

    init(
        store: AlarmStore,
        deadlines: DeadlineScheduling,
        calendar: OccurrenceCalendar = OccurrenceCalendar(),
        defaults: UserDefaults = .standard,
        currentDate: @escaping @MainActor () -> Date = { Date() },
        monotonicClock: @escaping @MainActor () -> MonotonicReading = { MonotonicReading.now() }
    ) {
        self.store = store
        self.deadlines = deadlines
        self.calendar = calendar
        self.defaults = defaults
        self.currentDate = currentDate
        self.monotonicClock = monotonicClock
    }

    /// At launch: whatever fell due while the app was not running is missed, however recently.
    func start(now: Date) {
        evaluate(now: now, window: Window(end: now, watch: .lapsed(.appNotRunning)))
    }

    /// The Mac is about to enter System sleep. Settling everything up to now while the app still
    /// watches leaves the wake a window that covers the sleep alone.
    func systemWillSleep(now: Date) {
        evaluateOwnCheck(now: now)
    }

    /// The Mac woke from System sleep: whatever fell due during it is missed, however recently.
    func systemDidWake(now: Date) {
        evaluate(now: now, window: Window(end: now, watch: .lapsed(.systemSleep)))
    }

    /// The Alarm list changed: reschedule, never look back. An Alarm for 07:00 saved at 07:00:10
    /// must not ring; it waits for its next Occurrence.
    func alarmsDidChange(now: Date) {
        evaluate(now: now, window: nil)
    }

    /// The system clock or time zone changed. Since the last evaluation the clock has both run and
    /// jumped, and only the time that really passed is evaluated, measured on the monotonic clock.
    /// So what the Mac slept through is still reported when this change reaches the app before the
    /// wake does, and what the clock jumped over is never looked back on.
    func clockDidChange(now: Date) {
        let reading = monotonicClock()
        var window: Window?
        if let last = lastEvaluatedAt, let lastReading = lastEvaluatedReading {
            // What `now` would read had the clock not been changed.
            let unchangedNow = last.addingTimeInterval(reading.elapsed(since: lastReading))
            window = Window(end: min(now, unchangedNow), watch: ownCheckWatch(seenAt: unchangedNow, reading: reading))
        }
        evaluate(now: now, window: window)
    }

    /// Whether the app was watching over a window, which decides what an Occurrence in it can be.
    private enum Watch {
        /// The app was not watching — it was not running, or the Mac was asleep — so every
        /// Occurrence is missed, for this cause.
        case lapsed(MissedCause)
        /// The app was watching and checked at `seenAt`: an Occurrence within `onTimeTolerance`
        /// before it is due, and an older one is missed because the check ran late.
        case kept(seenAt: Date)

        /// `nil` when `occurrence` is due; otherwise why it is missed.
        func missedCause(of occurrence: Occurrence) -> MissedCause? {
            switch self {
            case .lapsed(let cause):
                cause
            case .kept(let seenAt):
                seenAt.timeIntervalSince(occurrence.date) <= OccurrenceScheduler.onTimeTolerance ? nil : .checkRanLate
            }
        }
    }

    /// What one evaluation looks back on: every Occurrence after the last evaluation, through `end`.
    private struct Window {
        let end: Date
        let watch: Watch
    }

    /// The Occurrences of one window, sorted into due and missed, and the one-time Alarms they spend.
    private struct SortedOccurrences {
        var due: [Occurrence] = []
        var missed: [MissedOccurrence] = []
        var spentOneTimeAlarms: Set<UUID> = []
    }

    private var lastEvaluatedAt: Date? {
        defaults.object(forKey: Self.lastEvaluatedKey) as? Date
    }

    /// A check the app ran on its own, at a scheduled deadline or before System sleep.
    private func evaluateOwnCheck(now: Date) {
        evaluate(now: now, window: Window(end: now, watch: ownCheckWatch(seenAt: now, reading: monotonicClock())))
    }

    /// The app's own check watched over its window only if the Mac stayed awake since the last
    /// evaluation. A wall-clock deadline that passes during System sleep runs its check on wake, and
    /// that check may reach the app before `systemDidWake` does.
    private func ownCheckWatch(seenAt: Date, reading: MonotonicReading) -> Watch {
        // Before this process's first evaluation, nothing vouches that the Mac stayed awake.
        guard let lastReading = lastEvaluatedReading, reading.asleep(since: lastReading) < Self.sleepThreshold else {
            return .lapsed(.systemSleep)
        }
        return .kept(seenAt: seenAt)
    }

    /// Sorts every Occurrence of an Armed Alarm in `window`, records the evaluation at `now`,
    /// reports what it found and schedules the next check. With no `window`, or no stored
    /// evaluation — the first launch ever — it looks back on nothing; recording `now` then gives the
    /// next evaluation a window to look back over.
    private func evaluate(now: Date, window: Window?) {
        // `store.disarm` below calls back into `alarmsDidChange`, which must not re-enter.
        guard !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }

        var sorted = SortedOccurrences()
        if let window, let start = lastEvaluatedAt {
            sorted = sortOccurrences(after: start, in: window)
        }
        // Persist before calling back, so a callback never sees a stale window.
        defaults.set(now, forKey: Self.lastEvaluatedKey)
        lastEvaluatedReading = monotonicClock()
        // A one-time Alarm rings once, then Disarms itself (spec decision 22). A missed one Disarms
        // too, otherwise it would ring a day later, unasked.
        store.disarm(ids: sorted.spentOneTimeAlarms)
        if !sorted.missed.isEmpty { onMissed?(sorted.missed) }
        if !sorted.due.isEmpty { onDue?(sorted.due) }
        scheduleNextCheck(after: now)
    }

    private func sortOccurrences(after start: Date, in window: Window) -> SortedOccurrences {
        var sorted = SortedOccurrences()
        var occurrences: [Occurrence] = []
        for alarm in store.alarms where alarm.isArmed {
            let dates = calendar.occurrences(of: alarm, after: start, through: window.end)
            if alarm.isOneTime, !dates.isEmpty { sorted.spentOneTimeAlarms.insert(alarm.id) }
            occurrences += dates.map { Occurrence(alarmID: alarm.id, date: $0) }
        }
        // Chronological, and Occurrences at the same instant in a stable order.
        occurrences.sort { ($0.date, $0.alarmID.uuidString) < ($1.date, $1.alarmID.uuidString) }
        for occurrence in occurrences {
            if let cause = window.watch.missedCause(of: occurrence) {
                sorted.missed.append(MissedOccurrence(occurrence: occurrence, cause: cause))
            } else {
                sorted.due.append(occurrence)
            }
        }
        return sorted
    }

    private func scheduleNextCheck(after now: Date) {
        if let upcoming = UpcomingOccurrence.next(in: store.alarms, after: now, calendar: calendar) {
            // The check reads the clock when it runs — the timer's own time is never trusted.
            deadlines.schedule(at: upcoming.date) { [weak self] in
                guard let self else { return }
                evaluateOwnCheck(now: currentDate())
            }
        } else {
            deadlines.cancel()
        }
    }
}
