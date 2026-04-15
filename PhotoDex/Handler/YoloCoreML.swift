import CoreML
import ImageIO
import UIKit
import Vision

enum YoloCoreML {
    static func createYOLOModel() throws -> VNCoreMLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        return try VNCoreMLModel(for: yolov5s(configuration: configuration).model)
    }

    static func makePredictionsUsingYOLO(
        for image: UIImage,
        model: VNCoreMLModel
    ) throws -> [Prediction] {
        guard let fixedImage = image.fixedOrientation(), let cgImage = fixedImage.cgImage else {
            throw NSError(domain: "YoloCoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }

        return try performRequest(
            model: model,
            handler: VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        )
    }

    static func makePredictionsUsingYOLO(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        model: VNCoreMLModel
    ) throws -> [Prediction] {
        try performRequest(
            model: model,
            handler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        )
    }

    private static func performRequest(model: VNCoreMLModel, handler: VNImageRequestHandler) throws -> [Prediction] {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        try handler.perform([request])

        let results = request.results as? [VNRecognizedObjectObservation] ?? []
        return results.map {
            Prediction(
                label: $0.labels.first?.identifier ?? "Unknown",
                confidence: $0.confidence,
                boundingBox: $0.boundingBox
            )
        }
    }
}
