import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var objects: [TargetObject]

    var body: some View {
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
                            matcher: VisionObjectMatcher(),
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
}
