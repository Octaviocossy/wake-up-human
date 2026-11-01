import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var missionOpen = false

    var body: some View {
        Group {
            if missionOpen {
                // Lockdown (spec decision 6): with a Wake-up session open the app shows only the mission,
                // whatever opened it — no navigation, no Object setup, no Debug link.
                MissionView(
                    repository: TargetObjectRepository(context: modelContext),
                    onSessionsClosed: { missionOpen = false })
            } else {
                normalContent
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await refreshMissionOpen()
            await reconcileAlarms()
        }
        // The intent that launched the app may finish after the first refresh above.
        .onReceive(NotificationCenter.default.publisher(for: .wakeUpSessionsChanged)) { _ in
            Task { await refreshMissionOpen() }
        }
    }

    private var normalContent: some View {
        NavigationStack { AlarmListView(context: modelContext) }
    }

    /// Re-registers every enabled Alarm on launch and whenever the app becomes active: alarms can stop ringing
    /// after an iOS update, and this is also what removes System alarms nothing owns. In every state, mission
    /// lockdown included.
    private func reconcileAlarms() async {
        do {
            _ = try await AppEnvironment.alarmSync.reconcile(in: modelContext)
        } catch {
            Log.alarm.error("could not read the alarms to reconcile: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshMissionOpen() async {
        do {
            missionOpen = try await AppEnvironment.loop.hasOpenSession()
        } catch {
            Log.mission.error("could not read the sessions: \(error.localizedDescription, privacy: .public)")
        }
    }
}
