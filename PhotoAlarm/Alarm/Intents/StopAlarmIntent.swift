import AlarmKit
import AppIntents

/// Runs when the user taps "Stop" on a Ring. One of the only two hooks into the system alert
/// (ADR-0025): a dismissal for which iOS runs no intent ends the re-alarm loop on purpose.
struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID") var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        Log.intents.info("stop intent for \(id.uuidString, privacy: .public)")
        try? AlarmManager.shared.stop(id: id)
        #if DEBUG
            await IntentEventLog.shared.append(IntentEvent(kind: .stop, alarmID: id, date: .now))
        #endif
        do {
            try await AppEnvironment.loop.ringEnded(systemAlarmID: id, via: .stop)
        } catch {
            Log.intents.error("stop intent could not arm a follow-up: \(error.localizedDescription, privacy: .public)")
        }
        return .result()
    }
}
