import ImageIO
import SwiftUI

/// The only screen while a Wake-up session is open (spec decision 6): the camera first, then the result
/// of the Photo check, and the Fallback once it unlocks. No navigation, whatever opened the app.
struct MissionView: View {
    private enum Cover: String, Identifiable {
        case camera
        case fallback

        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var model: MissionModel
    @State private var cover: Cover?
    @State private var hasOpenedCamera = false
    @State private var unreadablePhoto = false

    init(
        repository: TargetObjectRepository,
        loop: WakeUpLoop = AppEnvironment.loop,
        matcher: any ObjectMatcher = AppEnvironment.matcher,
        onSessionsClosed: @escaping @MainActor () -> Void
    ) {
        _model = State(
            initialValue: MissionModel(
                loop: loop, matcher: matcher, repository: repository, onSessionsClosed: onSessionsClosed))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Wake up").font(.largeTitle.bold())
            Text("Take a photo of your object to end the alarm.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            resultSection
            Text("Failed attempts: \(shownFailedChecks) of \(MissionPolicy.fallbackUnlockFailures)")
                .foregroundStyle(.secondary)

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }
            if unreadablePhoto {
                Text("The camera returned an unreadable photo. Try again.").foregroundStyle(.red)
            }

            Button {
                cover = .camera
            } label: {
                Label(model.lastResult == nil ? "Take photo" : "Take photo again", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!CameraPicker.isAvailable || model.isChecking)

            if !CameraPicker.isAvailable {
                Label("Camera unavailable", systemImage: "camera.slash").foregroundStyle(.secondary)
            }

            if model.isFallbackUnlocked {
                Button("Emergency fallback") { cover = .fallback }
                    .buttonStyle(.bordered)
                    .disabled(model.isChecking)
            }
            Spacer()
        }
        .padding()
        .overlay { if model.isChecking { ProgressView("Checking…") } }
        // Postponing runs only while the app is in the foreground: leaving it (or locking the phone) cancels
        // the task, so the pending Follow-up rings within a minute.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.runForegroundTicks()
        }
        // The brief: the app opens straight into the camera.
        .task {
            guard !hasOpenedCamera else { return }
            hasOpenedCamera = true
            if CameraPicker.isAvailable { cover = .camera }
        }
        .fullScreenCover(item: $cover) { cover in
            switch cover {
            case .camera:
                CameraPicker(
                    onCapture: { image in
                        self.cover = nil
                        handle(image)
                    },
                    onCancel: { self.cover = nil }
                )
                .ignoresSafeArea()
            case .fallback:
                FallbackView(model: model, onClose: { self.cover = nil })
            }
        }
    }

    /// Failed attempts are shown up to the unlock count; past it the Fallback button says the rest.
    private var shownFailedChecks: Int {
        min(model.failedChecks, MissionPolicy.fallbackUnlockFailures)
    }

    @ViewBuilder private var resultSection: some View {
        switch model.lastResult {
        case .match:
            Label("Match", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .noMatch:
            Label("No match", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case nil:
            EmptyView()
        }
        #if DEBUG
            if let distance = model.lastDistance {
                Text("Distance \(distance, format: .number.precision(.fractionLength(3)))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        #endif
    }

    private func handle(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            unreadablePhoto = true
            return
        }
        unreadablePhoto = false
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        Task { await model.check(cgImage, orientation: orientation) }
    }
}
