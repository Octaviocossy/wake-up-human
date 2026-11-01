import Testing

@testable import PhotoAlarm

struct FallbackChallengeTests {
    @Test func seededProblemsStayInsideTheDocumentedRanges() {
        var generator = SeededGenerator(seed: 42)
        for _ in 0..<500 {
            let problem = FallbackChallenge.makeProblem(using: &generator)
            #expect((11...99).contains(problem.a))
            #expect((2...9).contains(problem.b))
            #expect((10...99).contains(problem.c))
            #expect(problem.answer == problem.a * problem.b + problem.c)
        }
    }

    @Test func theSameSeedMakesTheSameProblems() {
        var first = SeededGenerator(seed: 7)
        var second = SeededGenerator(seed: 7)
        for _ in 0..<20 {
            #expect(FallbackChallenge.makeProblem(using: &first) == FallbackChallenge.makeProblem(using: &second))
        }
    }

    @Test func theTextShowsTheProblem() {
        #expect(ArithmeticProblem(a: 47, b: 8, c: 23).text == "47 × 8 + 23")
    }

    @Test func theCorrectAnswerIsAcceptedWithSurroundingWhitespace() {
        let problem = ArithmeticProblem(a: 47, b: 8, c: 23)
        #expect(problem.answer == 399)
        #expect(FallbackChallenge.isCorrect("399", for: problem))
        #expect(FallbackChallenge.isCorrect("  399\n", for: problem))
    }

    @Test func aWrongNumberIsRejected() {
        let problem = ArithmeticProblem(a: 47, b: 8, c: 23)
        #expect(FallbackChallenge.isCorrect("398", for: problem) == false)
        #expect(FallbackChallenge.isCorrect("0", for: problem) == false)
    }

    @Test func textThatIsNotAWholeNumberIsRejected() {
        let problem = ArithmeticProblem(a: 47, b: 8, c: 23)
        #expect(FallbackChallenge.isCorrect("", for: problem) == false)
        #expect(FallbackChallenge.isCorrect("abc", for: problem) == false)
        #expect(FallbackChallenge.isCorrect("39 9", for: problem) == false)
        #expect(FallbackChallenge.isCorrect("399.0", for: problem) == false)
    }
}
