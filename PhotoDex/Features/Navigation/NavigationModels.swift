//
//  NavigationModels.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import Foundation

/// A single depth-map zone reading — one cell of the 3 × 2 grid.
struct ZoneReading {
    let distance: Float     // metres, 5th-percentile robust minimum within the cell
    let col: Int            // 0 = left, 1 = center, 2 = right
    let row: Int            // 0 = upper, 1 = lower
}

/// The horizontal direction offering the most clearance for safe walking.
/// The guide tone is spatially positioned in this direction so the user
/// can simply walk toward the sound.
enum ClearDirection: Equatable {
    case left, center, right, none

    /// Stereo pan in [-1, 1] used as a fallback for non-spatial headphones.
    var pan: Float {
        switch self {
        case .left:   return -0.85
        case .center: return  0.0
        case .right:  return  0.85
        case .none:   return  0.0
        }
    }

    /// 3-D position (X, Y, Z in metres) for the virtual guide-tone source.
    /// Negative Z = in front of the listener; AirPods HRTF will render this
    /// as coming from the corresponding direction in world space.
    var position3D: (x: Float, y: Float, z: Float) {
        switch self {
        case .left:   return (-1.5,  0, -2)
        case .center: return ( 0.0,  0, -2)
        case .right:  return ( 1.5,  0, -2)
        case .none:   return ( 0.0,  0, -2)
        }
    }

    var localizedName: String {
        let isRO = Locale.preferredLanguages.first?.hasPrefix("ro") == true
        switch self {
        case .left:   return isRO ? "stânga"  : "left"
        case .center: return isRO ? "înainte" : "ahead"
        case .right:  return isRO ? "dreapta" : "right"
        case .none:   return isRO ? "blocat"  : "blocked"
        }
    }
}

/// Zone-level depth snapshot produced once per processed AR frame (≈12 Hz).
struct ObstacleSnapshot {
    let timestamp: TimeInterval
    /// [row][col] — row 0 = upper, row 1 = lower; col 0/1/2 = left/center/right.
    let cells: [[ZoneReading]]

    var lowerLeft:   ZoneReading? { cell(row: 1, col: 0) }
    var lowerCenter: ZoneReading? { cell(row: 1, col: 1) }
    var lowerRight:  ZoneReading? { cell(row: 1, col: 2) }

    /// Nearest obstacle anywhere in the snapshot.
    var nearest: ZoneReading? {
        cells.flatMap { $0 }.filter { $0.distance.isFinite }.min { $0.distance < $1.distance }
    }

    /// Direction with the maximum clearance in the lower (walking-path) row.
    /// Returns .none when all lower zones are within 0.5 m.
    var clearDirection: ClearDirection {
        let candidates: [(ClearDirection, Float)] = [
            (.left,   lowerLeft?.finiteDistance   ?? 0),
            (.center, lowerCenter?.finiteDistance ?? 0),
            (.right,  lowerRight?.finiteDistance  ?? 0),
        ]
        guard let best = candidates.max(by: { $0.1 < $1.1 }), best.1 >= 0.5 else {
            return .none
        }
        return best.0
    }

    /// Clearance distance (metres) in the recommended direction.
    var clearDistance: Float {
        switch clearDirection {
        case .left:   return lowerLeft?.finiteDistance   ?? 0
        case .center: return lowerCenter?.finiteDistance ?? 0
        case .right:  return lowerRight?.finiteDistance  ?? 0
        case .none:   return 0
        }
    }

    private func cell(row: Int, col: Int) -> ZoneReading? {
        guard cells.indices.contains(row), cells[row].indices.contains(col) else { return nil }
        return cells[row][col]
    }
}

private extension ZoneReading {
    var finiteDistance: Float { distance.isFinite ? distance : 0 }
}

/// Discrete navigation events forwarded to haptic transients and DangerAnnouncer.
enum NavigationEvent {
    case stepUp       // curb / stair riser detected ahead
    case stepDown     // dropoff detected ahead
    case doorAhead    // ARMeshAnchor door classification within 2 m
    case allBlocked   // all lower zones < 0.5 m simultaneously
}

/// A navigation-relevant object detected by YOLO in the AR camera frame,
/// enriched with a distance estimate from the co-located LiDAR depth grid.
struct NavigationObjectAlert {
    let label: String
    let confidence: Float
    /// Horizontal direction derived from the YOLO bounding-box centre X.
    let direction: ClearDirection
    /// Metres from the corresponding LiDAR depth zone (lower row).
    /// nil when the zone reading is unavailable or out of sensor range.
    let estimatedDistance: Float?
    /// Vision-normalised bounding box — needed by PathAwareFilter for corridor classification.
    let boundingBox: CGRect
}

/// Simplified ARKit tracking state for SwiftUI display — avoids importing ARKit in the ViewModel.
enum NavigationTrackingState {
    case initializing
    case normal
    case limitedExcessiveMotion
    case limitedInsufficientFeatures
    case notAvailable
}

