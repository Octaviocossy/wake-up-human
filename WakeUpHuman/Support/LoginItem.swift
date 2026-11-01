import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case disabled
    /// Registered, but the user has not approved it in System Settings yet.
    case requiresApproval
    /// The system cannot find the app to register — typically it does not run from `/Applications`.
    case unavailable
}

/// Whether macOS starts the app at login — read live from `SMAppService.mainApp.status`, never
/// mirrored: the user can change it in System Settings without the app being told (Caffeinassy).
@MainActor
protocol LoginItemControlling: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    /// Opens System Settings > Login Items, where the user approves or removes the item.
    func openSystemSettings()
}

/// The `SMAppService` implementation. Boundary code: verified by hand from `/Applications`, not by
/// unit tests; a test run never builds one (`AppDelegate` builds nothing under `AppEnvironment.isRunningTests`).
@MainActor
final class SMAppServiceLoginItem: LoginItemControlling {
    private let service = SMAppService.mainApp

    var status: LoginItemStatus {
        switch service.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func register() throws { try service.register() }

    func unregister() throws { try service.unregister() }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// Launch at login is on by default (spec decision 18), applied exactly once, so a user who
/// switches it off is never switched back on at the next launch.
enum LaunchAtLoginDefault {
    static let appliedKey = "launchAtLoginDefaultApplied"

    /// The first time it runs: registers the login item if it is off, then remembers it has run. A
    /// failed registration is logged and never retried — registering works reliably only from
    /// `/Applications`, and the panel's footer shows the truth either way.
    @MainActor
    static func applyIfNeeded(loginItem: LoginItemControlling, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: appliedKey) else { return }
        if loginItem.status == .disabled {
            do {
                try loginItem.register()
                Log.app.info("Launch at login switched on by default")
            } catch {
                Log.app.error("Could not switch launch at login on: \(error.localizedDescription)")
            }
        }
        defaults.set(true, forKey: appliedKey)
    }
}
