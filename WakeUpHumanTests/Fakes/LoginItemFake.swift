@testable import WakeUpHuman

/// Stands in for `SMAppService.mainApp`: its `status` is settable, and a successful `register` or
/// `unregister` moves it the way the system would.
@MainActor
final class LoginItemFake: LoginItemControlling {
    struct RegisterFailure: Error {}

    var status: LoginItemStatus
    /// When `true`, `register()` throws and leaves `status` alone.
    var registerThrows = false
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openSettingsCount = 0

    init(status: LoginItemStatus = .disabled) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if registerThrows { throw RegisterFailure() }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        status = .disabled
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }
}
