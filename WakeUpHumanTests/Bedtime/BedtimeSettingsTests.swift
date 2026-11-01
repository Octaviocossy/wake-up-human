import Foundation
import Testing

@testable import WakeUpHuman

struct BedtimeSettingsTests {
    private let suite = TestDefaults()

    @Test func theRainVolumeDefaultsToSixtyPercent() {
        #expect(BedtimeSettings(defaults: suite.defaults).rainVolume == 0.6)
    }

    @Test(arguments: [(-0.5, 0.0), (0.0, 0.0), (0.25, 0.25), (1.0, 1.0), (7.0, 1.0)] as [(Float, Float)])
    func writingClampsTheRainVolumeToZeroToOne(written: Float, expected: Float) {
        let settings = BedtimeSettings(defaults: suite.defaults)

        settings.rainVolume = written

        #expect(settings.rainVolume == expected)
    }

    @Test func aStoredOutOfRangeValueIsClampedOnRead() {
        suite.defaults.set(Float(3), forKey: BedtimeSettings.rainVolumeKey)

        #expect(BedtimeSettings(defaults: suite.defaults).rainVolume == 1)
    }

    @Test func anUnreadableStoredValueReadsAsTheDefault() {
        suite.defaults.set("loud", forKey: BedtimeSettings.rainVolumeKey)

        #expect(BedtimeSettings(defaults: suite.defaults).rainVolume == 0.6)
    }

    @Test func theRainVolumePersistsAcrossInstancesOnTheSameSuite() {
        BedtimeSettings(defaults: suite.defaults).rainVolume = 0.35

        #expect(BedtimeSettings(defaults: suite.defaults).rainVolume == 0.35)
    }
}
