import Foundation
import IOKit.pwr_mgt

/// Registers and releases one IOKit power assertion. Invariant 6: only a Ring (display sleep, while
/// it sounds) and Bedtime (#16, system sleep) ever hold one.
@MainActor
protocol PowerAssertionControlling: AnyObject {
    var isHeld: Bool { get }
    /// Registers the assertion, or does nothing if it is already held. `false` if the system refused it.
    @discardableResult func acquire() -> Bool
    /// Releases it. A no-op when none is held.
    func release()
}

/// The IOKit implementation. Boundary code: verified with `pmset -g assertions | grep "Wake Up Human"`,
/// not by unit tests.
@MainActor
final class IOKitPowerAssertion: PowerAssertionControlling {
    /// IOKit declares the assertion types as `CFSTR` macros, which do not import into Swift, so they
    /// are spelled out.
    enum Kind: String {
        /// A Ring: the display (and so the system) stays on while it sounds.
        case preventDisplaySleep = "PreventUserIdleDisplaySleep"
        /// Bedtime (#16): the system stays out of idle System sleep.
        case preventSystemSleep = "PreventUserIdleSystemSleep"
    }

    private let kind: Kind
    /// What `pmset -g assertions` prints.
    private let name: String
    private var assertionID: IOPMAssertionID?

    init(kind: Kind, name: String) {
        self.kind = kind
        self.name = name
    }

    var isHeld: Bool { assertionID != nil }

    @discardableResult
    func acquire() -> Bool {
        guard assertionID == nil else { return true }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kind.rawValue as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), name as CFString, &id)
        guard result == kIOReturnSuccess else {
            Log.power.error("The system refused the \(self.kind.rawValue, privacy: .public) assertion: \(result)")
            return false
        }
        assertionID = id
        Log.power.info("Holding the \(self.kind.rawValue, privacy: .public) assertion")
        return true
    }

    func release() {
        guard let assertionID else { return }
        self.assertionID = nil
        let result = IOPMAssertionRelease(assertionID)
        guard result == kIOReturnSuccess else {
            Log.power.error("Could not release the \(self.kind.rawValue, privacy: .public) assertion: \(result)")
            return
        }
        Log.power.info("Released the \(self.kind.rawValue, privacy: .public) assertion")
    }
}
