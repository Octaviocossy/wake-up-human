import CoreGraphics
import Foundation
import ImageIO
import Vision

struct VisionObjectMatcher: ObjectMatcher {
    func featurePrint(of image: CGImage, orientation: CGImagePropertyOrientation) async throws -> Data {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        try handler.perform([request])
        guard let observation = request.results?.first else { throw ObjectMatcherError.noFeaturePrint }
        return try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    func smallestDistance(from candidate: Data, toAnyOf references: [Data]) throws -> Float {
        guard !references.isEmpty else { throw ObjectMatcherError.noReferences }
        let candidatePrint = try Self.unarchive(candidate)
        var best = Float.greatestFiniteMagnitude
        for reference in references {
            var distance: Float = 0
            try candidatePrint.computeDistance(&distance, to: try Self.unarchive(reference))
            best = min(best, distance)
        }
        #if DEBUG
            Log.vision.debug("smallest distance \(best)")
        #endif
        return best
    }

    static func unarchive(_ data: Data) throws -> VNFeaturePrintObservation {
        guard
            let observation = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self, from: data)
        else { throw ObjectMatcherError.corruptFeaturePrint }
        return observation
    }
}
