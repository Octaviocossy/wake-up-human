import Testing

@testable import WakeUpHuman

/// A small seeded generator, so a draw is reproducible.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct TypingChallengeTests {
    private let challenge = TypingChallenge(words: ["mesa", "camino", "verde", "pan", "ventana", "nube"])

    private static let pool = [
        "mesa", "camino", "verde", "pan", "ventana", "nube", "perro", "libro", "agua", "casa",
        "calle", "fuego",
    ]

    @Test func drawReturnsSixDistinctWordsFromTheList() throws {
        let list = try WordList(text: Self.pool.joined(separator: "\n"))
        var generator = SplitMix64(seed: 42)

        let drawn = TypingChallenge.draw(from: list, using: &generator)

        #expect(drawn.words.count == TypingChallenge.wordCount)
        #expect(Set(drawn.words).count == TypingChallenge.wordCount)
        #expect(Set(drawn.words).isSubset(of: Set(list.words)))
    }

    @Test func drawIsDeterministicForTheSameSeed() throws {
        let list = try WordList(text: Self.pool.joined(separator: "\n"))
        var first = SplitMix64(seed: 7)
        var second = SplitMix64(seed: 7)

        #expect(
            TypingChallenge.draw(from: list, using: &first)
                == TypingChallenge.draw(from: list, using: &second))
    }

    @Test func drawVariesWithTheSeed() throws {
        let list = try WordList(text: Self.pool.joined(separator: "\n"))
        let draws = (UInt64(1)...20).map { seed in
            var generator = SplitMix64(seed: seed)
            return TypingChallenge.draw(from: list, using: &generator).words
        }

        #expect(Set(draws).count > 1)
    }

    @Test func targetJoinsTheWordsWithSingleSpaces() {
        #expect(challenge.target == "mesa camino verde pan ventana nube")
    }

    @Test func emptyInputPutsTheCursorOnTheFirstCharacter() {
        let progress = challenge.evaluate("")

        #expect(progress.words[0].characters[0].state == .cursor)
        #expect(progress.words[0].characters[1].state == .pending)
        #expect(progress.words[1].characters[0].state == .pending)
        #expect(progress.completedWords == 0)
        #expect(!progress.isSolved)
    }

    @Test func aCorrectFirstWordFollowedByASpaceIsCompleted() {
        let progress = challenge.evaluate("mesa ")

        #expect(progress.words[0].isDone)
        #expect(progress.words[0].characters.allSatisfy { $0.state == .done })
        #expect(progress.words[1].characters[0].state == .cursor)
        #expect(progress.completedWords == 1)
    }

    @Test func aCorrectFirstWordWithoutItsSpaceIsNotYetCompleted() {
        let progress = challenge.evaluate("mesa")

        #expect(!progress.words[0].isDone)
        #expect(progress.completedWords == 0)
    }

    @Test func aWrongLetterIsMarkedWithoutResettingEarlierWords() {
        let progress = challenge.evaluate("mesa camino vexde")

        #expect(progress.words[0].isDone)
        #expect(progress.words[1].isDone)
        #expect(progress.words[2].characters.map(\.state) == [.done, .done, .wrong, .done, .done])
        #expect(progress.words[2].hasError)
        #expect(!progress.words[2].isDone)
        #expect(progress.completedWords == 2)
    }

    @Test func aDoubleSpaceMarksTheNextWordInError() {
        let progress = challenge.evaluate("mesa  camino")

        #expect(progress.words[0].isDone)
        #expect(progress.words[1].hasError)
        #expect(progress.words[1].characters[0].state == .wrong)
    }

    @Test func aMissingSpaceMarksTheWordInError() {
        let progress = challenge.evaluate("mesax")

        #expect(progress.words[0].hasError)
        #expect(!progress.words[0].isDone)
    }

    @Test func theTargetSolvesTheChallenge() {
        let progress = challenge.evaluate(challenge.target)

        #expect(progress.isSolved)
        #expect(progress.completedWords == TypingChallenge.wordCount)
        #expect(challenge.isSolved(by: challenge.target))
    }

    @Test func theTargetWithOneTrailingSpaceSolvesTheChallenge() {
        let typed = challenge.target + " "

        #expect(challenge.isSolved(by: typed))
        #expect(challenge.evaluate(typed).isSolved)
        #expect(challenge.evaluate(typed).completedWords == TypingChallenge.wordCount)
    }

    @Test func theTargetWithTwoTrailingSpacesNeitherSolvesNorCompletesTheLastWord() {
        let typed = challenge.target + "  "
        let progress = challenge.evaluate(typed)

        #expect(!challenge.isSolved(by: typed))
        #expect(!progress.isSolved)
        #expect(progress.words[5].hasError)
        #expect(!progress.words[5].isDone)
        #expect(progress.completedWords == TypingChallenge.wordCount - 1)
    }

    @Test func theTargetFollowedByALetterIsAnError() {
        let progress = challenge.evaluate(challenge.target + "x")

        #expect(!progress.isSolved)
        #expect(progress.words[5].hasError)
    }

    @Test func evaluationComparesExactlyBecauseLowercasingIsTheCallersJob() {
        let progress = challenge.evaluate("MESA")

        #expect(progress.words[0].characters.allSatisfy { $0.state == .wrong })
        #expect(!challenge.isSolved(by: challenge.target.uppercased()))
    }
}
