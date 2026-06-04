//
//  PathAwareFilter.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/2/26.
//

import Foundation

/// Fuses VFH+ steering data with YOLO object alerts to implement the
/// DotLumen "guide, don't narrate" principle: TTS fires only when the
/// haptic/audio guidance channel cannot handle an obstacle on its own.
///
/// Implements the suppression rules from the Path-Aware Guidance spec §4.2:
///   • VFH already steering away + obstacle > 2 m          → silent
///   • Obstacle outside relevance zone                      → silent
///   • Peripheral + > 2 m                                  → silent
///   • Same label announced within 10 s at similar distance → silent
///   • Background non-hazard item not directly in path      → silent
///   • VFH high-confidence corridor + obstacle > 2 m        → silent
///
/// Not thread-safe: access only from @MainActor (DepthNavigatorViewModel).
final class PathAwareFilter {

    /// Per-label: time of last announcement + distance at that point.
    private var announced: [String: (time: Date, distance: Float)] = [:]

    /// Labels that represent genuine walking hazards. Objects outside this set
    /// are silenced unless they are directly in the centre of the walking corridor.
    private static let walkingHazardLabels: Set<String> = [
        "car", "truck", "bus", "motorcycle", "bicycle", "person",
        "traffic light", "stop sign", "fire hydrant",
        "bench", "chair", "dining table", "suitcase", "backpack",
        "umbrella", "handbag", "sports ball", "skateboard",
        "dog", "cat", "horse",
    ]

    // MARK: - Public API

    /// Accepts a batch of YOLO alerts from one inference cycle, applies all
    /// suppression rules, and returns the single highest-priority detection
    /// that should be announced — or an empty array when everything is suppressed.
    func filter(
        alerts:    [NavigationObjectAlert],
        steering:  SteeringResult,
        verbosity: NavVerbosityLevel = .balanced
    ) -> [DepthValidatedDetection] {
        let enriched    = alerts.map { enrich($0, steering: steering) }
        let inPathCount = enriched.filter { $0.pathRelation == .inPath }.count
        let cooldown    = effectiveCooldown(steering: steering, inPathCount: inPathCount)
        let filtered    = enriched.filter { shouldAnnounce($0, steering: steering, verbosity: verbosity, cooldown: cooldown) }
        let sorted = filtered.sorted { $0.threatScore > $1.threatScore }
        guard let top = sorted.first else {
            if !enriched.isEmpty { NavigationSessionLogger.shared.logTTSEvent(suppressed: true) }
            return []
        }
        NavigationSessionLogger.shared.logTTSEvent(suppressed: false)
        announced[top.prediction.label] = (time: Date(), distance: top.realDistance)
        return [top]
    }

    /// Dynamic cooldown: fewer obstacles on the path → longer silence between TTS.
    private func effectiveCooldown(steering: SteeringResult, inPathCount: Int) -> TimeInterval {
        if steering.direction == .none { return 1.5 }  // all blocked — rapid re-announcements
        switch inPathCount {
        case 0:     return 10.0   // wide open path — near-silent
        case 1:     return 5.0
        case 2...3: return 3.0
        default:    return 2.0   // crowded scene — more frequent updates
        }
    }

    /// Reset per-session state (call when a navigation session ends).
    func reset() { announced = [:] }

    // MARK: - Enrichment

    private func enrich(
        _ alert:   NavigationObjectAlert,
        steering:  SteeringResult
    ) -> DepthValidatedDetection {
        let bbox     = alert.boundingBox
        let relation = Corridor.default.classify(bbox)
        let side     = Corridor.default.side(for: bbox)
        let realDist = alert.estimatedDistance ?? 0

        // isInSteeringPath: the obstacle lies in the direction VFH is guiding the user toward
        let isInPath: Bool
        switch steering.direction {
        case .none:   isInPath = true   // all sectors blocked — every obstacle matters
        default:      isInPath = alert.direction == steering.direction
        }

        // Threat score: confidence × distance-factor × path-weight
        let pathFactor: Double
        switch relation {
        case .inPath:           pathFactor = 1.0
        case .adjacent:         pathFactor = 0.5
        case .peripheral:       pathFactor = 0.2
        case .outsideRelevance: pathFactor = 0.0
        }
        let distFactor  = realDist > 0
            ? max(0.0, 1.0 - Double(realDist) / Double(BEVGrid.maxRange))
            : 0.5   // no LiDAR reading — assume medium threat
        let threatScore = Double(alert.confidence) * distFactor * pathFactor

        return DepthValidatedDetection(
            prediction:       Prediction(label: alert.label, confidence: alert.confidence,
                                         boundingBox: bbox),
            pathRelation:     relation,
            realDistance:     realDist,
            side:             side,
            isInSteeringPath: isInPath,
            threatScore:      threatScore
        )
    }

    // MARK: - Suppression rules (§4.2)

    private func shouldAnnounce(
        _ d:       DepthValidatedDetection,
        steering:  SteeringResult,
        verbosity: NavVerbosityLevel,
        cooldown:  TimeInterval
    ) -> Bool {
        // Minimal: TTS only for immediate in-path obstacles (< 1 m)
        if verbosity == .minimal {
            return d.pathRelation == .inPath && d.realDistance < 1.0
        }

        // Not in the relevant walking zone at all
        if d.pathRelation == .outsideRelevance { return false }

        // VFH already steering away from this obstacle and it is far enough
        if !d.isInSteeringPath, d.realDistance > 2.0 { return false }

        // Peripheral and too far to matter right now
        if d.pathRelation == .peripheral, d.realDistance > 2.0 { return false }

        // Same obstacle already announced recently at a similar distance
        if isRedundant(d, cooldown: cooldown) { return false }

        // Background non-hazard item that is not directly blocking the corridor
        if !isNavigationRelevant(d.prediction.label), d.pathRelation != .inPath { return false }

        // VFH has found a wide clear valley and the obstacle is comfortably far
        if steering.confidence > 0.5, d.realDistance > 2.0 { return false }

        // Detailed: allow adjacent obstacles through (skip the default adjacent suppression)
        if verbosity == .detailed {
            return d.pathRelation == .inPath || d.pathRelation == .adjacent
        }

        return true
    }

    private func isRedundant(_ d: DepthValidatedDetection, cooldown: TimeInterval) -> Bool {
        guard let last = announced[d.prediction.label] else { return false }
        guard Date().timeIntervalSince(last.time) < cooldown else { return false }
        return abs(d.realDistance - last.distance) < 1.0  // same distance ±1 m
    }

    private func isNavigationRelevant(_ label: String) -> Bool {
        Self.walkingHazardLabels.contains(label)
    }
}
