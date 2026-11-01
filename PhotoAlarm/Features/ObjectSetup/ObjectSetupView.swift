import ImageIO
import SwiftData
import SwiftUI

struct ObjectSetupView: View {
    private enum CaptureKind: String, Identifiable {
        case reference
        case test

        var id: String { rawValue }
    }

    @Query private var existingObjects: [TargetObject]
    @State private var model: ObjectSetupModel
    @State private var captureKind: CaptureKind?
    @State private var isWorking = false
    @State private var unreadablePhoto = false

    init(matcher: any ObjectMatcher, repository: TargetObjectRepository) {
        _model = State(initialValue: ObjectSetupModel(matcher: matcher, repository: repository))
    }

    var body: some View {
        List {
            Section("How to take the photos") {
                Text(
                    "Take 3 to 5 photos of the object from different angles and in different lighting, "
                        + "with the object filling most of the frame. Then take one more photo to test it.")
                if !existingObjects.isEmpty {
                    Text("An object is already registered. Finishing this setup replaces it.")
                        .foregroundStyle(.secondary)
                }
            }

            if !CameraPicker.isAvailable {
                Section { Label("Camera unavailable", systemImage: "camera.slash") }
            }

            switch model.phase {
            case .capturing: capturingSection
            case .testing: testingSection
            case .testFailed(let distance): testFailedSection(distance: distance)
            case .registered: registeredSection
            }

            if let message = model.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
            if unreadablePhoto {
                Section { Text("The camera returned an unreadable photo. Try again.").foregroundStyle(.red) }
            }
        }
        .navigationTitle("Target object")
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView() } }
        .fullScreenCover(item: $captureKind) { kind in
            CameraPicker(
                onCapture: { image in
                    captureKind = nil
                    handle(image, as: kind)
                },
                onCancel: { captureKind = nil }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var capturingSection: some View {
        Section {
            Text(
                "\(model.capturedPrints.count) of \(ObjectSetupModel.minReferences)–\(ObjectSetupModel.maxReferences) photos"
            )
            if model.canCaptureMore {
                Button("Take reference photo") { captureKind = .reference }
                    .disabled(!CameraPicker.isAvailable)
            }
            if model.canStartTest {
                Button("Test the object") { model.startTest() }
            }
            if !model.capturedPrints.isEmpty {
                Button("Start over", role: .destructive) { restart() }
            }
        }
    }

    private var testingSection: some View {
        Section("Test") {
            Text("Take one more photo of the object to check that it is recognized.")
            Button("Take test photo") { captureKind = .test }
                .disabled(!CameraPicker.isAvailable)
            Button("Start over", role: .destructive) { restart() }
        }
    }

    private func testFailedSection(distance: Float) -> some View {
        Section("Test failed") {
            Text(
                "No match. Distance \(distance, format: .number.precision(.fractionLength(3))), needs below \(MatchThreshold.value, format: .number.precision(.fractionLength(3)))."
            )
            Button("Retry test") { model.retryTest() }
            Button("Start over", role: .destructive) { restart() }
        }
    }

    private var registeredSection: some View {
        Section("Registered") {
            Text("The object is registered with \(model.capturedPrints.count) references.")
            if let distance = model.lastTestDistance {
                Text("Test distance \(distance, format: .number.precision(.fractionLength(3)))")
                    .foregroundStyle(.secondary)
            }
            Button("Register again") { restart() }
        }
    }

    // MARK: - Actions

    private func restart() {
        unreadablePhoto = false
        model.restart()
    }

    private func handle(_ image: UIImage, as kind: CaptureKind) {
        guard let cgImage = image.cgImage else {
            unreadablePhoto = true
            return
        }
        unreadablePhoto = false
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        isWorking = true
        Task {
            switch kind {
            case .reference: await model.addReference(cgImage, orientation: orientation)
            case .test: await model.submitTestPhoto(cgImage, orientation: orientation)
            }
            isWorking = false
        }
    }
}
