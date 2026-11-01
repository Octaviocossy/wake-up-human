#if DEBUG
    import SwiftUI

    struct DebugMenuView: View {
        var body: some View {
            List {
                NavigationLink("AlarmKit spike") { AlarmSpikeView() }
                NavigationLink("Vision spike") { VisionSpikeView() }
            }
            .navigationTitle("Debug")
        }
    }
#endif
