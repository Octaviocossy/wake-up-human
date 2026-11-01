import AppKit

/// Relays System sleep, the wake from it, and changes to the system clock or time zone to closures
/// on the main actor, until `stop()`.
@MainActor
final class SystemEventObserver {
    private var observations: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    init(
        willSleep: @escaping @MainActor @Sendable () -> Void,
        didWake: @escaping @MainActor @Sendable () -> Void,
        clockDidChange: @escaping @MainActor @Sendable () -> Void
    ) {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(NSWorkspace.willSleepNotification, on: workspace, willSleep)
        observe(NSWorkspace.didWakeNotification, on: workspace, didWake)
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            observe(name, on: .default, clockDidChange)
        }
    }

    func stop() {
        for observation in observations {
            observation.center.removeObserver(observation.token)
        }
        observations.removeAll()
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observations.append((center, token))
    }
}