/// UserDefaults keys for navigation-mode feature toggles.
enum NavPreferenceKeys {
    static let stepsDetection = "nav.stepsDetectionEnabled"
    static let yoloDetection  = "nav.yoloDetectionEnabled"
    static let verbosityLevel = "nav.verbosityLevel"
}

/// How many YOLO obstacles get announced via TTS. Stored as `Int` rawValue in UserDefaults.
enum NavVerbosityLevel: Int, CaseIterable, Identifiable {
    case minimal  = 0   // guide tone + haptics; TTS only for < 1 m in-path obstacles
    case balanced = 1   // default: path-blocking obstacles with adaptive cooldown
    case detailed = 2   // balanced + adjacent obstacles with exact distances

    var id: Int { rawValue }

    var localizedTitle: String {
        let isRO = Locale.preferredLanguages.first?.hasPrefix("ro") == true
        switch self {
        case .minimal:  return isRO ? "Minimal"   : "Minimal"
        case .balanced: return isRO ? "Echilibrat" : "Balanced"
        case .detailed: return isRO ? "Detaliat"   : "Detailed"
        }
    }

    var localizedDescription: String {
        let isRO = Locale.preferredLanguages.first?.hasPrefix("ro") == true
        switch self {
        case .minimal:
            return isRO
                ? "Ton ghidaj + haptic. TTS doar pentru obstacole < 1 m în cale."
                : "Guide tone + haptics only. TTS fires for < 1 m in-path obstacles."
        case .balanced:
            return isRO
                ? "Anunță obstacolele din cale. Setare implicită."
                : "Announces path-blocking obstacles. Default."
        case .detailed:
            return isRO
                ? "Include și obstacolele adiacente cu distanța exactă."
                : "Also announces adjacent obstacles with exact distances."
        }
    }
}

enum NavigationError: LocalizedError {
    case lidarNotAvailable
    case sessionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .lidarNotAvailable:
            return Locale.preferredLanguages.first?.hasPrefix("ro") == true
                ? "LiDAR nu este disponibil pe acest dispozitiv. Modul Navigare necesită iPhone Pro cu LiDAR."
                : "LiDAR is not available on this device. Navigation Mode requires an iPhone Pro with LiDAR."
        case .sessionFailed(let e):
            return "AR session failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - VFH Path Planning Structures (Phase 1 — PAD-Lite)

/// Top-down binary occupancy grid projected from the LiDAR depth map.
/// 40 × 40 cells at 15 cm each covers a 6 m × 6 m area; the user occupies the centre cell.
struct BEVGrid {
    static let gridSize:  Int   = 40
    static let cellSize:  Float = 0.15   // metres per cell
    static let maxRange:  Float = 5.0    // ignore depth readings beyond 5 m
    static let minHeight: Float = 0.15   // ignore points below shin/curb height
    static let maxHeight: Float = 2.0    // ignore ceiling-level points

    /// [row (z)][col (x)], true = occupied. User at (gridSize/2, gridSize/2).
    var cells: [[Bool]]

    static var empty: BEVGrid {
        BEVGrid(cells: Array(repeating: Array(repeating: false, count: gridSize), count: gridSize))
    }
}

/// 1-D polar obstacle density histogram — 36 sectors of 10° each, covering 360°.
struct PolarHistogram {
    static let sectorCount: Int   = 36
    static let sectorAngle: Float = 2 * Float.pi / Float(sectorCount)   // ≈ 0.1745 rad

    /// Weighted obstacle density per sector. Values above ~0.35 are treated as blocked.
    var densities: [Float]
}

/// A contiguous run of free sectors in the binary polar histogram — a candidate walking corridor.
struct CandidateValley {
    let startSector: Int
    let endSector:   Int
    let centerAngle: Float   // radians; 0 = straight ahead, positive = clockwise (right)
    let width:       Int     // number of consecutive free sectors
    let clearance:   Float   // estimated free distance in metres
}

/// VFH+ path planner output: a continuous steering angle with confidence and clearance.
struct SteeringResult {
    let angle:       Float          // radians; 0 = forward, positive = right
    let clearance:   Float          // metres of free space in the chosen steering direction
    let confidence:  Float          // 0..1; proportion of the polar histogram that is free here
    let direction:   ClearDirection // backward-compatible discrete direction for existing engines
    let valleyCount: Int            // candidate valleys found; 0 = all sectors blocked
}

/// A YOLO detection enriched by PathAwareFilter with VFH spatial context.
/// Produced by `PathAwareFilter.filter(alerts:steering:)` and consumed by
/// `DangerAnnouncer.processPathAwareDetection(_:)`.
struct DepthValidatedDetection {
    let prediction:       Prediction
    let pathRelation:     PathRelation
    let realDistance:     Float
    let side:             HazardSide
    let isInSteeringPath: Bool
    let threatScore:      Double
}
