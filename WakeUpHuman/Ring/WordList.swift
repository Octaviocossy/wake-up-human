import Foundation

/// The bundled Typing challenge vocabulary (spec decision 5).
struct WordList: Sendable {
    enum LoadError: Error, Equatable {
        case missingResource
        case invalidWord(String)  // not 3–8 lowercase a–z letters
        case duplicate(String)
        case tooShort(Int)  // fewer than `TypingChallenge.wordCount` words
    }

    static let letterCounts = 3...8

    let words: [String]

    /// Parses one word per line; blank lines are ignored.
    init(text: String) throws(LoadError) {
        var seen = Set<String>()
        var parsed: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let word = line.trimmingCharacters(in: .whitespaces)
            if word.isEmpty { continue }
            guard Self.isValid(word) else { throw .invalidWord(word) }
            guard seen.insert(word).inserted else { throw .duplicate(word) }
            parsed.append(word)
        }
        guard parsed.count >= TypingChallenge.wordCount else { throw .tooShort(parsed.count) }
        words = parsed
    }

    static func bundled(in bundle: Bundle = .main) throws(LoadError) -> WordList {
        guard
            let url = bundle.url(forResource: "words-es", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { throw .missingResource }
        return try WordList(text: text)
    }

    private static func isValid(_ word: String) -> Bool {
        letterCounts.contains(word.utf8.count)
            && word.utf8.allSatisfy { (UInt8(ascii: "a")...UInt8(ascii: "z")).contains($0) }
    }
}
