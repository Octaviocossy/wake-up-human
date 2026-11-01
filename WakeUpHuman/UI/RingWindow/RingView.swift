import SwiftUI

/// Colours of `docs/design/ring-window.html` that `PanelStyle` does not already carry.
private enum RingStyle {
    static let wordBox = Color(hex: 0x0F0F10)
    static let hairline = Color(hex: 0x2C2C2E)
    static let field = Color(hex: 0x161618)
    static let chip = Color(hex: 0x1C1C1E)
    static let chipBorder = Color(hex: 0x3A3A3C)
    static let subtitle = Color(hex: 0xC7C7CC)
    static let chipText = Color(hex: 0x1D1D1F)
    static let wrongText = Color(hex: 0xFF6961)
    static let done = Color(hex: 0xF5F5F7)
    static let pending = Color(hex: 0x8E8E93)
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The Ring window's content: the Typing challenge while ringing, "Alarma apagada" once Dismissed.
struct RingView: View {
    let presentation: RingPresentation

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch presentation.phase {
            case .ringing:
                ringing
                bottomBar
            case .dismissed(let rangForSeconds):
                dismissed(rangForSeconds: rangForSeconds)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(PanelStyle.primaryText)
        .preferredColorScheme(.dark)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 12) {
                statusChip
                if let joined = RingFormatting.joined(alarmTimes: presentation.alarmTimes) {
                    joinedChip(joined)
                }
            }
            Spacer()
            if presentation.phase == .ringing {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(RingFormatting.elapsed(elapsedSeconds(at: context.date)))
                        .font(.system(size: 14))
                        .monospacedDigit()
                        .foregroundStyle(PanelStyle.secondaryText)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "alarm")
                .font(.system(size: 15, weight: .semibold))
            Text(RingFormatting.status(alarmTimes: presentation.alarmTimes))
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(RingStyle.chipText)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(height: 34)
        .background(PanelStyle.accent, in: Capsule())
    }

