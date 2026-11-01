import Testing

@testable import WakeUpHuman

struct StatusIconTests {
    private func appearance(
        ringing: Bool = false, bedtime: Bool = false, armed: Bool = false, notice: Bool = false
    ) -> StatusIconAppearance {
        StatusIcon.appearance(
            for: StatusIconInput(
                isRinging: ringing, bedtimeOn: bedtime, anyAlarmArmed: armed, hasPendingNotice: notice))
    }

    @Test func nothingArmedIsADimmedAlarmClock() {
        #expect(
            appearance()
                == StatusIconAppearance(
                    symbolName: "alarm", isDimmed: true, isRingingTint: false, showsDot: false,
                    accessibilityDescription: "Wake Up Human — sin alarmas armadas"))
    }

    @Test func anArmedAlarmIsAFullAlarmClock() {
        #expect(
            appearance(armed: true)
                == StatusIconAppearance(
                    symbolName: "alarm", isDimmed: false, isRingingTint: false, showsDot: false,
                    accessibilityDescription: "Wake Up Human — alarma armada"))
    }

    @Test func bedtimeOnIsAMoon() {
        #expect(
            appearance(bedtime: true)
                == StatusIconAppearance(
                    symbolName: "moon.fill", isDimmed: false, isRingingTint: false, showsDot: false,
                    accessibilityDescription: "Wake Up Human — modo dormir activo"))
    }

    @Test func aRingIsAFilledAlarmClockWithTheOrangeTint() {
        #expect(
            appearance(ringing: true)
                == StatusIconAppearance(
                    symbolName: "alarm.fill", isDimmed: false, isRingingTint: true, showsDot: false,
                    accessibilityDescription: "Wake Up Human — sonando"))
    }

    @Test func aRingBeatsBedtimeAndAnArmedAlarm() {
        let ringing = appearance(ringing: true, bedtime: true, armed: true)

        #expect(ringing.symbolName == "alarm.fill")
        #expect(ringing.isRingingTint)
    }

    @Test func bedtimeBeatsAnArmedAlarm() {
        let bedtime = appearance(bedtime: true, armed: true)

        #expect(bedtime.symbolName == "moon.fill")
        #expect(!bedtime.isRingingTint)
    }

    @Test func aPendingNoticeAddsTheDotToEveryStateButARing() {
        #expect(appearance(notice: true).showsDot)
        #expect(appearance(armed: true, notice: true).showsDot)
        #expect(appearance(bedtime: true, notice: true).showsDot)
        #expect(!appearance(ringing: true, notice: true).showsDot)
    }

    @Test func noNoticeMeansNoDot() {
        #expect(!appearance().showsDot)
        #expect(!appearance(armed: true).showsDot)
        #expect(!appearance(bedtime: true).showsDot)
    }

    @Test func aDimmedIconNeedsNothingArmedBedtimeOffAndNoRing() {
        #expect(appearance().isDimmed)
        #expect(!appearance(armed: true).isDimmed)
        #expect(!appearance(bedtime: true).isDimmed)
        #expect(!appearance(ringing: true).isDimmed)
    }

    @Test func aPendingNoticeIsAnnouncedInTheAccessibilityDescription() {
        #expect(
            appearance(armed: true, notice: true).accessibilityDescription
                == "Wake Up Human — alarma armada · aviso pendiente")
        #expect(
            appearance(bedtime: true, notice: true).accessibilityDescription
                == "Wake Up Human — modo dormir activo · aviso pendiente")
        #expect(
            appearance(notice: true).accessibilityDescription
                == "Wake Up Human — sin alarmas armadas · aviso pendiente")
        #expect(
            appearance(ringing: true, notice: true).accessibilityDescription
                == "Wake Up Human — sonando · aviso pendiente")
    }
}
