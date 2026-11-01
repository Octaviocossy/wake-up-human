import Testing

@testable import PhotoAlarm

struct ExpiryBannerTests {
    // MARK: Levels

    @Test func moreThanTwoDaysLeftIsNormal() {
        #expect(ExpiryWarning.level(daysRemaining: 3) == .normal(days: 3))
        #expect(ExpiryWarning.level(daysRemaining: 7) == .normal(days: 7))
    }

    @Test func twoDaysAndOneDayLeftAreUrgent() {
        #expect(ExpiryWarning.level(daysRemaining: 2) == .urgent(days: 2))
        #expect(ExpiryWarning.level(daysRemaining: 1) == .urgent(days: 1))
    }

    @Test func theExpiryDayAndAfterAreExpired() {
        #expect(ExpiryWarning.level(daysRemaining: 0) == .expired)
        #expect(ExpiryWarning.level(daysRemaining: -1) == .expired)
    }

    @Test func onlyTheNormalLevelIsNotRed() {
        #expect(!ExpiryWarning.normal(days: 3).isRed)
        #expect(ExpiryWarning.urgent(days: 2).isRed)
        #expect(ExpiryWarning.expired.isRed)
    }

    // MARK: Messages

    @Test func theNormalMessageCountsTheDays() {
        #expect(ExpiryWarning.normal(days: 5).message == "Build expires in 5 days")
    }

    @Test func theUrgentMessageSaysToReinstallAndAgreesInNumber() {
        #expect(ExpiryWarning.urgent(days: 2).message == "Build expires in 2 days — reinstall from Xcode")
        #expect(ExpiryWarning.urgent(days: 1).message == "Build expires in 1 day — reinstall from Xcode")
    }

    @Test func theExpiredMessageSaysToReinstall() {
        #expect(ExpiryWarning.expired.message == "Build expired — reinstall from Xcode")
    }
}
