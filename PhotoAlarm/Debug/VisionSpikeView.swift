#if DEBUG
    import ImageIO
    import SwiftData
    import SwiftUI
    import UIKit

    /// One measurement of the calibration screen.
    struct VisionMeasurement: Identifiable {
        let id = UUID()
        let label: String
        let lighting: String
        let distance: Float
        let result: PhotoCheckResult
        let time: Date

        var resultText: String { result == .match ? "match" : "no-match" }

        /// `label,lighting,distance,result,time` — fields containing a comma, quote or newline are quoted.
        var csvLine: String {
            [
                Self.csvField(label),
                Self.csvField(lighting),
                String(format: "%.4f", distance),
                resultText,
                time.formatted(.iso8601),
            ].joined(separator: ",")
        }

        static func csvField(_ value: String) -> String {
            guard value.contains(where: { ",\"\n\r".contains($0) }) else { return value }
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
    }

    /// Calibration screen: measures the smallest distance of live photos against the registered
    /// References so `MatchThreshold.value` can be chosen on the device.
    struct VisionSpikeView: View {
        @Environment(\.modelContext) private var modelContext
        @Query private var objects: [TargetObject]
        @State private var label = ""
        @State private var lighting = ""
        @State private var measurements: [VisionMeasurement] = []
        @State private var isShowingCamera = false
        @State private var isWorking = false
        @State private var errorMessage: String?

        private let matcher = VisionObjectMatcher()

        private var referenceCount: Int { objects.first?.references.count ?? 0 }

        var body: some View {
            List {
                Section {
                    if referenceCount == 0 {
                        Text("Register the target object first")
                    } else {
                        Text(
                            "\(referenceCount) references · threshold \(MatchThreshold.value, format: .number.precision(.fractionLength(3)))"
                        )
                        TextField("Label (target, red mug, similar bottle)", text: $label)
                        TextField("Lighting (daylight, dim morning)", text: $lighting)
                        if CameraPicker.isAvailable {
                            Button("Capture & measure") { isShowingCamera = true }
                                .disabled(isWorking)
                        } else {
                            Label("Camera unavailable", systemImage: "camera.slash")
                        }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                if !measurements.isEmpty {
                    Section("Measurements") {
                        ForEach(measurements) { row in
                            VStack(alignment: .leading) {
                                Text(
                                    "\(row.label.isEmpty ? "(no label)" : row.label) · \(row.lighting.isEmpty ? "(no lighting)" : row.lighting)"
                                )
                                Text(
                                    "\(row.distance, format: .number.precision(.fractionLength(4))) · \(row.resultText) · \(row.time.formatted(date: .omitted, time: .standard))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        Button("Copy CSV") { UIPasteboard.general.string = csv }
                        Button("Clear", role: .destructive) { measurements = [] }
                    }
                }
            }
            .navigationTitle("Vision spike")
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker(
                    onCapture: { image in
                        isShowingCamera = false
                        measure(image)
                    },
                    onCancel: { isShowingCamera = false }
                )
                .ignoresSafeArea()
            }
        }

        private var csv: String {
            (["label,lighting,distance,result,time"] + measurements.map(\.csvLine)).joined(separator: "\n")
        }

        private func measure(_ image: UIImage) {
            guard let cgImage = image.cgImage else {
                errorMessage = "The camera returned an unreadable photo."
                return
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let label = label
            let lighting = lighting
            isWorking = true
            errorMessage = nil
            Task {
                defer { isWorking = false }
                do {
                    let references = try TargetObjectRepository(context: modelContext).referencePrints()
                    let candidate = try await matcher.featurePrint(of: cgImage, orientation: orientation)
                    let distance = try matcher.smallestDistance(from: candidate, toAnyOf: references)
                    let result = PhotoCheck.evaluate(distance: distance)
                    let row = VisionMeasurement(
                        label: label, lighting: lighting, distance: distance, result: result, time: .now)
                    measurements.insert(row, at: 0)
                    Log.vision.info(
                        "measure label=\(label, privacy: .public) lighting=\(lighting, privacy: .public) distance=\(distance) result=\(row.resultText, privacy: .public)"
                    )
                } catch {
                    errorMessage = "Could not measure that photo: \(error)"
                }
            }
        }
    }
#endif
