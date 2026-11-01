import SwiftUI

/// The notice cards at the top of the panel (`docs/design/panel.html`, "With notices" and "Bedtime on
/// battery"). Order: the pending ones in the order they were recorded — missed and unattended
/// Rings — then the derived ones, Bedtime off and Bedtime on battery. Renders nothing when there are
/// none. Reads `clock.now`, so the Bedtime-off notice appears as soon as an Alarm enters the 12-hour
/// window while the panel is open.
struct NoticesSection: View {
    let clock: PanelClock
    let notices: NoticeCenter
    let alarmStore: AlarmStore
    let bedtime: BedtimeController
    let powerSource: IOKitPowerSourceMonitor

    var body: some View {
        let calendar = OccurrenceCalendar()
        let derived = NoticeCenter.derived(
            bedtimeOn: bedtime.isOn,
            upcoming: UpcomingOccurrence.next(in: alarmStore.alarms, after: clock.now, calendar: calendar),
            onBattery: powerSource.isOnBattery,
            now: clock.now
        )
        if !notices.pending.isEmpty || !derived.isEmpty {
            VStack(spacing: 8) {
                ForEach(notices.pending) { notice in
                    pendingCard(notice, calendar: calendar.calendar)
                }
                ForEach(derived.indices, id: \.self) { index in
                    derivedCard(derived[index], calendar: calendar.calendar)
                }
            }
        }
    }

    @ViewBuilder
    private func pendingCard(_ notice: PendingNotice, calendar: Calendar) -> some View {
        let acknowledge = NoticeCard.Action(title: NoticeFormatting.acknowledgeLabel) {
            notices.acknowledge(id: notice.id)
        }
        switch notice.kind {
        case .missed(let times, let cause):
            NoticeCard(
                symbol: "exclamationmark.circle", symbolColor: NoticeCard.missedRed, tone: .neutral,
                title: NoticeFormatting.missedTitle(times: times),
                message: NoticeFormatting.missedBody(cause: cause), action: acknowledge)
        case .unattended(let times, let endedAt):
            NoticeCard(
                symbol: "alarm.waves.left.and.right", symbolColor: PanelStyle.accent, tone: .neutral,
                title: NoticeFormatting.unattendedTitle(times: times),
                message: NoticeFormatting.unattendedBody(endedAt: endedAt, calendar: calendar), action: acknowledge)
        }
    }

    @ViewBuilder
    private func derivedCard(_ notice: DerivedNotice, calendar: Calendar) -> some View {
        switch notice {
        case .bedtimeOffWithAlarmSoon(let upcoming):
            NoticeCard(
                symbol: "moon.zzz", symbolColor: PanelStyle.warning, tone: .warning,
                title: NoticeFormatting.bedtimeOffTitle,
                message: NoticeFormatting.bedtimeOffBody(upcoming: upcoming, now: clock.now, calendar: calendar),
                action: NoticeCard.Action(title: NoticeFormatting.activateBedtimeLabel) { bedtime.turnOn() })
        case .bedtimeOnBattery:
            NoticeCard(
                symbol: "battery.25", symbolColor: PanelStyle.warning, tone: .warning,
                title: NoticeFormatting.batteryTitle, message: NoticeFormatting.batteryBody, action: nil)
        }
    }
}

/// One card. Neutral cards (missed, unattended) are the panel's usual white 6 %; warning cards
/// (Bedtime off, battery) are yellow, and their one button is solid yellow.
private struct NoticeCard: View {
    enum Tone { case neutral, warning }

    struct Action {
        let title: String
        let run: () -> Void
    }

    static let missedRed = Color(red: 255 / 255, green: 105 / 255, blue: 97 / 255)  // #ff6961

    let symbol: String
    let symbolColor: Color
    let tone: Tone
    let title: String
    let message: String
    let action: Action?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(symbolColor)
                .frame(width: 18)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PanelStyle.primaryText)
                Text(message)
                    .font(.system(size: 12))
                    .lineSpacing(2)
                    .foregroundStyle(messageColor)
                if let action {
                    Button(action: action.run) {
                        Text(action.title)
                            .font(.system(size: 12, weight: tone == .warning ? .semibold : .medium))
                            .foregroundStyle(tone == .warning ? Self.onYellow : PanelStyle.primaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(
                                tone == .warning ? PanelStyle.warning : Color.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(tone == .warning ? PanelStyle.warning.opacity(0.10) : PanelStyle.card, in: shape)
        .overlay(shape.stroke(tone == .warning ? PanelStyle.warning.opacity(0.28) : PanelStyle.cardBorder))
        .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10) }

    private var messageColor: Color {
        tone == .warning
            ? Color(red: 209 / 255, green: 209 / 255, blue: 214 / 255)  // #d1d1d6
            : Color(red: 199 / 255, green: 199 / 255, blue: 204 / 255)  // #c7c7cc
    }

    private static let onYellow = Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)  // #1d1d1f
}
