//
//  RadarHapticsEngine.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import CoreHaptics
import Foundation

/// Continuous Core Haptics player whose intensity and sharpness track the
/// nearest obstacle distance, plus one-shot transients for discrete events.
///
/// Thread-safe: all CHHapticEngine operations are safe to call from any queue.
final class RadarHapticsEngine {

    private let engine: CHHapticEngine
    private let continuousPlayer: CHHapticAdvancedPatternPlayer

    // MARK: - Init / deinit

    init() throws {
        engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = false
        try engine.start()

        // 30-second looping event; intensity/sharpness are overridden each frame.
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity,  value: 0.0),
                .init(parameterID: .hapticSharpness,  value: 0.5),
            ],
            relativeTime: 0,
            duration: 30
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
        continuousPlayer.loopEnabled = true
        try continuousPlayer.start(atTime: CHHapticTimeImmediate)

        engine.stoppedHandler = { [weak self] reason in
            AppLogger.navigation.warning("Haptic engine stopped: \(String(describing: reason))")
            try? self?.engine.start()
        }
        engine.resetHandler = { [weak self] in
            AppLogger.navigation.warning("Haptic engine reset — rebuilding")
            guard let self else { return }
            try? self.engine.start()
            try? self.continuousPlayer.start(atTime: CHHapticTimeImmediate)
        }
    }

    // MARK: - Per-frame update

    /// Call once per processed AR frame. `distance` is the nearest obstacle in metres.
    func update(nearest distance: Float) {
        let intensity: Float = {
            switch distance {
            case ..<0.5:    return 1.0
            case 0.5..<1.0: return 0.7
            case 1.0..<2.0: return 0.35
            case 2.0..<3.0: return 0.15
            default:        return 0.0
            }
        }()
        let sharpness = min(1, max(0, 1 - distance / 3.0))

        try? continuousPlayer.sendParameters([
            .init(parameterID: .hapticIntensityControl, value: intensity,  relativeTime: 0),
            .init(parameterID: .hapticSharpnessControl, value: sharpness,  relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    // MARK: - Discrete events

    func fireTransient(for event: NavigationEvent) {
        let (intensity, sharpness, count): (Float, Float, Int) = {
            switch event {
            case .stepUp:     return (1.0, 0.9, 2)
            case .stepDown:   return (1.0, 0.4, 3)
            case .doorAhead:  return (0.8, 0.7, 1)
            case .allBlocked: return (1.0, 0.3, 4)
            }
        }()

        let events = (0..<count).map { i in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity,  value: intensity),
                    .init(parameterID: .hapticSharpness,  value: sharpness),
                ],
                relativeTime: Double(i) * 0.12
            )
        }

        guard
            let pattern = try? CHHapticPattern(events: events, parameters: []),
            let player  = try? engine.makePlayer(with: pattern)
        else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    // MARK: - Lifecycle

    func stop() {
        try? continuousPlayer.stop(atTime: CHHapticTimeImmediate)
        engine.stop()
    }
}
