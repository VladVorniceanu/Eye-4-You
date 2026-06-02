//
//  SpatialAudioEngine.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import AVFoundation
import Foundation

/// Plays a spatially positioned guide tone that steers the user toward the VFH+
/// computed safe walking direction. The user follows the sound to navigate safely.
///
/// Uses AVAudioEnvironmentNode with HRTF rendering. AirPods with Spatial Audio
/// automatically apply head-tracked binaural positioning at the system level —
/// no manual head-tracking integration is required.
///
/// Sound semantics:
///   • Position encodes WHERE to go — continuous angle from VFH+ (sweeps smoothly,
///     not snapping between left/center/right like the old discrete system).
///   • Ping interval encodes HOW CLEAR that path is (slower = more open).
///   • Pitch encodes URGENCY (880 Hz = relaxed, 660 Hz = caution, 330 Hz = alarm).
///
/// Thread-safe: setMuted / update may be called from different threads.
final class SpatialAudioEngine {

    private let engine      = AVAudioEngine()
    private let player      = AVAudioPlayerNode()
    private let environment = AVAudioEnvironmentNode()

    // Pre-rendered mono chime buffers: guide / caution / alarm
    private let guideBuffer:  AVAudioPCMBuffer
    private let cautionBuffer: AVAudioPCMBuffer
    private let alarmBuffer:  AVAudioPCMBuffer

    private var lastPingTime: CFTimeInterval = 0

    private let lock = NSLock()
    private var _isMuted = false

    // MARK: - Init

    init() throws {
        guard
            let g = Self.makeChime(freq: 880, duration: 0.14),
            let c = Self.makeChime(freq: 660, duration: 0.10),
            let a = Self.makeChime(freq: 330, duration: 0.08)
        else { throw AudioEngineError.bufferCreationFailed }
        guideBuffer   = g
        cautionBuffer = c
        alarmBuffer   = a

        // Audio graph: player → environment → mainMixerNode
        engine.attach(player)
        engine.attach(environment)
        engine.connect(player, to: environment, format: guideBuffer.format)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        // Listener at origin, facing -Z (forward)
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: 0, y: 0, z: -1),
            up:      AVAudio3DVector(x: 0, y: 1, z:  0)
        )

        // HRTF rendering — AirPods Spatial Audio enhances this automatically
        player.renderingAlgorithm = .HRTF

        // .allowAirPlay is only valid for .playAndRecord — .playback already
        // routes to AirPods; no extra option is needed for spatial audio.
        try AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .default,
            options: [.duckOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        try engine.start()
    }

    // MARK: - Per-frame update

    /// Called once per processed AR frame with the VFH+ steering result.
    /// Repositions the virtual sound source at a continuous angle and fires
    /// a guide ping when the cooldown interval has elapsed.
    func update(steering: SteeringResult) {
        lock.lock()
        let muted = _isMuted
        lock.unlock()
        guard !muted else { return }

        // Continuous angle positioning — sound source sweeps smoothly instead of
        // snapping between three discrete positions
        let pos = position3D(from: steering.angle)
        player.position = AVAudio3DPoint(x: pos.x, y: pos.y, z: pos.z)

        let blocked  = steering.direction == .none
        let interval = pingInterval(clearance: steering.clearance, blocked: blocked)
        guard interval.isFinite else { return }

        let now = CACurrentMediaTime()
        guard now - lastPingTime >= interval else { return }
        lastPingTime = now

        let buffer: AVAudioPCMBuffer = {
            if blocked                    { return alarmBuffer   }
            if steering.clearance < 1.0   { return cautionBuffer }
            return guideBuffer
        }()

        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    // MARK: - Muting (called from DangerAnnouncer while TTS speaks)

    func setMuted(_ muted: Bool) {
        lock.lock()
        _isMuted = muted
        lock.unlock()
        if muted { player.stop() }
    }

    // MARK: - Lifecycle

    func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }

    // MARK: - Private helpers

    /// Places the virtual sound source on a circle of radius 2 m around the listener.
    /// angle = 0 → straight ahead (−Z), positive angle → clockwise (right).
    private func position3D(from angle: Float) -> (x: Float, y: Float, z: Float) {
        let radius: Float = 2.0
        return (
            x:  radius * sin(angle),
            y:  0,
            z: -radius * cos(angle)   // −Z = forward in AVAudioEnvironmentNode space
        )
    }

    /// Interval between guide pings based on VFH+ clearance distance.
    /// Shorter interval = more urgent. `.infinity` = silent (wide-open path).
    private func pingInterval(clearance: Float, blocked: Bool) -> Double {
        if blocked { return 0.20 }          // all sectors blocked: rapid alarm pings
        switch clearance {
        case 3.5...:      return .infinity  // clear corridor — silence, no nudge needed
        case 2.5..<3.5:   return 1.5
        case 1.5..<2.5:   return 1.0
        case 1.0..<1.5:   return 0.6
        case 0.5..<1.0:   return 0.35
        default:          return 0.20       // very short clearance in best direction
        }
    }

    /// Pre-renders a mono sine-wave chime with a fast attack and exponential decay.
    private static func makeChime(freq: Float, duration: Float) -> AVAudioPCMBuffer? {
        let sr: Float = 44_100
        let count = AVAudioFrameCount(sr * duration)
        guard
            let fmt = AVAudioFormat(standardFormatWithSampleRate: Double(sr), channels: 1),
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: count),
            let ptr = buf.floatChannelData?[0]
        else { return nil }

        buf.frameLength = count
        for i in 0..<Int(count) {
            let t        = Float(i) / sr
            let attack   = min(1, t / 0.004)            // 4 ms linear ramp-up
            let decay    = exp(-15 * max(0, t - 0.004)) // fast exponential release
            ptr[i] = sin(2 * .pi * freq * t) * attack * decay * 0.40
        }
        return buf
    }

    enum AudioEngineError: Error {
        case bufferCreationFailed
    }
}
