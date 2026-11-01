import Testing

@testable import PhotoAlarm

struct PhotoCheckTests {
    @Test func distanceBelowThresholdIsMatch() {
        #expect(PhotoCheck.evaluate(distance: 0.3, threshold: 0.6) == .match)
    }

    @Test func distanceEqualToThresholdIsNoMatch() {
        #expect(PhotoCheck.evaluate(distance: 0.6, threshold: 0.6) == .noMatch)
    }

    @Test func distanceAboveThresholdIsNoMatch() {
        #expect(PhotoCheck.evaluate(distance: 0.9, threshold: 0.6) == .noMatch)
    }

    @Test func defaultThresholdIsTheCalibratedConstant() {
        #expect(PhotoCheck.evaluate(distance: MatchThreshold.value - 0.01) == .match)
        #expect(PhotoCheck.evaluate(distance: MatchThreshold.value) == .noMatch)
    }
}
