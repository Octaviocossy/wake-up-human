import Testing

@testable import WakeUpHuman

struct AppEnvironmentTests {
    @Test func reportsTheHostedTestRun() {
        #expect(AppEnvironment.isRunningTests)
    }
}
