import Foundation

/// A repeating timer behind a seam, so the volume ramp's 0.5 s tick can be driven by hand in tests.
@MainActor
protocol RepeatingTicker: AnyObject {
    /// Calls `tick` every `interval` seconds until `stop()`. Starting again replaces the schedule.
    func start(every interval: TimeInterval, tick: @escaping @MainActor () -> Void)
    func stop()
}

/// A `Timer` on the main run loop in `.common` mode, so it keeps firing while a menu or a panel
/// tracks events — the same arrangement as the panel controller's clock.
@MainActor
final class RunLoopTicker: RepeatingTicker {
    private var timer: Timer?

    func start(every interval: TimeInterval, tick: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
