import Foundation

/// One Fallback problem, e.g. `47 × 8 + 23`.
struct ArithmeticProblem: Equatable, Sendable {
    let a: Int
    let b: Int
    let c: Int

    var answer: Int { a * b + c }
    var text: String { "\(a) × \(b) + \(c)" }
}

enum FallbackChallenge {
    /// `a × b + c` with a in 11…99, b in 2…9 and c in 10…99: too slow to solve half asleep.
    static func makeProblem<G: RandomNumberGenerator>(using generator: inout G) -> ArithmeticProblem {
        ArithmeticProblem(
            a: .random(in: 11...99, using: &generator),
            b: .random(in: 2...9, using: &generator),
            c: .random(in: 10...99, using: &generator))
    }

    static func makeProblem() -> ArithmeticProblem {
        var generator = SystemRandomNumberGenerator()
        return makeProblem(using: &generator)
    }

    /// True when `input`, ignoring surrounding whitespace, is exactly the problem's answer.
    static func isCorrect(_ input: String, for problem: ArithmeticProblem) -> Bool {
        Int(input.trimmingCharacters(in: .whitespacesAndNewlines)) == problem.answer
    }
}
