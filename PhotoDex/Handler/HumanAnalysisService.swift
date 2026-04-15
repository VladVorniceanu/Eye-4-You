import CoreML
import UIKit
@preconcurrency import Vision

final class HumanAnalysisService: @unchecked Sendable {
    static let shared = HumanAnalysisService()

    private let ageModel: VNCoreMLModel
    private let genderModel: VNCoreMLModel
    private let emotionModel: VNCoreMLModel

    private init() {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine

        do {
            ageModel = try VNCoreMLModel(for: AgeNet(configuration: configuration).model)
            genderModel = try VNCoreMLModel(for: GenderNet(configuration: configuration).model)
            emotionModel = try VNCoreMLModel(for: EmotionNet(configuration: configuration).model)
        } catch {
            fatalError("Failed to load human analysis models: \(error.localizedDescription)")
        }
    }

    func analyzeHuman(in image: UIImage) async -> HumanAnalysisResult? {
        guard let cgImage = image.fixedOrientation()?.cgImage ?? image.cgImage else {
            AppLogger.analysis.error("HumanAnalysisService: invalid CGImage")
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let ageRequest = VNCoreMLRequest(model: self.ageModel)
                ageRequest.imageCropAndScaleOption = .centerCrop

                let genderRequest = VNCoreMLRequest(model: self.genderModel)
                genderRequest.imageCropAndScaleOption = .centerCrop

                let emotionRequest = VNCoreMLRequest(model: self.emotionModel)
                emotionRequest.imageCropAndScaleOption = .centerCrop

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([ageRequest, genderRequest, emotionRequest])

                    let age = (ageRequest.results as? [VNClassificationObservation])?.first?.identifier
                    let gender = (genderRequest.results as? [VNClassificationObservation])?.first?.identifier
                    let emotion = (emotionRequest.results as? [VNClassificationObservation])?.first?.identifier

                    guard let age, let gender, let emotion else {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(returning: HumanAnalysisResult(age: age, gender: gender, emotion: emotion))
                } catch {
                    AppLogger.analysis.error("HumanAnalysisService: perform failed - \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
