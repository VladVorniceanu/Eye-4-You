import CoreML
import QuartzCore
import UIKit
@preconcurrency import Vision

final class CustomMLModel: @unchecked Sendable {
    static let shared = CustomMLModel()

    private let inferenceQueue = DispatchQueue(
        label: "com.PhotoDex.ml.inference",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let modelLock = NSLock()

    private var yoloModel: VNCoreMLModel?
    private var mobileNetModel: VNCoreMLModel?
    private var lastLiveAnalysisTime: CFTimeInterval = 0
    private var liveAnalysisRate: LiveAnalysisRate = .ten

    private let maxSecondaryAnalyses = 3

    private init() {}

    func warmUp() async -> Bool {
        await withCheckedContinuation { continuation in
            inferenceQueue.async {
                do {
                    _ = try self.loadModels()
                    continuation.resume(returning: true)
                } catch {
                    AppLogger.analysis.error("ML warm up failed - \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func analyzePhoto(_ image: UIImage, includePose: Bool = true) async throws -> ImageAnalysisResult {
        let models = try await modelsAsync()

        async let predictions = enrichedPredictions(for: image, yoloModel: models.yolo, mobileNetModel: models.mobileNet)
        async let posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = includePose
            ? PoseDetectionManager.shared.detectPose(in: image)
            : [:]

        return ImageAnalysisResult(predictions: try await predictions, posePoints: await posePoints)
    }

    func analyzeLiveFrame(
        sampleBuffer: CMSampleBuffer,
        detectObjects: Bool,
        detectPose: Bool
    ) async throws -> ImageAnalysisResult? {
        guard detectObjects || detectPose else {
            return nil
        }

        guard shouldAnalyzeLiveFrame(at: CACurrentMediaTime()) else {
            return nil
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let models = try await modelsAsync()

        async let predictions: [Prediction] = detectObjects
            ? livePredictions(pixelBuffer: pixelBuffer, model: models.yolo)
            : []
        async let posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = detectPose
            ? PoseDetectionManager.shared.detectPose(sampleBuffer: sampleBuffer, orientation: .right)
            : [:]

        return ImageAnalysisResult(predictions: try await predictions, posePoints: await posePoints)
    }

    func updateLiveAnalysisRate(_ rate: LiveAnalysisRate) {
        modelLock.lock()
        defer { modelLock.unlock() }
        liveAnalysisRate = rate
        lastLiveAnalysisTime = 0
    }

    private func modelsAsync() async throws -> (yolo: VNCoreMLModel, mobileNet: VNCoreMLModel) {
        try await withCheckedThrowingContinuation { continuation in
            inferenceQueue.async {
                do {
                    continuation.resume(returning: try self.loadModels())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadModels() throws -> (yolo: VNCoreMLModel, mobileNet: VNCoreMLModel) {
        modelLock.lock()
        defer { modelLock.unlock() }

        if let yoloModel, let mobileNetModel {
            return (yoloModel, mobileNetModel)
        }

        let yoloModel = try YoloCoreML.createYOLOModel()
        let mobileNetModel = try MobileNetV2CoreML.createMobileNetModel()
        self.yoloModel = yoloModel
        self.mobileNetModel = mobileNetModel
        return (yoloModel, mobileNetModel)
    }

    private func enrichedPredictions(
        for image: UIImage,
        yoloModel: VNCoreMLModel,
        mobileNetModel: VNCoreMLModel
    ) async throws -> [Prediction] {
        let basePredictions = try await withCheckedThrowingContinuation { continuation in
            inferenceQueue.async {
                do {
                    continuation.resume(returning: try YoloCoreML.makePredictionsUsingYOLO(for: image, model: yoloModel))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard !basePredictions.isEmpty else {
            return []
        }

        let predictionsToEnhance = basePredictions
            .filter { $0.boundingBox != nil }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxSecondaryAnalyses)
        let selectedIDs = Set(predictionsToEnhance.map(\.id))
        var enhancedPredictions: [UUID: Prediction] = [:]

        await withTaskGroup(of: Prediction?.self) { group in
            for prediction in basePredictions where selectedIDs.contains(prediction.id) {
                group.addTask {
                    await self.enhance(prediction: prediction, in: image, mobileNetModel: mobileNetModel)
                }
            }

            for await prediction in group {
                if let prediction {
                    enhancedPredictions[prediction.id] = prediction
                }
            }
        }

        return basePredictions.map { enhancedPredictions[$0.id] ?? $0 }
    }

    private func livePredictions(
        pixelBuffer: CVPixelBuffer,
        model: VNCoreMLModel
    ) async throws -> [Prediction] {
        try await withCheckedThrowingContinuation { continuation in
            inferenceQueue.async {
                do {
                    let predictions = try YoloCoreML.makePredictionsUsingYOLO(
                        pixelBuffer: pixelBuffer,
                        orientation: .right,
                        model: model
                    )
                    continuation.resume(returning: predictions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func enhance(
        prediction: Prediction,
        in image: UIImage,
        mobileNetModel: VNCoreMLModel
    ) async -> Prediction? {
        guard
            let boundingBox = prediction.boundingBox,
            prediction.confidence >= 0.35,
            prediction.label != "person"
        else {
            return prediction
        }

        let crop = cropImage(image: image, boundingBox: boundingBox, padding: 48).scaled(maxDimension: 256)
        return await withCheckedContinuation { continuation in
            inferenceQueue.async {
                var updatedPrediction = prediction
                do {
                    let mobileNetPrediction = try MobileNetV2CoreML.makePredictionMobileNetV2(for: crop, model: mobileNetModel)
                    updatedPrediction.label = mobileNetPrediction.label
                    updatedPrediction.confidence = mobileNetPrediction.confidence
                } catch {
                    AppLogger.analysis.error("MobileNet prediction failed - \(error.localizedDescription)")
                }
                continuation.resume(returning: updatedPrediction)
            }
        }
    }

    private func shouldAnalyzeLiveFrame(at time: CFTimeInterval) -> Bool {
        modelLock.lock()
        defer { modelLock.unlock() }

        guard time - lastLiveAnalysisTime >= liveAnalysisRate.interval else {
            return false
        }

        lastLiveAnalysisTime = time
        return true
    }

    private func cropImage(image: UIImage, boundingBox: CGRect, padding: CGFloat) -> UIImage {
        guard let cgImage = image.fixedOrientation()?.cgImage ?? image.cgImage else {
            return image
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let x = max((boundingBox.origin.x * width) - padding, 0)
        let y = max(((1 - boundingBox.maxY) * height) - padding, 0)
        let cropWidth = min((boundingBox.width * width) + (padding * 2), width - x)
        let cropHeight = min((boundingBox.height * height) + (padding * 2), height - y)
        let cropRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight).integral

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCGImage)
    }
}
