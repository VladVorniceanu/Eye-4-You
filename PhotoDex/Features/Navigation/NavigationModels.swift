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

/// Simplified ARKit tracking state for SwiftUI display — avoids importing ARKit in the ViewModel.
enum NavigationTrackingState {
    case initializing
    case normal
    case limitedExcessiveMotion
    case limitedInsufficientFeatures
    case notAvailable
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
