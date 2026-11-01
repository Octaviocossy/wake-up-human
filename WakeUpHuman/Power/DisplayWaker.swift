import Foundation
import IOKit.pwr_mgt

/// Turns a dark display on for a Ring (spec decision 3). A display assertion only keeps a lit
/// display on; declaring user activity is what lights a dark one.
@MainActor
protocol DisplayWaking: AnyObject {
    /// Declares local user activity, which turns the display on. Declaring again renews it.
    func wake()
    /// Releases the declaration. A no-op when none is held.
    func release()
}

/// The IOKit implementation. Boundary code: verified by hand on the Mac with the display asleep, not
/// by unit tests.
@MainActor
final class IOKitDisplayWaker: DisplayWaking {
    /// What `pmset -g assertions` prints while the declaration is held.
    private let name: String
    private var assertionID: IOPMAssertionID?

    init(name: String = "Wake Up Human — Ring") {
        self.name = name
    }

    func wake() {
        // Passing the ID already held renews that declaration instead of registering a second one.
        var id = assertionID ?? IOPMAssertionID(0)
        let result = IOPMAssertionDeclareUserActivity(name as CFString, kIOPMUserActiveLocal, &id)
        guard result == kIOReturnSuccess else {
            Log.power.error("Could not declare user activity to wake the display: \(result)")
            return
        }
        assertionID = id
        Log.power.info("Declared user activity to wake the display")
    }

    func release() {
        guard let assertionID else { return }
        self.assertionID = nil
        let result = IOPMAssertionRelease(assertionID)
        if result != kIOReturnSuccess {
            Log.power.error("Could not release the user-activity declaration: \(result)")
        }
    }
}
