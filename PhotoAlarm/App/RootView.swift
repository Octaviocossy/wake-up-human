import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Photo Alarm") }
                #if DEBUG
                    Section { NavigationLink("Debug") { DebugMenuView() } }
                #endif
            }
            .navigationTitle("Photo Alarm")
        }
    }
}
