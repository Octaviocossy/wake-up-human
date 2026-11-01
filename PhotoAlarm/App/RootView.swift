import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var objects: [TargetObject]
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
        }
        // The intent that launched the app may finish after the first refresh above.
        .onReceive(NotificationCenter.default.publisher(for: .wakeUpSessionsChanged)) { _ in
            Task { await refreshMissionOpen() }
        }
    }

    private var normalContent: some View {
        NavigationStack {
            List {
                Section { Text("Photo Alarm") }
                Section("Target object") {
                    if let object = objects.first {
                        Text("Registered · \(object.references.count) references")
                    } else {
                        Text("Not registered")
                    }
                    NavigationLink("Set up target object") {
                        ObjectSetupView(
                            matcher: AppEnvironment.matcher,
                            repository: TargetObjectRepository(context: modelContext)
                        )
                    }
                }
                #if DEBUG
                    Section { NavigationLink("Debug") { DebugMenuView() } }
                #endif
            }
            .navigationTitle("Photo Alarm")
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
