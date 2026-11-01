import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct RingPresentationTests {
    private let challenge = TypingChallenge(words: ["mesa", "camino", "verde", "pan", "ventana", "nube"])
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func makePresentation() -> RingPresentation {
        RingPresentation(
            challenge: challenge,
            alarmTimes: ["07:00"],
            startedAt: start,
            capEndsAt: start.addingTimeInterval(3_600)
        )
    }

    @Test func startsRingingWithNothingTyped() {
        let presentation = makePresentation()

        #expect(presentation.typed.isEmpty)
        #expect(presentation.phase == .ringing)
        #expect(presentation.progress.completedWords == 0)
    }

    @Test func insertLowercasesWhatIsTyped() {
        let presentation = makePresentation()

        presentation.insert("MESA")

        #expect(presentation.typed == "mesa")
    }

    @Test func insertDropsNewlines() {
        let presentation = makePresentation()

        presentation.insert("me\nsa\r")

        #expect(presentation.typed == "mesa")
    }

    @Test func deleteBackwardRemovesOneCharacter() {
        let presentation = makePresentation()
        presentation.insert("mesa")

        presentation.deleteBackward()

        #expect(presentation.typed == "mes")
    }

    @Test func deleteBackwardOnEmptyTextDoesNothing() {
        let presentation = makePresentation()

        presentation.deleteBackward()

        #expect(presentation.typed.isEmpty)
    }

    @Test func typingUpdatesTheProgress() {
        let presentation = makePresentation()

        presentation.insert("mesa ")

        #expect(presentation.progress.completedWords == 1)
    }

    @Test func typingTheTargetCallsOnSolvedOnce() {
        let presentation = makePresentation()
        var solved = 0
        presentation.onSolved = { solved += 1 }

        presentation.insert(challenge.target)

        #expect(solved == 1)
    }

    @Test func onSolvedFiresOnceEvenIfMoreTextFollows() {
        let presentation = makePresentation()
        var solved = 0
        presentation.onSolved = { solved += 1 }

        presentation.insert(challenge.target)
        presentation.insert(" ")
        presentation.insert("x")
        presentation.deleteBackward()
        presentation.deleteBackward()

        #expect(presentation.progress.isSolved)
        #expect(solved == 1)
    }

    @Test func solvingNeedsNoEnterAndAcceptsOneTrailingSpace() {
        let presentation = makePresentation()
        var solved = 0
        presentation.onSolved = { solved += 1 }

        presentation.insert(challenge.target.uppercased() + " ")

        #expect(solved == 1)
    }

    @Test func wrongTextNeverCallsOnSolved() {
        let presentation = makePresentation()
        var solved = 0
        presentation.onSolved = { solved += 1 }

        presentation.insert("mesa camino verde pan ventana nuve")

        #expect(solved == 0)
    }

    @Test func inputIsIgnoredAfterShowDismissed() {
        let presentation = makePresentation()
        presentation.insert("me")

        presentation.showDismissed(rangForSeconds: 352)
        presentation.insert("sa")
        presentation.deleteBackward()

        #expect(presentation.typed == "me")
        #expect(presentation.phase == .dismissed(rangForSeconds: 352))
    }

    @Test func inputIsCappedTenCharactersPastTheTarget() {
        let presentation = makePresentation()

        presentation.insert(String(repeating: "a", count: 100))

        #expect(presentation.typed.count == challenge.target.count + RingPresentation.maximumExtraCharacters)
    }

    @Test func rejectPasteShowsTheHintUntil1_8SecondsLater() {
        let presentation = makePresentation()
        let attempt = start.addingTimeInterval(10)
        #expect(!presentation.isShowingPasteHint(now: attempt))

        presentation.rejectPaste(now: attempt)

        #expect(presentation.isShowingPasteHint(now: attempt))
        #expect(presentation.isShowingPasteHint(now: attempt.addingTimeInterval(1.7)))
        #expect(!presentation.isShowingPasteHint(now: attempt.addingTimeInterval(1.8)))
    }

    @Test func rejectedPasteLeavesTheTypedTextUnchanged() {
        let presentation = makePresentation()
        presentation.insert("mesa")

        presentation.rejectPaste(now: start)

        #expect(presentation.typed == "mesa")
    }
}
