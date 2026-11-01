import Foundation

/// Reads when this build's provisioning profile expires (spec decision 20). A free Personal Team build stops
/// launching after 7 days, and an app that cannot launch cannot run its Mission. The date is read from the
/// profile shipped inside the app, so nothing leaves the device (invariant 3).
enum ProvisioningProfile {
    /// Extracts `ExpirationDate` from the XML plist embedded in a provisioning profile blob. The profile is a
    /// CMS-signed envelope around a plain-text plist, so the plist is found by its markers rather than by
    /// verifying the signature.
    static func expirationDate(fromProfileData data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard
            let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }

    /// nil in the simulator and in any build without an embedded profile.
    static func embeddedExpirationDate(in bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return expirationDate(fromProfileData: data)
    }

    /// Whole calendar days from `now` to `expiry` (0 on the expiry day, negative after it).
    static func daysRemaining(until expiry: Date, now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiry))
            .day ?? 0
    }
}
