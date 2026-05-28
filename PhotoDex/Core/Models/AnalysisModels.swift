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

// Discrete proximity bucket derived from the YOLO bounding-box height.
// Heights are normalized (0..1) — a tall bbox occupies more of the frame and
// therefore represents an object that is physically closer to the user.
enum Proximity {
    case immediate, near, mid, far

    static func from(_ bbox: CGRect) -> Proximity {
        switch bbox.height {
        case 0.6...:        return .immediate
        case 0.35..<0.6:    return .near
        case 0.18..<0.35:   return .mid
        default:            return .far
        }
    }
}

// Where an obstacle sits relative to the user's walking corridor.
// Drives both phrase composition and haptic strength downstream.
enum PathRelation {
    case inPath, adjacent, peripheral, outsideRelevance
}

// Horizontal side of the obstacle relative to the corridor heading.
enum HazardSide {
    case left, center, right
}

// Walking-corridor trapezoid in Vision-normalized coordinates (origin
// bottom-left, y increases upward). The base sits at the bottom of the frame
// (closest to the user's feet) and narrows toward `apexY` (roughly ~5 m out).
// Anything above the apex is "too far to matter right now".
struct Corridor {
    let baseY: CGFloat
    let apexY: CGFloat
    let baseHalfWidth: CGFloat
    let apexHalfWidth: CGFloat
    let centerX: CGFloat

    static let `default` = Corridor(
        baseY: 0.0,
        apexY: 0.6,
        baseHalfWidth: 0.25,
        apexHalfWidth: 0.075,
        centerX: 0.5
    )

    // `point` is the ground-contact estimate of an object — typically
    // (bbox.midX, bbox.minY) in Vision coords.
    func contains(_ point: CGPoint) -> Bool {
        guard point.y >= baseY, point.y <= apexY else { return false }
        return abs(point.x - centerX) <= halfWidth(atY: point.y)
    }

    // Distance from `point` to the nearest corridor wall along x, in
    // normalized units. Zero when the point is inside the corridor.
    func lateralDistance(to point: CGPoint) -> CGFloat {
        let clampedY = max(baseY, min(apexY, point.y))
        return max(0, abs(point.x - centerX) - halfWidth(atY: clampedY))
    }

    func classify(_ bbox: CGRect) -> PathRelation {
        let ground = CGPoint(x: bbox.midX, y: bbox.minY)
        if contains(ground) { return .inPath }
        if lateralDistance(to: ground) < 0.1 { return .adjacent }
        if bbox.minY < apexY { return .peripheral }
        return .outsideRelevance
    }

    func side(for bbox: CGRect) -> HazardSide {
        let dx = bbox.midX - centerX
        if dx < -0.05 { return .left }
        if dx > 0.05 { return .right }
        return .center
    }

    private func halfWidth(atY y: CGFloat) -> CGFloat {
        // t = 1 at the base (close to user, wide), 0 at the apex (far, narrow).
        let t = 1 - (y - baseY) / (apexY - baseY)
        return apexHalfWidth + t * (baseHalfWidth - apexHalfWidth)
    }
}

struct ScoredHazard {
    let prediction: Prediction
    let relation: PathRelation
    let proximity: Proximity
    let side: HazardSide
    let score: Double
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
