import Foundation
import Testing

@testable import WakeUpHuman

struct NoticeFormattingTests {
    @Test func aSingleMissedTimeReadsInTheSingular() {
        #expect(NoticeFormatting.missedTitle(times: ["06:15"]) == "No sonó la alarma de las 06:15")
    }

    @Test func twoMissedTimesReadInThePlural() {
        #expect(
            NoticeFormatting.missedTitle(times: ["06:15", "07:00"]) == "No sonaron las alarmas de las 06:15 y 07:00")
    }

    @Test func threeMissedTimesAreSeparatedByCommas() {
        #expect(
            NoticeFormatting.missedTitle(times: ["06:15", "07:00", "07:30"])
                == "No sonaron las alarmas de las 06:15, 07:00 y 07:30")
    }

    @Test func eachMissedCauseNamesItselfAndSaysTheAlarmNeverRingsLate() {
        #expect(
            NoticeFormatting.missedBody(cause: .systemSleep)
                == "A esa hora la Mac estaba dormida. Una alarma perdida no suena tarde.")
        #expect(
            NoticeFormatting.missedBody(cause: .appNotRunning)
                == "A esa hora la app no estaba abierta. Una alarma perdida no suena tarde.")
        #expect(
            NoticeFormatting.missedBody(cause: .checkRanLate)
                == "A esa hora la app no respondió. Una alarma perdida no suena tarde.")
    }

    @Test func aSingleUnattendedTimeReadsInTheSingular() {
        #expect(NoticeFormatting.unattendedTitle(times: ["08:30"]) == "La alarma de las 08:30 sonó sin respuesta")
    }

    @Test func severalUnattendedTimesReadInThePlural() {
        #expect(
            NoticeFormatting.unattendedTitle(times: ["08:30", "08:35"])
                == "Las alarmas de las 08:30 y 08:35 sonaron sin respuesta")
        #expect(
            NoticeFormatting.unattendedTitle(times: ["08:30", "08:35", "08:40"])
                == "Las alarmas de las 08:30, 08:35 y 08:40 sonaron sin respuesta")
    }

    @Test func theUnattendedBodyNamesWhenTheRingStopped() {
        let endedAt = TestCalendar.date(2026, 11, 2, 9, 30)

        #expect(
            NoticeFormatting.unattendedBody(endedAt: endedAt, calendar: TestCalendar.utc)
                == "Sonó los 60 minutos, hasta las 09:30, y se calló sola.")
    }

    @Test func theUnattendedEndTimeFollowsTheCalendarsTimeZone() {
        let endedAt = TestCalendar.date(2026, 11, 2, 9, 30)

        // Madrid is UTC+1 in November.
        #expect(
            NoticeFormatting.unattendedBody(endedAt: endedAt, calendar: TestCalendar.madrid)
                == "Sonó los 60 minutos, hasta las 10:30, y se calló sola.")
    }

    // 2026-11-01 is a Sunday.
    private let sundayNight = TestCalendar.date(2026, 11, 1, 22, 46)

    @Test func theBedtimeOffBodyNamesTomorrowsAlarm() {
        let upcoming = UpcomingOccurrence(alarm: TestCalendar.alarm(7, 0), date: TestCalendar.date(2026, 11, 2, 7))

        #expect(
            NoticeFormatting.bedtimeOffBody(upcoming: upcoming, now: sundayNight, calendar: TestCalendar.utc)
                == "Hay una alarma mañana 07:00. Sin el modo dormir la Mac puede dormirse y la alarma no sonar.")
    }

    @Test func theBedtimeOffBodyNamesTodaysAlarm() {
        let upcoming = UpcomingOccurrence(
            alarm: TestCalendar.alarm(23, 30), date: TestCalendar.date(2026, 11, 1, 23, 30))

        #expect(
            NoticeFormatting.bedtimeOffBody(upcoming: upcoming, now: sundayNight, calendar: TestCalendar.utc)
                == "Hay una alarma hoy 23:30. Sin el modo dormir la Mac puede dormirse y la alarma no sonar.")
    }

    @Test func theBedtimeOffAndBatteryNoticesHaveTheirFixedCopy() {
        #expect(NoticeFormatting.bedtimeOffTitle == "Modo dormir apagado")
        #expect(NoticeFormatting.batteryTitle == "Modo dormir a batería")
        #expect(
            NoticeFormatting.batteryBody == "Enchufá la Mac. Sin corriente puede dormirse igual y la alarma no sonar.")
    }

    @Test func theButtonsAreLabelledInSpanish() {
        #expect(NoticeFormatting.acknowledgeLabel == "Entendido")
        #expect(NoticeFormatting.activateBedtimeLabel == "Activar modo dormir")
    }
}
