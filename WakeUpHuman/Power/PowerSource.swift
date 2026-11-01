import Foundation
import IOKit.ps
import Observation

/// Whether the Mac runs on battery, for the "Bedtime on battery" notice (glossary › Notice). Read from
/// IOKit's power sources and kept current by their change notification. A desktop Mac, which has no
/// battery, always reads `false`.
///
/// Boundary code: verified by hand — unplug and plug in the charger with Bedtime on — not by unit tests.
/// Holds no power assertion (invariant 6); it only reads.
@MainActor
@Observable
final class IOKitPowerSourceMonitor {
    private(set) var isOnBattery: Bool

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init() {
        isOnBattery = Self.readIsOnBattery()
        start()
    }

    /// Stops listening. The notification's context is an unretained pointer to `self`, so this must
    /// run before the monitor goes away.
    func stop() {
        guard let runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        self.runLoopSource = nil
    }

    private func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            // The source is on the main run loop, so this runs on the main thread.
            MainActor.assumeIsolated {
                Unmanaged<IOKitPowerSourceMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            Log.power.error("Could not listen for power source changes; the battery notice may go stale")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
    }

    private func refresh() {
        let onBattery = Self.readIsOnBattery()
        guard onBattery != isOnBattery else { return }
        isOnBattery = onBattery
        Log.power.info("The Mac is now on \(onBattery ? "battery" : "mains", privacy: .public) power")
    }

    private static func readIsOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return false }
        return (providing as String) == kIOPMBatteryPowerKey
    }
}
