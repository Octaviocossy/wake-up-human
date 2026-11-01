import Foundation

/// The app's shared collaborators. The alarm-button intents run in the app's own process, so they and the
/// screens use the same `WakeUpLoop` — one actor serializing every change to the mission state.
enum AppEnvironment {
    static let scheduler: any AlarmScheduler = AlarmKitScheduler()
    static let matcher: any ObjectMatcher = VisionObjectMatcher()
    static let loop = WakeUpLoop(
        store: MissionStateStore(directory: .applicationSupportDirectory), scheduler: scheduler)
    /// The one reconcile of Alarms with AlarmKit; every caller shares it so passes never interleave.
    static let alarmSync = AlarmSync(scheduler: scheduler, loop: loop)
}
