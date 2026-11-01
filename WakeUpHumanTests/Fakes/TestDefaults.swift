import Foundation

/// A throwaway `UserDefaults` suite, removed when the test that owns it ends.
final class TestDefaults {
    let defaults: UserDefaults
    private let suiteName = "test-\(UUID().uuidString)"

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
