import Foundation
import Testing

@testable import WakeUpHuman

struct RingFormattingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: hour, minute: minute))!
    }

    @Test func statusNamesASingleAlarm() {
        #expect(RingFormatting.status(alarmTimes: ["07:00"]) == "Sonando · alarma de las 07:00")
    }

    @Test func statusJoinsTwoTimesWithY() {
        #expect(RingFormatting.status(alarmTimes: ["07:00", "07:05"]) == "Sonando · 07:00 y 07:05")
    }

    @Test func statusSeparatesMoreTimesWithCommas() {
        #expect(
            RingFormatting.status(alarmTimes: ["07:00", "07:05", "07:10"])
                == "Sonando · 07:00, 07:05 y 07:10")
    }

    @Test func joinedIsAbsentForASingleTime() {
        #expect(RingFormatting.joined(alarmTimes: ["07:00"]) == nil)
        #expect(RingFormatting.joined(alarmTimes: []) == nil)
    }

    @Test func joinedNamesTheLatestTime() {
        #expect(
            RingFormatting.joined(alarmTimes: ["07:00", "07:05"]) == "Se sumó la alarma de las 07:05")
        #expect(
            RingFormatting.joined(alarmTimes: ["07:00", "07:05", "07:10"])
                == "Se sumó la alarma de las 07:10")
    }

    @Test func elapsedLeavesMinutesUnpaddedAndPadsSeconds() {
        #expect(RingFormatting.elapsed(352) == "Sonando hace 5:52")
        #expect(RingFormatting.elapsed(14) == "Sonando hace 0:14")
        #expect(RingFormatting.elapsed(3_600) == "Sonando hace 60:00")
    }

    @Test func clockPadsHourAndMinute() {
        #expect(RingFormatting.clock(date(hour: 7, minute: 0), calendar: calendar) == "07:00")
        #expect(RingFormatting.clock(date(hour: 18, minute: 5), calendar: calendar) == "18:05")
    }

    @Test func progressCountsCompletedWordsOfSix() {
        #expect(RingFormatting.progress(completed: 0) == "0 de 6 palabras")
        #expect(RingFormatting.progress(completed: 3) == "3 de 6 palabras")
    }

    @Test func volumeLabelsEachStatus() {
        #expect(
            RingFormatting.volume(.ramping(percent: 35, secondsToMax: 16))
                == "Volumen del sistema 35 % · al máximo en 16 s")
        #expect(RingFormatting.volume(.atMaximum) == "Volumen del sistema al máximo")
        #expect(
            RingFormatting.volume(.unavailable)
                == "No se puede controlar el volumen de esta salida")
    }

    @Test func volumeIsHiddenWhenUnknown() {
        #expect(RingFormatting.volume(.unknown) == nil)
    }

    @Test func capNamesTheEndTimeAndTheSixtyMinuteLimit() {
        #expect(
            RingFormatting.cap(endsAt: date(hour: 8, minute: 0), calendar: calendar)
                == "Se calla sola a las 08:00 · tope de 60 min")
    }

    @Test func capTakesTheLimitFromTheCaller() {
        #expect(
            RingFormatting.cap(endsAt: date(hour: 8, minute: 30), calendar: calendar, minutes: 30)
                == "Se calla sola a las 08:30 · tope de 30 min")
    }

    @Test func pasteHintChangesWhenAPasteWasRejected() {
        #expect(RingFormatting.pasteHint(rejected: false) == "Pegar está bloqueado")
        #expect(RingFormatting.pasteHint(rejected: true) == "No se puede pegar: tipealo")
    }

    @Test func rangForSplitsMinutesAndSeconds() {
        #expect(RingFormatting.rangFor(352) == "Sonó 5 min 52 s")
        #expect(RingFormatting.rangFor(9) == "Sonó 0 min 9 s")
    }
}
