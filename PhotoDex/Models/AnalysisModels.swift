import CoreGraphics
import Foundation
import Vision

struct HumanAnalysisResult: Equatable, Hashable {
    let age: String
    let gender: String
    let emotion: String
}

struct Prediction: Equatable, Hashable, Identifiable {
    let id: UUID
    var label: String
    var confidence: VNConfidence
    var boundingBox: CGRect?
    var humanAnalysis: HumanAnalysisResult?

    init(
        id: UUID = UUID(),
        label: String,
        confidence: VNConfidence,
        boundingBox: CGRect?,
        humanAnalysis: HumanAnalysisResult? = nil
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.humanAnalysis = humanAnalysis
    }
}

struct ImageAnalysisResult: Equatable {
    var predictions: [Prediction]
    var posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
}

struct FocusIndicatorState: Equatable {
    var point: CGPoint
    var isVisible: Bool
}
