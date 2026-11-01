import AlarmKit
import AppIntents

/// Runs when the user taps "Take photo" on a Ring (the secondary button, `.custom` behavior). It
/// opens the app; the mission screen itself arrives with the mission child.
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
            await SpikeFollowUp.record(.openMission, alarmID: id)
        #endif
        return .result()
    }
}
