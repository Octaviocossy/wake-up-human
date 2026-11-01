import AlarmKit
import AppIntents
import SwiftUI

struct AlarmKitScheduler: AlarmScheduler {
    func requestAuthorization() async -> Bool {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
        @unknown default:
            return false
        }
    }

    func scheduleWeekly(id: UUID, hour: Int, minute: Int, weekdays: Set<Locale.Weekday>) async throws {
        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: .weekly(Array(weekdays))))
        _ = try await AlarmManager.shared.schedule(
            id: id, configuration: Self.configuration(id: id, schedule: schedule))
        Log.alarm.info("scheduled weekly \(id.uuidString, privacy: .public) at \(hour):\(minute)")
    }

    func scheduleOneOff(id: UUID, at date: Date) async throws {
        _ = try await AlarmManager.shared.schedule(
            id: id, configuration: Self.configuration(id: id, schedule: .fixed(date)))
        Log.alarm.info(
            "scheduled one-off \(id.uuidString, privacy: .public) at \(date.ISO8601Format(), privacy: .public)")
    }

    func cancel(id: UUID) throws {
        try AlarmManager.shared.cancel(id: id)
        Log.alarm.info("cancelled \(id.uuidString, privacy: .public)")
    }

    func scheduledAlarms() throws -> [ScheduledSystemAlarm] {
        try AlarmManager.shared.alarms.map { alarm in
            let state: ScheduledSystemAlarm.State =
                switch alarm.state {
                case .scheduled: .scheduled
                case .alerting: .alerting
                default: .other
                }
            return ScheduledSystemAlarm(id: alarm.id, state: state)
        }
    }

    /// One presentation for every System alarm: no countdown, "Stop" + "Take photo".
    /// Titles are plain literals, never localization keys (brief risk: raw keys after a reboot).
    static func configuration(id: UUID, schedule: Alarm.Schedule) -> AlarmManager.AlarmConfiguration<PhotoAlarmMetadata>
    {
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert()),
            metadata: PhotoAlarmMetadata(),
            tintColor: .orange)
        return .alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: OpenMissionIntent(alarmID: id.uuidString),
            sound: .default)
    }

    private static func alert() -> AlarmPresentation.Alert {
        let takePhoto = AlarmButton(text: "Take photo", textColor: .white, systemImageName: "camera")
        if #available(iOS 26.1, *) {
            // The system draws its own Stop button from iOS 26.1 on; `stopButton` is deprecated there.
            return AlarmPresentation.Alert(
                title: "Wake up", secondaryButton: takePhoto, secondaryButtonBehavior: .custom)
        } else {
            let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
            return AlarmPresentation.Alert(
                title: "Wake up", stopButton: stop, secondaryButton: takePhoto, secondaryButtonBehavior: .custom)
        }
    }
}
