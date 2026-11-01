import Foundation

/// Bedtime's one persisted setting: the rain volume (spec decision 20).
///
/// Whether Bedtime is on is deliberately **not** stored, so the app always launches with it off: a
/// launch at login in the evening must not start rain or take a power assertion unasked.
struct BedtimeSettings {
    static let rainVolumeKey = "rainVolume"
    static let defaultRainVolume: Float = 0.6

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 0...1. Clamped on write and on read; an unset or unreadable value reads as the default.
    var rainVolume: Float {
        get {
            guard let stored = (defaults.object(forKey: Self.rainVolumeKey) as? NSNumber)?.floatValue else {
                return Self.defaultRainVolume
            }
            return Self.clamped(stored)
        }
        nonmutating set {
            defaults.set(Self.clamped(newValue), forKey: Self.rainVolumeKey)
        }
    }

    /// `value` limited to 0...1; NaN reads as the default.
    static func clamped(_ value: Float) -> Float {
        guard !value.isNaN else { return defaultRainVolume }
        return min(max(value, 0), 1)
    }
}
