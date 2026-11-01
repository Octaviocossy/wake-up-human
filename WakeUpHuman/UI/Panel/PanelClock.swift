import Foundation
import Observation

/// The panel's notion of "now", advanced once a second only while the panel is visible
/// (`PanelController` drives it). Sections read `now` for countdowns instead of running timers.
@MainActor
@Observable
final class PanelClock {
    private(set) var now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    func tick(now: Date = Date()) {
        self.now = now
    }
}
