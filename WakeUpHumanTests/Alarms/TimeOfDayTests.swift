import Foundation
import Testing

@testable import WakeUpHuman

struct TimeOfDayTests {
    @Test func ordersByTheMinuteOfTheDay() {
        #expect(TimeOfDay(hour: 6, minute: 59) < TimeOfDay(hour: 7, minute: 0))
        #expect(TimeOfDay(hour: 23, minute: 59).minuteOfDay == 1439)
    }

    @Test func roundTripsThroughJSON() throws {
        let time = TimeOfDay(hour: 7, minute: 30)

        let decoded = try JSONDecoder().decode(TimeOfDay.self, from: JSONEncoder().encode(time))

        #expect(decoded == time)
    }

    @Test func anOutOfRangeTimeFailsToDecode() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeOfDay.self, from: Data(#"{"hour":24,"minute":0}"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeOfDay.self, from: Data(#"{"hour":7,"minute":60}"#.utf8))
        }
    }
}
