import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct LaunchAtLoginDefaultTests {
    private let suite = TestDefaults()

    @Test func theFirstRunRegistersADisabledLoginItemOnceAndSetsTheFlag() {
        let loginItem = LoginItemFake(status: .disabled)

        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem, defaults: suite.defaults)

        #expect(loginItem.registerCount == 1)
        #expect(loginItem.status == .enabled)
        #expect(suite.defaults.bool(forKey: LaunchAtLoginDefault.appliedKey))
    }

    @Test func aUserWhoSwitchedItOffIsNotSwitchedBackOnAtTheNextLaunch() {
        let loginItem = LoginItemFake(status: .disabled)
        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem, defaults: suite.defaults)
        loginItem.status = .disabled  // the user switches it off

        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem, defaults: suite.defaults)

        #expect(loginItem.registerCount == 1)
        #expect(loginItem.status == .disabled)
    }

    @Test(arguments: [LoginItemStatus.enabled, .requiresApproval, .unavailable])
    func aLoginItemThatIsNotDisabledSetsTheFlagWithoutRegistering(status: LoginItemStatus) {
        let loginItem = LoginItemFake(status: status)

        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem, defaults: suite.defaults)

        #expect(loginItem.registerCount == 0)
        #expect(suite.defaults.bool(forKey: LaunchAtLoginDefault.appliedKey))
    }

    @Test func aRegistrationThatThrowsStillSetsTheFlagAndIsNotRetried() {
        let loginItem = LoginItemFake(status: .disabled)
        loginItem.registerThrows = true

        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem, defaults: suite.defaults)
        LaunchAtLoginDefault.applyIfNeeded(loginItem: loginItem, defaults: suite.defaults)

        #expect(loginItem.registerCount == 1)
        #expect(suite.defaults.bool(forKey: LaunchAtLoginDefault.appliedKey))
    }
}