    private func joinedChip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PanelStyle.accent)
            Text(text)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(RingStyle.chip, in: Capsule())
        .overlay(Capsule().strokeBorder(RingStyle.chipBorder, lineWidth: 1))
    }

    // MARK: Ringing

    private var ringing: some View {
        VStack(spacing: 36) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(RingFormatting.clock(context.date, calendar: .current))
                    .font(.system(size: 168, weight: .ultraLight))
                    .monospacedDigit()
                    .tracking(-6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            VStack(spacing: 22) {
                Text("Escribí estas seis palabras para apagarla")
                    .font(.system(size: 17))
                    .foregroundStyle(RingStyle.subtitle)
                wordBoxes
            }
            VStack(spacing: 14) {
                inputField
                progressRow
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wordBoxes: some View {
        FlowLayout(spacing: 14, lineSpacing: 14) {
            ForEach(Array(presentation.progress.words.enumerated()), id: \.offset) { _, word in
                wordBox(word)
            }
        }
        .frame(maxWidth: 1280)
        .accessibilityHidden(true)
    }

    private func wordBox(_ word: WordProgress) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(word.characters.enumerated()), id: \.offset) { _, entry in
                characterView(entry)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(word.isDone ? PanelStyle.accent.opacity(0.10) : RingStyle.wordBox)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(boxBorder(for: word), lineWidth: 1.5)
        )
    }

    private func boxBorder(for word: WordProgress) -> Color {
        if word.hasError { return PanelStyle.danger }
        return word.isDone ? PanelStyle.accent.opacity(0.6) : RingStyle.hairline
    }

    private func characterView(_ entry: WordProgress.Entry) -> some View {
        Text(String(entry.character))
            .font(.system(size: 40, weight: .medium, design: .monospaced))
            .foregroundStyle(color(for: entry.state))
            .lineLimit(1)
            .fixedSize()
            .background {
                if entry.state == .wrong {
                    RoundedRectangle(cornerRadius: 4).fill(PanelStyle.danger.opacity(0.2))
                }
            }
            .overlay(alignment: .bottom) {
                if entry.state == .cursor {
                    Rectangle().fill(PanelStyle.accent).frame(height: 3)
                }
            }
    }

    private func color(for state: CharacterState) -> Color {
        switch state {
        case .done: RingStyle.done
        case .wrong: RingStyle.wrongText
        case .cursor, .pending: RingStyle.pending
        }
    }

    /// The field look. The real input is `ChallengeInputView`, an invisible key-capturing view laid
    /// over it, so the text shown here can never be pasted into.
    private var inputField: some View {
        HStack(spacing: 2) {
            if presentation.typed.isEmpty {
                caret
                Text("escribí acá…")
                    .foregroundStyle(PanelStyle.tertiaryText)
            } else {
                Text(presentation.typed)
                    .truncationMode(.head)
                caret
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 26, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, 24)
        .frame(width: 760, height: 66)
        .background(RingStyle.field, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(PanelStyle.accent, lineWidth: 2))
        .accessibilityHidden(true)
        .overlay {
            ChallengeInputView(
                target: presentation.challenge.target,
                typed: presentation.typed,
                onInsert: { presentation.insert($0) },
                onDeleteBackward: { presentation.deleteBackward() },
                onPasteAttempt: { presentation.rejectPaste() }
            )
        }
    }

    private var caret: some View {
        Rectangle().fill(PanelStyle.accent).frame(width: 2, height: 30)
    }

    private var progressRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<TypingChallenge.wordCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < presentation.progress.completedWords ? PanelStyle.accent : RingStyle.hairline)
                        .frame(width: 34, height: 6)
                }
            }
            Text(RingFormatting.progress(completed: presentation.progress.completedWords))
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(PanelStyle.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RingFormatting.progress(completed: presentation.progress.completedWords))
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 24) {
            volumeRow
                .frame(maxWidth: .infinity, alignment: .leading)
            pasteHint
            Text(
                RingFormatting.cap(
                    endsAt: presentation.capEndsAt,
                    calendar: .current,
                    minutes: capMinutes
                )
            )
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 13))
        .foregroundStyle(PanelStyle.secondaryText)
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 30)
        .overlay(alignment: .top) {
            Rectangle().fill(RingStyle.chip).frame(height: 1)
        }
    }

    @ViewBuilder
    private var volumeRow: some View {
        if let label = RingFormatting.volume(presentation.volume) {
            HStack(spacing: 12) {
                Image(systemName: presentation.volume == .unavailable ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 15))
                    .foregroundStyle(RingStyle.subtitle)
                if let fraction = volumeFraction {
                    Capsule()
                        .fill(RingStyle.hairline)
                        .frame(width: 140, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(PanelStyle.accent).frame(width: 140 * fraction, height: 6)
                        }
                        .animation(.linear(duration: 0.9), value: fraction)
                }
                Text(label).monospacedDigit()
            }
        }
    }

    private var volumeFraction: Double? {
        switch presentation.volume {
        case .ramping(let percent, _): Double(min(max(percent, 0), 100)) / 100
        case .atMaximum: 1
        case .unknown, .unavailable: nil
        }
    }

    private var pasteHint: some View {
        // Half-second ticks so the yellow hint clears close to `pasteHintDuration`.
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let rejected = presentation.isShowingPasteHint(now: context.date)
            HStack(spacing: 8) {
                Image(systemName: "lock").font(.system(size: 12))
                Text(RingFormatting.pasteHint(rejected: rejected))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(rejected ? PanelStyle.warning : PanelStyle.secondaryText)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rejected ? PanelStyle.warning.opacity(0.14) : Color.clear)
            )
            .animation(.easeOut(duration: 0.2), value: rejected)
        }
    }

    // MARK: Dismissed

    private func dismissed(rangForSeconds: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(PanelStyle.accent)
                .frame(width: 88, height: 88)
                .background(PanelStyle.accent.opacity(0.14), in: Circle())
            Text("Alarma apagada")
                .font(.system(size: 40, weight: .light))
                .tracking(-0.5)
            Text("Volvieron el volumen y el silencio que tenías.")
                .font(.system(size: 17))
                .foregroundStyle(RingStyle.subtitle)
            Text(RingFormatting.rangFor(rangForSeconds))
                .font(.system(size: 15))
                .monospacedDigit()
                .foregroundStyle(PanelStyle.secondaryText)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Time

    private func elapsedSeconds(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(presentation.startedAt)))
    }

    private var capMinutes: Int {
        Int((presentation.capEndsAt.timeIntervalSince(presentation.startedAt) / 60).rounded())
    }
}

/// A centred, wrapping row of views (the prototype's `flex-wrap: wrap; justify-content: center`).
private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    RingView(
        presentation: {
            let presentation = RingPresentation(
                challenge: TypingChallenge(words: ["mesa", "camino", "verde", "pan", "ventana", "nube"]),
                alarmTimes: ["07:00", "07:05"],
                startedAt: Date().addingTimeInterval(-14),
                capEndsAt: Date().addingTimeInterval(3_586)
            )
            presentation.insert("mesa camino vere")
            presentation.volume = .ramping(percent: 35, secondsToMax: 16)
            return presentation
        }()
    )
    .frame(width: 1440, height: 900)
}
