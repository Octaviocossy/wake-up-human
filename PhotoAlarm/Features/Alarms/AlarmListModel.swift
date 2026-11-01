import Foundation
import Observation
import SwiftData

/// What the Alarm list does: enabling behind the gate, saving, deleting, and the reconcile that follows each
/// change so AlarmKit always matches the stored Alarms.
@MainActor
@Observable
final class AlarmListModel {
    private let context: ModelContext
    private let repository: TargetObjectRepository
    private let scheduler: any AlarmScheduler
    private let sync: AlarmSync

    /// Why the last attempt to enable an Alarm was refused, so the list can show the reason and a way out.
    private(set) var enableBlock: AlarmRules.EnableBlock?
    /// Alarms the last reconcile could not register with AlarmKit.
    private(set) var failedAlarmIDs: Set<UUID> = []
    private(set) var errorMessage: String?

    init(
        context: ModelContext,
        scheduler: any AlarmScheduler = AppEnvironment.scheduler,
        sync: AlarmSync = AppEnvironment.alarmSync
    ) {
        self.context = context
        repository = TargetObjectRepository(context: context)
        self.scheduler = scheduler
        self.sync = sync
    }

    /// Enables or disables `alarm`. Enabling is refused, leaving the Alarm disabled, until the Target object is
    /// registered (spec decision 7) and AlarmKit is authorized; the first enable asks for that authorization.
    func setEnabled(_ alarm: WakeAlarm, to enabled: Bool) async {
        clearMessages()
        if enabled {
            let block = await currentEnableBlock()
            enableBlock = block
            guard block == nil else { return }
        }
        alarm.isEnabled = enabled
        await persistAndReconcile()
    }

    /// Updates `alarm`, or creates an Alarm when it is nil. A new Alarm starts enabled when the gate passes and
    /// disabled otherwise, with the reason in `enableBlock`. Returns false when nothing was saved.
    @discardableResult
    func save(_ alarm: WakeAlarm?, hour: Int, minute: Int, weekdayNumbers: [Int]) async -> Bool {
        clearMessages()
        guard AlarmRules.canSave(weekdayNumbers: weekdayNumbers) else { return false }
        let numbers = Set(weekdayNumbers.filter { WakeAlarm.weekday(for: $0) != nil }).sorted()
        if let alarm {
            alarm.hour = hour
            alarm.minute = minute
            alarm.weekdayNumbers = numbers
        } else {
            let block = await currentEnableBlock()
            enableBlock = block
            context.insert(WakeAlarm(hour: hour, minute: minute, weekdayNumbers: numbers, isEnabled: block == nil))
        }
        return await persistAndReconcile()
    }

    /// Deletes the Alarms; the reconcile that follows cancels their System alarms.
    func delete(_ alarms: [WakeAlarm]) async {
        clearMessages()
        for alarm in alarms {
            context.delete(alarm)
        }
        await persistAndReconcile()
    }

    /// Brings AlarmKit in line with every stored Alarm and records which ones could not be registered.
    func reconcile() async {
        do {
            failedAlarmIDs = Set(try await sync.reconcile(in: context).failed)
        } catch {
            errorMessage = "Could not read your alarms: \(error.localizedDescription)"
        }
    }

    private func clearMessages() {
        enableBlock = nil
        errorMessage = nil
    }

    /// The Target object is checked first, so the user is not asked for AlarmKit permission for an Alarm that
    /// could not be enabled anyway. A store that cannot be read counts as not registered: it refuses, never enables.
    private func currentEnableBlock() async -> AlarmRules.EnableBlock? {
        let isRegistered = (try? repository.isRegistered()) ?? false
        let isAuthorized = isRegistered ? await scheduler.requestAuthorization() : false
        return AlarmRules.enableBlock(isTargetRegistered: isRegistered, isAuthorized: isAuthorized)
    }

    /// Saves the context and reconciles. A failed save is rolled back, so the screen shows what is stored.
    @discardableResult
    private func persistAndReconcile() async -> Bool {
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "Could not save your alarms: \(error.localizedDescription)"
            return false
        }
        await reconcile()
        return true
    }
}
