import SwiftUI

/// How loudly to warn about the build's remaining life (spec decision 20).
enum ExpiryWarning: Equatable {
    /// More than 2 days left.
    case normal(days: Int)
    /// 1 or 2 days left: shown in red.
    case urgent(days: Int)
    /// The expiry day itself or later: the build may not launch again.
    case expired

    static func level(daysRemaining days: Int) -> ExpiryWarning {
        if days <= 0 { return .expired }
        return days <= 2 ? .urgent(days: days) : .normal(days: days)
    }

    var isRed: Bool {
        if case .normal = self { return false }
        return true
    }

    var message: String {
        switch self {
        case .normal(let days):
            "Build expires in \(Self.dayCount(days))"
        case .urgent(let days):
            "Build expires in \(Self.dayCount(days)) — reinstall from Xcode"
        case .expired:
            "Build expired — reinstall from Xcode"
        }
    }

    private static func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }
}

/// The days left on the installed build, as the first section of the Alarms list. Renders nothing when `expiry`
/// is nil (the simulator and any build without an embedded provisioning profile).
struct ExpiryBanner: View {
    let expiry: Date?
    var now: Date = .now

    var body: some View {
        if let expiry {
            let warning = ExpiryWarning.level(
                daysRemaining: ProvisioningProfile.daysRemaining(until: expiry, now: now))
            Section {
                Text(warning.message)
                    .font(.subheadline.weight(warning.isRed ? .semibold : .regular))
                    .foregroundStyle(warning.isRed ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .listRowBackground(warning.isRed ? Color.red : nil)
            }
        }
    }
}
