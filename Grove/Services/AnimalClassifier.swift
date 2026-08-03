@preconcurrency import Vision
import UIKit

/// Turns a photo into a set of lowercased labels using Apple's on-device
/// Vision classifier. No model file, no network, no cost — perfect for the MVP.
///
/// Later we can swap the guts of `classify` for a `VNCoreMLRequest` backed by a
/// trained species model, or a cloud call, without touching callers.
enum AnimalClassifier {

    /// Returns Vision's top labels above a confidence floor, most-confident first.
    static func classify(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = image.cgOrientation

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Perform synchronously and read `results` directly — no completion
                // handler — so the continuation resumes on exactly one path.
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                    let observations = (request.results as? [VNClassificationObservation]) ?? []
                    let labels = observations
                        .filter { $0.confidence > 0.10 }
                        .prefix(12)
                        .map { $0.identifier.lowercased() }
                    continuation.resume(returning: Array(labels))
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Convenience: classify and resolve straight to a catalog `Species`.
    static func identify(_ image: UIImage) async -> Species {
        let labels = await classify(image)
        return CreatureCatalog.match(labels: labels)
    }
}

private extension UIImage {
    /// Bridges UIImage orientation into the CGImagePropertyOrientation Vision wants.
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
