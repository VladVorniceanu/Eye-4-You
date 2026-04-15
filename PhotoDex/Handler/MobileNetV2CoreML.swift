import CoreML
import UIKit
import Vision

enum MobileNetV2CoreML {
    static func createMobileNetModel() throws -> VNCoreMLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        return try VNCoreMLModel(for: MobileNetV2(configuration: configuration).model)
    }

    static func makePredictionMobileNetV2(
        for image: UIImage,
        model: VNCoreMLModel
    ) throws -> Prediction {
        guard let fixedImage = image.fixedOrientation(), let cgImage = fixedImage.cgImage else {
            throw NSError(domain: "MobileNetV2CoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        guard
            let predictions = request.results as? [VNClassificationObservation],
            let bestPrediction = predictions.max(by: { $0.confidence < $1.confidence })
        else {
            throw NSError(domain: "MobileNetV2CoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "No predictions found"])
        }

        return Prediction(label: bestPrediction.identifier, confidence: bestPrediction.confidence, boundingBox: nil)
    }
}
