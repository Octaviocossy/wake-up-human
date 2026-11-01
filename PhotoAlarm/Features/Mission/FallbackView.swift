import SwiftUI

/// The Fallback: 15 arithmetic problems in a row, for a lost or moved Target object. A wrong answer sends
/// the count back to 0. The count is persisted by the loop, so leaving this screen loses nothing.
struct FallbackView: View {
    let model: MissionModel
    let onClose: () -> Void

    @State private var problem = FallbackChallenge.makeProblem()
    @State private var answer = ""
    @State private var lastAnswerWasWrong = false
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        !isSubmitting && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Emergency fallback").font(.title.bold())
            Text("\(model.fallbackSolved) of \(MissionPolicy.fallbackProblemCount)")
                .font(.title3.monospacedDigit())
            if lastAnswerWasWrong {
                Text("Wrong — back to 0").foregroundStyle(.red)
            }

            Text(problem.text)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()

            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .multilineTextAlignment(.center)

            Button("Submit", action: submit)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmit)

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }
            Button("Back to the camera", action: onClose)
            Spacer()
        }
        .padding()
    }

    private func submit() {
        let correct = FallbackChallenge.isCorrect(answer, for: problem)
        lastAnswerWasWrong = !correct
        answer = ""
        problem = FallbackChallenge.makeProblem()
        isSubmitting = true
        Task {
            await model.submitFallbackAnswer(correct: correct)
            isSubmitting = false
        }
    }
}
