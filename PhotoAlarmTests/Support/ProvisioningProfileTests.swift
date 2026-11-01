import Foundation
import Testing

@testable import PhotoAlarm

struct ProvisioningProfileTests {
    private static let expiry = Date(timeIntervalSince1970: 1_800_000_000)

    /// A stand-in for a real profile: a plist wrapped in junk, as the CMS envelope wraps it.
    private static func profileData(_ plist: [String: Any]) throws -> Data {
        let xml = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        return Data("junk-prefix".utf8) + xml + Data("junk-suffix".utf8)
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static func date(day: Int, hour: Int, calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)))
    }

    // MARK: Reading the expiry

    @Test func theExpirationDateIsReadFromThePlistInsideTheProfile() throws {
        let data = try Self.profileData(["ExpirationDate": Self.expiry, "Name": "x"])

        let read = try #require(ProvisioningProfile.expirationDate(fromProfileData: data))

        #expect(abs(read.timeIntervalSince(Self.expiry)) < 1)
    }

    @Test func dataWithoutAPlistHasNoExpirationDate() {
        #expect(ProvisioningProfile.expirationDate(fromProfileData: Data("not a profile".utf8)) == nil)
        #expect(ProvisioningProfile.expirationDate(fromProfileData: Data()) == nil)
    }

    @Test func aPlistWithoutAnExpirationDateHasNone() throws {
        let data = try Self.profileData(["Name": "x"])

        #expect(ProvisioningProfile.expirationDate(fromProfileData: data) == nil)
    }

    @Test func anExpirationDateThatIsNotADateIsIgnored() throws {
        let data = try Self.profileData(["ExpirationDate": "tomorrow"])

        #expect(ProvisioningProfile.expirationDate(fromProfileData: data) == nil)
    }

    // MARK: The embedded profile

    @Test func aBundleWithoutAnEmbeddedProfileHasNoExpiry() throws {
        let directory = try Self.makeTemporaryBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bundle = try #require(Bundle(url: directory))

        #expect(ProvisioningProfile.embeddedExpirationDate(in: bundle) == nil)
    }

    @Test func theEmbeddedProfileOfABundleIsRead() throws {
        let directory = try Self.makeTemporaryBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Self.profileData(["ExpirationDate": Self.expiry])
            .write(to: directory.appending(path: "embedded.mobileprovision"))

        let bundle = try #require(Bundle(url: directory))

        let read = try #require(ProvisioningProfile.embeddedExpirationDate(in: bundle))

        #expect(abs(read.timeIntervalSince(Self.expiry)) < 1)
    }

    private static func makeTemporaryBundleDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ProvisioningProfileTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: Day arithmetic

    @Test func threeDaysAheadIsThreeDaysRemaining() throws {
        let calendar = Self.utcCalendar()
        let now = try Self.date(day: 1, hour: 8, calendar: calendar)
        let expiry = try Self.date(day: 4, hour: 20, calendar: calendar)

        #expect(ProvisioningProfile.daysRemaining(until: expiry, now: now, calendar: calendar) == 3)
    }

    @Test func laterTheSameDayIsZeroDaysRemaining() throws {
        let calendar = Self.utcCalendar()
        let now = try Self.date(day: 1, hour: 8, calendar: calendar)
        let expiry = try Self.date(day: 1, hour: 23, calendar: calendar)

        #expect(ProvisioningProfile.daysRemaining(until: expiry, now: now, calendar: calendar) == 0)
    }

    @Test func yesterdayIsMinusOneDaysRemaining() throws {
        let calendar = Self.utcCalendar()
        let now = try Self.date(day: 2, hour: 8, calendar: calendar)
        let expiry = try Self.date(day: 1, hour: 23, calendar: calendar)

        #expect(ProvisioningProfile.daysRemaining(until: expiry, now: now, calendar: calendar) == -1)
    }

    @Test func daysAreCalendarDaysNotTwentyFourHourBlocks() throws {
        let calendar = Self.utcCalendar()
        let now = try Self.date(day: 1, hour: 23, calendar: calendar)
        let expiry = try Self.date(day: 2, hour: 1, calendar: calendar)

        #expect(ProvisioningProfile.daysRemaining(until: expiry, now: now, calendar: calendar) == 1)
    }
}
