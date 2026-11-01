import Foundation
import Observation

/// Bedtime (glossary › Bedtime): rain plus the only assertion that keeps the Mac awake while it
/// waits for an Alarm (invariant 6, ADR-0027). The assertion is held exactly while `isOn`.
///
/// Bedtime runs until it is switched off or a Ring replaces it (spec decision 9). It is allowed with
/// no upcoming Alarm (spec decision 26) and is never persisted as on (see `BedtimeSettings`).
@MainActor
@Observable
final class BedtimeController {
    private(set) var isOn = false

    /// The rain's own volume, 0...1, independent of the system volume (spec decision 20). Persisted,
    /// and applied to the rain whether or not Bedtime is on.
    var rainVolume: Float {
        didSet {
            let clamped = BedtimeSettings.clamped(rainVolume)
            if clamped != rainVolume { rainVolume = clamped }
            settings.rainVolume = clamped
            rain.volume = clamped
        }
    }

    @ObservationIgnored private let rain: RainPlaying
    @ObservationIgnored private let assertion: PowerAssertionControlling
    @ObservationIgnored private let settings: BedtimeSettings

    init(rain: RainPlaying, assertion: PowerAssertionControlling, settings: BedtimeSettings = BedtimeSettings()) {
        self.rain = rain
        self.assertion = assertion
        self.settings = settings
        let volume = settings.rainVolume
        rainVolume = volume
        rain.volume = volume
    }

    /// Takes the assertion, then starts the rain. If the system refuses the assertion, Bedtime stays
    /// off and logs, so the switch never claims the Mac will stay awake when it will not. Does nothing
    /// when Bedtime is already on.
    func turnOn() {
        guard !isOn else { return }
        guard assertion.acquire() else {
            Log.bedtime.error("The system refused the keep-awake assertion; Bedtime stays off")
            return
        }
        isOn = true
        do {
            try rain.start()
        } catch {
            // The assertion matters more than the sound: an Alarm still rings with the Mac awake.
            Log.bedtime.fault("The rain failed to start: \(String(describing: error), privacy: .public)")
        }
        Log.bedtime.info("Bedtime on")
    }

    /// Stops the rain and releases the assertion. Idempotent.
    func turnOff() {
        guard isOn else { return }
        end()
        Log.bedtime.info("Bedtime off")
    }

    /// A Ring replaces Bedtime (spec decision 9): same as `turnOff`, logged as such. Bedtime stays
    /// off after the Ring is Dismissed.
    func endForRing() {
        guard isOn else { return }
        end()
        Log.bedtime.info("Bedtime off: a Ring replaced it")
    }

    private func end() {
        isOn = false
        rain.stop()
        assertion.release()
    }
}
