import Foundation
import Testing

@testable import WakeUpHuman

struct AlarmFormattingTests {
    @Test func timeIsZeroPadded() {
        #expect(AlarmFormatting.time(TimeOfDay(hour: 7, minute: 0)) == "07:00")
        #expect(AlarmFormatting.time(TimeOfDay(hour: 22, minute: 46)) == "22:46")
    }

    @Test func noWeekdayReadsOnce() {
        #expect(AlarmFormatting.days([]) == "Una vez")
    }

    @Test func allSevenWeekdaysReadEveryDay() {
        #expect(AlarmFormatting.days(Set(Weekday.allCases)) == "Todos los días")
    }

    @Test func mondayToFridayReadsAsARange() {
        #expect(AlarmFormatting.days([.monday, .tuesday, .wednesday, .thursday, .friday]) == "Lun a vie")
    }

    @Test func theWeekendReadsAsSaturdayAndSunday() {
        #expect(AlarmFormatting.days([.saturday, .sunday]) == "Sáb y dom")
    }

    @Test func otherSetsListMondayFirstAbbreviationsWithACapitalFirstLetter() {
        #expect(AlarmFormatting.days([.friday, .wednesday, .monday]) == "Lun, mié, vie")
        #expect(AlarmFormatting.days([.sunday, .tuesday]) == "Mar, dom")
        #expect(AlarmFormatting.days([.thursday]) == "Jue")
    }

    @Test func theHintForRepeatingDaysRepeatsTheLowercasedLabel() {
        #expect(AlarmFormatting.repeatHint([.monday, .wednesday, .friday]) == "Se repite: lun, mié, vie.")
        #expect(AlarmFormatting.repeatHint(Set(Weekday.allCases)) == "Se repite: todos los días.")
    }

    @Test func theHintForNoDaysSaysItRingsOnce() {
        #expect(AlarmFormatting.repeatHint([]) == "Sin días: suena una vez y se desarma sola.")
    }

    // 2026-11-01 is a Sunday.
    private let sundayNight = TestCalendar.date(2026, 11, 1, 22, 46)

    @Test func whenLabelSaysTodayForTheSameDay() {
        let laterToday = TestCalendar.date(2026, 11, 1, 23, 30)

        #expect(AlarmFormatting.whenLabel(of: laterToday, now: sundayNight, calendar: TestCalendar.utc) == "hoy")
    }

    @Test func whenLabelSaysTomorrowForTheNextDay() {
        let mondayMorning = TestCalendar.date(2026, 11, 2, 7)

        #expect(AlarmFormatting.whenLabel(of: mondayMorning, now: sundayNight, calendar: TestCalendar.utc) == "mañana")
    }

    @Test func whenLabelGivesTheWeekdayAbbreviationFurtherAhead() {
        let tuesday = TestCalendar.date(2026, 11, 3, 7)
        let nextSunday = TestCalendar.date(2026, 11, 8, 7)

        #expect(AlarmFormatting.whenLabel(of: tuesday, now: sundayNight, calendar: TestCalendar.utc) == "mar")
        #expect(AlarmFormatting.whenLabel(of: nextSunday, now: sundayNight, calendar: TestCalendar.utc) == "dom")
    }

    @Test func tomorrowCrossesAMonthBoundary() {
        let now = TestCalendar.date(2026, 10, 31, 22)

        #expect(
            AlarmFormatting.whenLabel(of: TestCalendar.date(2026, 11, 1, 6), now: now, calendar: TestCalendar.utc)
                == "mañana")
    }

    @Test func countdownRoundsUpToWholeMinutes() {
        let now = TestCalendar.date(2026, 11, 1, 22, 46)

        let eightHours = now.addingTimeInterval(8 * 3600 + 13 * 60 + 30)
        #expect(AlarmFormatting.countdown(from: now, to: eightHours) == "en 8 h 14 min")
        #expect(AlarmFormatting.countdown(from: now, to: now.addingTimeInterval(14 * 60)) == "en 14 min")
        #expect(AlarmFormatting.countdown(from: now, to: now.addingTimeInterval(14 * 60 + 1)) == "en 15 min")
    }

    @Test func countdownKeepsTheZeroMinutesOfAWholeHour() {
        let now = TestCalendar.date(2026, 11, 1, 22, 46)

        #expect(AlarmFormatting.countdown(from: now, to: now.addingTimeInterval(2 * 3600)) == "en 2 h 0 min")
    }

    @Test func weekdayLabelsGiveTheChipLetterTheFullNameAndTheAbbreviation() {
        #expect(Weekday.allCases.map { AlarmFormatting.labels(of: $0).letter } == ["L", "M", "X", "J", "V", "S", "D"])
        #expect(
            AlarmFormatting.labels(of: .wednesday)
                == AlarmFormatting.WeekdayLabels(letter: "X", name: "Miércoles", abbreviation: "mié"))
    }
}
