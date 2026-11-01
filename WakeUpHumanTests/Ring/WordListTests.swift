import Foundation
import Testing

@testable import WakeUpHuman

struct WordListTests {
    private static let validText = "mesa\ncamino\nverde\npan\nventana\nnube\n"

    @Test func bundledListHasAtLeast200Words() throws {
        let list = try WordList.bundled()

        #expect(list.words.count >= 200)
    }

    @Test func bundledWordsAreThreeToEightLowercaseLetters() throws {
        let list = try WordList.bundled()

        #expect(list.words.allSatisfy { $0.wholeMatch(of: /[a-z]{3,8}/) != nil })
    }

    @Test func bundledWordsAreUnique() throws {
        let list = try WordList.bundled()

        #expect(Set(list.words).count == list.words.count)
    }

    @Test func fallbackPassesTheSameChecksAsTheBundledList() throws {
        let parsed = try WordList(text: WordList.fallback.words.joined(separator: "\n"))

        #expect(parsed.words == WordList.fallback.words)
        #expect(WordList.fallback.words.count == 30)
    }

    @Test func fallbackWordsComeFromTheBundledList() throws {
        let bundled = Set(try WordList.bundled().words)

        #expect(WordList.fallback.words.allSatisfy(bundled.contains))
    }

    @Test func parsesOneWordPerLineAndIgnoresBlankLines() throws {
        let list = try WordList(text: "mesa\n\ncamino\n  \nverde\r\npan\nventana\nnube")

        #expect(list.words == ["mesa", "camino", "verde", "pan", "ventana", "nube"])
    }

    @Test func rejectsAnAccentedWord() {
        #expect(throws: WordList.LoadError.invalidWord("camión")) {
            try WordList(text: Self.validText + "camión\n")
        }
    }

    @Test func rejectsAnUppercaseWord() {
        #expect(throws: WordList.LoadError.invalidWord("Mesa")) {
            try WordList(text: Self.validText + "Mesa\n")
        }
    }

    @Test func rejectsAWordOutsideThreeToEightLetters() {
        #expect(throws: WordList.LoadError.invalidWord("no")) {
            try WordList(text: Self.validText + "no\n")
        }
        #expect(throws: WordList.LoadError.invalidWord("tranquilo")) {
            try WordList(text: Self.validText + "tranquilo\n")
        }
    }

    @Test func rejectsADuplicate() {
        #expect(throws: WordList.LoadError.duplicate("mesa")) {
            try WordList(text: Self.validText + "mesa\n")
        }
    }

    @Test func rejectsAListShorterThanTheChallenge() {
        #expect(throws: WordList.LoadError.tooShort(5)) {
            try WordList(text: "mesa\ncamino\nverde\npan\nventana\n")
        }
    }

    @Test func reportsAMissingResource() {
        #expect(throws: WordList.LoadError.missingResource) {
            try WordList.bundled(in: Bundle(for: BundleToken.self))
        }
    }

    private final class BundleToken {}
}
