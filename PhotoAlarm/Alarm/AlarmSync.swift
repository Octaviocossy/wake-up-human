import Foundation
import SwiftData

/// Reconciles the Alarms with AlarmKit: the one writer of an Alarm's weekly System alarm, so the list, the editor
/// and every launch converge on the same registrations. One idempotent pass, run on launch (alarms can stop
/// ringing after an iOS update, so every enabled Alarm is re-registered each time) and after every change.
///
/// It never touches a System alarm that is ringing, and never touches the Follow-up of an open Wake-up session:
/// a launch must not silence a Ring or break the re-alarm loop (ADR-0025).
struct AlarmSync: Sendable {
    /// What one pass did. `cancelled` lists only the System alarms removed because nothing owns them; the cancel
    /// that precedes re-scheduling an enabled Alarm is not counted.
    struct Report: Sendable, Equatable {
        var scheduled: [UUID] = []
        var cancelled: [UUID] = []
        var failed: [UUID] = []
    }

    let scheduler: any AlarmScheduler
    let loop: WakeUpLoop
    private let gate = Gate()

    init(scheduler: any AlarmScheduler, loop: WakeUpLoop) {
        self.scheduler = scheduler
        self.loop = loop
    }

    /// Re-registers every enabled Alarm and removes System alarms nothing owns. Passes run one at a time, whoever
    /// asks, and a cancelled caller (a view's task) cannot abandon one between a cancel and the re-schedule.
    func reconcile(_ alarms: [WakeAlarmSnapshot]) async -> Report {
        await Task {
            await gate.acquire()
            let report = await pass(alarms)
            await gate.release()
            return report
        }.value
    }

    private func pass(_ alarms: [WakeAlarmSnapshot]) async -> Report {
        var report = Report()
        let enabled = alarms.filter(\.isEnabled)

        // Blind to AlarmKit (for example, no authorization): nothing is cancelled and nothing is re-scheduled, so
        // whatever is registered keeps ringing; a Ring that is under way cannot be told apart from a quiet alarm.
        let existing: [ScheduledSystemAlarm]
        do {
            existing = try scheduler.scheduledAlarms()
        } catch {
            Log.alarm.error("reconcile cannot read the System alarms: \(error.localizedDescription, privacy: .public)")
            report.failed = enabled.map(\.id)
            return report
        }
        let registered = Set(existing.map(\.id))
        let alerting = Set(existing.filter { $0.state == .alerting }.map(\.id))

        // Re-register each enabled Alarm that is not ringing: cancel the old registration, then schedule it again.
        for alarm in enabled where !alerting.contains(alarm.id) {
            guard !alarm.weekdays.isEmpty else {
                report.failed.append(alarm.id)
                continue
            }
            if registered.contains(alarm.id) {
                try? scheduler.cancel(id: alarm.id)
            }
            do {
                try await scheduler.scheduleWeekly(
                    id: alarm.id, hour: alarm.hour, minute: alarm.minute, weekdays: alarm.weekdays)
                report.scheduled.append(alarm.id)
            } catch {
                let reason = error.localizedDescription
                Log.alarm.error("reconcile could not schedule \(alarm.id.uuidString, privacy: .public): \(reason)")
                report.failed.append(alarm.id)
            }
        }

        // Remove what nothing owns: disabled or deleted Alarms, stale Follow-ups of closed sessions, debug alarms.
        // Without the open sessions' Follow-ups to protect, an unowned System alarm might be one, so none is removed.
        if let protected = try? await loop.pendingFollowUpIDs() {
            let owned = Set(enabled.map(\.id)).union(protected).union(alerting)
            let orphans = registered.subtracting(owned).sorted { $0.uuidString < $1.uuidString }
            for orphan in orphans {
                do {
                    try scheduler.cancel(id: orphan)
                    report.cancelled.append(orphan)
                } catch {
                    let reason = error.localizedDescription
                    Log.alarm.error("reconcile could not cancel \(orphan.uuidString, privacy: .public): \(reason)")
                }
            }
        } else {
            Log.alarm.error("reconcile cannot read the open sessions, so it leaves unowned System alarms alone")
        }

        let (scheduled, cancelled, failed) = (report.scheduled.count, report.cancelled.count, report.failed.count)
        Log.alarm.info("reconcile scheduled \(scheduled) cancelled \(cancelled) failed \(failed)")
        return report
    }

    /// A mutex for passes: `scheduleWeekly` awaits, so two passes would otherwise interleave their cancels and
    /// schedules. Copies of an `AlarmSync` share the gate.
    private actor Gate {
        private var isBusy = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func acquire() async {
            if isBusy {
                await withCheckedContinuation { waiters.append($0) }
            } else {
                isBusy = true
            }
        }

        func release() {
            if waiters.isEmpty {
                isBusy = false
            } else {
                waiters.removeFirst().resume()
            }
        }
    }
}

extension AlarmSync {
    /// Reconciles every Alarm stored in `context`. A failed fetch throws instead of reconciling: an empty list
    /// would make every System alarm look unowned and cancel it.
    @MainActor
    func reconcile(in context: ModelContext) async throws -> Report {
        let alarms = try context.fetch(FetchDescriptor<WakeAlarm>())
        return await reconcile(alarms.map(\.snapshot))
    }
}
