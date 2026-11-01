/// Six words to retype to Dismiss a Ring (glossary › Typing challenge).
struct TypingChallenge: Equatable, Sendable {
    static let wordCount = 6

    let words: [String]
    var target: String { words.joined(separator: " ") }

    /// Draws `wordCount` distinct words — fresh for every Ring.
    static func draw(
        from list: WordList,
        using generator: inout some RandomNumberGenerator
    ) -> TypingChallenge {
        var pool = list.words
        var drawn: [String] = []
        for _ in 0..<wordCount where !pool.isEmpty {
            drawn.append(pool.remove(at: Int.random(in: 0..<pool.count, using: &generator)))
        }
        return TypingChallenge(words: drawn)
    }

    static func draw(from list: WordList) -> TypingChallenge {
        var generator = SystemRandomNumberGenerator()
        return draw(from: list, using: &generator)
    }

    /// Lowercased typed text that matches the target, optionally followed by one space.
    func isSolved(by typed: String) -> Bool { typed == target || typed == target + " " }

    /// Positional, per-character progress (a port of the prototype's `renderVals`), so a mistake
    /// never resets what came after it. `typed` must already be lowercased: this compares exactly.
    func evaluate(_ typed: String) -> ChallengeProgress {
        let typedCharacters = Array(typed)
        let targetCount = target.count
        var offset = 0
        var completed = 0
        var progress: [WordProgress] = []

        for (index, word) in words.enumerated() {
            var hasError = false
            var allCorrect = true
            var characters: [WordProgress.Entry] = []

            for (j, character) in word.enumerated() {
                let position = offset + j
                let state: CharacterState
                if position < typedCharacters.count {
                    if typedCharacters[position] == character {
                        state = .done
                    } else {
                        state = .wrong
                        hasError = true
                        allCorrect = false
                    }
                } else {
                    allCorrect = false
                    state = position == typedCharacters.count ? .cursor : .pending
                }
                characters.append(WordProgress.Entry(character: character, state: state))
            }

            let spacePosition = offset + word.count
            let isLast = index == words.count - 1
            if !isLast, spacePosition < typedCharacters.count, typedCharacters[spacePosition] != " " {
                hasError = true
            }
            if isLast {
                // One trailing space is tolerated; anything else past the target is an error
                // (spec decision 5).
                let extra = typedCharacters.count - targetCount
                if extra > 1 || (extra == 1 && typedCharacters.last != " ") { hasError = true }
            }

            let isDone = allCorrect && !hasError && (isLast || spacePosition < typedCharacters.count)
            if isDone { completed += 1 }
            progress.append(WordProgress(characters: characters, isDone: isDone, hasError: hasError))
            offset = spacePosition + 1
        }

        return ChallengeProgress(
            words: progress,
            completedWords: completed,
            isSolved: isSolved(by: typed)
        )
    }
}

enum CharacterState: Equatable, Sendable { case done, wrong, cursor, pending }

struct WordProgress: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        let character: Character
        let state: CharacterState
    }

    let characters: [Entry]
    let isDone: Bool
    let hasError: Bool
}

struct ChallengeProgress: Equatable, Sendable {
    let words: [WordProgress]
    let completedWords: Int
    let isSolved: Bool
}
