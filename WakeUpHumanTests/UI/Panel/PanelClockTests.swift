import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct PanelClockTests {
    @Test func tickReplacesNowWithTheGivenDate() {
        let clock = PanelClock(now: Date(timeIntervalSince1970: 0))
        let later = Date(timeIntervalSince1970: 1_000)

        clock.tick(now: later)

        #expect(clock.now == later)
    }
}
