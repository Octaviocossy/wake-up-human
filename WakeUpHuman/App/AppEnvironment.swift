import Foundation

/// Facts about the process the app is running in.
enum AppEnvironment {
    /// `true` when the process is the host of a unit-test run. The test bundle is hosted in the app,
    /// so `applicationDidFinishLaunching` runs during `xcodebuild test`. Under a test run the app
    /// must never schedule a real Alarm, play a sound, change the system volume, take a power
    /// assertion or register a login item.
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}
