import Foundation
import Observation

/// The Alarm list, persisted in `UserDefaults` as Codable JSON (spec decision 23). It owns its own
/// key, so no shared preferences type exists for parallel slices to collide on.
@MainActor
@Observable
final class AlarmStore {
    static let defaultsKey = "alarms"

    /// Always sorted by time of day, then by `id` for a stable order (spec decision 35).
    private(set) var alarms: [Alarm]

    /// Called after every mutation that changed something, after persisting.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        alarms = Self.load(from: defaults)
    }

    /// A new Alarm is Armed.
    @discardableResult
    func add(hour: Int, minute: Int, weekdays: Set<Weekday>) -> Alarm {
        let alarm = Alarm(id: UUID(), hour: hour, minute: minute, weekdays: weekdays, isArmed: true)
        alarms.append(alarm)
        commit()
        return alarm
    }

    /// Saving an edit re-Arms the Alarm (spec decision 35). Never asks for the Typing challenge
    /// (spec decision 7).
    func update(id: UUID, hour: Int, minute: Int, weekdays: Set<Weekday>) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].hour = hour
        alarms[index].minute = minute
        alarms[index].weekdays = weekdays
        alarms[index].isArmed = true
        commit()
    }

    /// Arm or Disarm. Free: never asks for the Typing challenge (spec decision 7).
    func setArmed(_ isArmed: Bool, id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }), alarms[index].isArmed != isArmed else { return }
        alarms[index].isArmed = isArmed
        commit()
    }

    /// Free, like Disarm (spec decision 35, "Eliminar").
    func delete(id: UUID) {
        guard alarms.contains(where: { $0.id == id }) else { return }
        alarms.removeAll { $0.id == id }
        commit()
    }

    /// Disarms every Armed Alarm in `ids`; the scheduler uses it for one-time Alarms. A no-op — no
    /// `onChange` — when nothing changed.
    func disarm(ids: Set<UUID>) {
        var changed = false
        for index in alarms.indices where ids.contains(alarms[index].id) && alarms[index].isArmed {
            alarms[index].isArmed = false
            changed = true
        }
        if changed { commit() }
    }

    private func commit() {
        alarms.sort { ($0.minuteOfDay, $0.id.uuidString) < ($1.minuteOfDay, $1.id.uuidString) }
        do {
            defaults.set(try JSONEncoder().encode(alarms), forKey: Self.defaultsKey)
        } catch {
            Log.alarms.error("Could not save the Alarm list: \(error.localizedDescription)")
        }
        onChange?()
    }

    private static func load(from defaults: UserDefaults) -> [Alarm] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [] }
        do {
            let alarms = try JSONDecoder().decode([Alarm].self, from: data)
            return alarms.sorted { ($0.minuteOfDay, $0.id.uuidString) < ($1.minuteOfDay, $1.id.uuidString) }
        } catch {
            Log.alarms.error("Could not read the Alarm list, starting empty: \(error.localizedDescription)")
            return []
        }
    }
}
