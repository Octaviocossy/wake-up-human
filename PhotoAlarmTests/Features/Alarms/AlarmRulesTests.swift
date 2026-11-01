import Testing

@testable import PhotoAlarm

struct AlarmRulesTests {
    // MARK: Saving

    @Test func anAlarmWithNoWeekdayCannotBeSaved() {
        #expect(!AlarmRules.canSave(weekdayNumbers: []))
    }

    @Test func numbersThatAreNotWeekdaysDoNotCountTowardTheMinimum() {
        #expect(!AlarmRules.canSave(weekdayNumbers: [0, 8]))
    }

    @Test func oneWeekdayIsEnoughToSave() {
        #expect(AlarmRules.canSave(weekdayNumbers: [4]))
    }

    // MARK: Enabling

    @Test func withoutATargetObjectEnablingIsBlockedWhetherOrNotAuthorized() {
        #expect(
            AlarmRules.enableBlock(isTargetRegistered: false, isAuthorized: true) == .targetObjectNotRegistered)
        #expect(
            AlarmRules.enableBlock(isTargetRegistered: false, isAuthorized: false) == .targetObjectNotRegistered)
    }

    @Test func aRegisteredTargetObjectWithoutAuthorizationBlocksEnabling() {
        #expect(AlarmRules.enableBlock(isTargetRegistered: true, isAuthorized: false) == .notAuthorized)
    }

    @Test func aRegisteredTargetObjectAndAuthorizationLeaveNothingBlocking() {
        #expect(AlarmRules.enableBlock(isTargetRegistered: true, isAuthorized: true) == nil)
    }

    // MARK: Week order

    @Test func theWeekStartsOnTheGivenWeekday() {
        #expect(AlarmRules.weekOrder(firstWeekday: 1) == [1, 2, 3, 4, 5, 6, 7])
        #expect(AlarmRules.weekOrder(firstWeekday: 2) == [2, 3, 4, 5, 6, 7, 1])
        #expect(AlarmRules.weekOrder(firstWeekday: 7) == [7, 1, 2, 3, 4, 5, 6])
    }
}
