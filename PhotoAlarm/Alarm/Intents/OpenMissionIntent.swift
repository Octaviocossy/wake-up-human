import AlarmKit
import AppIntents

/// Runs when the user taps "Take photo" on a Ring (the secondary button, `.custom` behavior). It arms
/// a Follow-up exactly like Stop (spec decision 15) and opens the app, whose root view then shows only
/// the mission screen.
struct OpenMissionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Take photo"
    static let supportedModes: IntentModes = .foreground
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID") var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        Log.intents.info("open-mission intent for \(id.uuidString, privacy: .public)")
        try? AlarmManager.shared.stop(id: id)
        #if DEBUG
            await IntentEventLog.shared.append(IntentEvent(kind: .openMission, alarmID: id, date: .now))
        #endif
        do {
            try await AppEnvironment.loop.ringEnded(systemAlarmID: id, via: .takePhoto)
        } catch {
            Log.intents.error(
                "open-mission intent could not arm a follow-up: \(error.localizedDescription, privacy: .public)")
        }
        return .result()
    }
}
