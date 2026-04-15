import CoreGraphics
import Foundation
import Vision

struct Prediction: Equatable, Hashable, Identifiable {
    let id: UUID
    var label: String
    var confidence: VNConfidence
    var boundingBox: CGRect?

    init(
        id: UUID = UUID(),
        label: String,
        confidence: VNConfidence,
        boundingBox: CGRect?
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
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

enum LiveAnalysisRate: Int, CaseIterable, Identifiable {
    case one = 1
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case twentyFive = 25
    case thirty = 30

    var id: Int { rawValue }

    var label: String {
        "\(rawValue)/s"
    }

    var interval: CFTimeInterval {
        1.0 / Double(rawValue)
    }
}
