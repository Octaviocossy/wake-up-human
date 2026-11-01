import Foundation
import Testing

@testable import PhotoAlarm

struct SmokeTests {
    @Test @MainActor func testHostIsTheApp() {
        _ = RootView()
        #expect(Bundle.main.bundleIdentifier == "com.ovct.photoalarm")
    }
}
