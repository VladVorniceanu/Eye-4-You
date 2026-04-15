import ImageIO
import UIKit
import Vision

final class PoseDetectionManager {
    static let shared = PoseDetectionManager()

    func detectPose(in image: UIImage) async -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        guard let fixedImage = image.fixedOrientation(), let cgImage = fixedImage.cgImage else {
            return [:]
        }

        return await detectPose(cgImage: cgImage, orientation: .up)
    }

    func detectPose(
        sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation
    ) async -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return [:]
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let request = VNDetectHumanBodyPoseRequest()
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

                do {
                    try handler.perform([request])
                    continuation.resume(returning: Self.extractPoints(from: request.results))
                } catch {
                    AppLogger.analysis.error("PoseDetectionManager: detectPose failed - \(error.localizedDescription)")
                    continuation.resume(returning: [:])
                }
            }
        }
    }

    private func detectPose(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) async -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let request = VNDetectHumanBodyPoseRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

                do {
                    try handler.perform([request])
                    continuation.resume(returning: Self.extractPoints(from: request.results))
                } catch {
                    AppLogger.analysis.error("PoseDetectionManager: detectPose failed - \(error.localizedDescription)")
                    continuation.resume(returning: [:])
                }
            }
        }
    }

    private static func extractPoints(
        from observations: [VNHumanBodyPoseObservation]?
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        guard let observations else {
            return [:]
        }

        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for observation in observations {
            guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
                continue
            }

            for (jointName, point) in recognizedPoints where point.confidence > 0.15 {
                points[jointName] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }
        }

        return points
    }
}
