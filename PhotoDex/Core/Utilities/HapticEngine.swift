//
//  HapticEngine.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import UIKit

// Haptic feedback for obstacle warnings — two modes:
//
// One-shot alert (warn): fires once per TTS announcement.
//   heavy  = immediate + inPath
//   medium = near + inPath
//   light  = adjacent (any proximity)
//
// Continuous pulse (updateContinuousFeedback): loops while the top hazard holds,
// rate tied to proximity (0.5 / 0.8 / 1.5 s), stops automatically when no hazard.
// Direction is encoded by pulse count — iPhone has a single Taptic Engine so
// true left/right is not possible; pulse count is the closest available encoding:
//   1 pulse  = obstacle on the left
//   2 pulses = obstacle ahead / center
//   3 pulses = obstacle on the right
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let light  = UIImpactFeedbackGenerator(style: .light)

    private var pulseTask: Task<Void, Never>?
    private var currentProximity: Proximity?
    private var currentSide: HazardSide?

    private var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: AppSettingsKeys.hapticsEnabled) as? Bool) ?? true
    }

    private init() {
        heavy.prepare()
        medium.prepare()
        light.prepare()
    }

    // One-shot alert fired at the moment of TTS announcement.
    func warn(proximity: Proximity, inPath: Bool) {
        guard isEnabled else { return }
        switch (proximity, inPath) {
        case (.immediate, true):  heavy.impactOccurred()
        case (.near, true):       medium.impactOccurred()
        case (_, true):           break
        case (_, false):          light.impactOccurred()
        }
    }

    // Called every frame from DangerAnnouncer.process() with the top scored hazard.
    // Starts or updates the continuous pulse loop; pass nil to stop.
    func updateContinuousFeedback(for hazard: ScoredHazard?) {
        guard isEnabled, let hazard, hazard.proximity != .far else {
            stopPulsing()
            return
        }
        let prox = hazard.proximity
        let side = hazard.side
        // Avoid restarting the loop if nothing relevant changed.
        if currentProximity == prox && currentSide == side { return }
        startPulsing(proximity: prox, side: side)
    }

    func stopPulsing() {
        pulseTask?.cancel()
        pulseTask = nil
        currentProximity = nil
        currentSide = nil
    }

    private func startPulsing(proximity: Proximity, side: HazardSide) {
        pulseTask?.cancel()
        currentProximity = proximity
        currentSide = side

        pulseTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fireDirectionalPulse(proximity: proximity, side: side)
                let ns = UInt64(self.pulseInterval(for: proximity) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    // Fires 1 / 2 / 3 pulses for left / center / right.
    // Sub-pulse gap (100 ms) is short enough to read as a group,
    // long enough to feel as distinct taps.
    private func fireDirectionalPulse(proximity: Proximity, side: HazardSide) async {
        let generator = proximity == .immediate ? medium : light
        let subGap: UInt64 = 100_000_000  // 100 ms

        generator.impactOccurred()

        switch side {
        case .left:
            break
        case .center:
            try? await Task.sleep(nanoseconds: subGap)
            light.impactOccurred()
        case .right:
            try? await Task.sleep(nanoseconds: subGap)
            light.impactOccurred()
            try? await Task.sleep(nanoseconds: subGap)
            light.impactOccurred()
        }
    }

    // Time between pulse groups, in seconds.
    private func pulseInterval(for proximity: Proximity) -> Double {
        switch proximity {
        case .immediate: return 0.5
        case .near:      return 0.8
        case .mid:       return 1.5
        case .far:       return 0
        }
    }
}
