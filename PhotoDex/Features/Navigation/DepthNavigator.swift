//
//  DepthNavigator.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import ARKit
import AVFoundation
import Foundation
import UIKit

/// Singleton facade that owns the ARSession and drives the full navigation
/// pipeline: depth processing → haptics → spatial audio → callbacks.
///
/// Threading:
///   • `start()` / `stop()` / `setAudioEnabled()` / `setGuidanceActive()` / `setDebugEnabled()`
///     may be called from any context.
///   • `onSnapshot`, `onEvent`, `onHeatmap`, and `onTrackingStateChange` are always
///     delivered on @MainActor.
///   • All frame processing and engine updates happen on the private serial queue.
final class DepthNavigator: NSObject {

    static let shared = DepthNavigator()

    /// Delivered on @MainActor at up to `processingHz` per second.
    var onSnapshot: ((ObstacleSnapshot) -> Void)?
    /// Delivered on @MainActor for discrete events (step, door, blocked).
    var onEvent: ((NavigationEvent) -> Void)?
    /// Delivered on @MainActor at ≈8 Hz when debug mode is enabled.
    var onHeatmap: ((UIImage) -> Void)?
    /// Delivered on @MainActor whenever ARKit tracking state changes.
    var onTrackingStateChange: ((NavigationTrackingState) -> Void)?

    // MARK: - Public state (thread-safe via lock)

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }; return _isRunning
    }

    var processingHz: Int {
        get { lock.lock(); defer { lock.unlock() }; return _processingHz }
        set { lock.lock(); defer { lock.unlock() }; _processingHz = max(1, min(30, newValue)) }
    }

    /// Enables or disables the full guidance pipeline (haptics / audio / events).
    /// When false the session still runs — depth data feeds the heatmap and snapshot
    /// callbacks, but no haptics or spatial audio are produced.
    func setGuidanceActive(_ active: Bool) {
        lock.lock(); _isGuidanceActive = active; lock.unlock()
    }

    /// Enables or disables real-time heatmap rendering (≈8 Hz), independent of guidance.
    func setDebugEnabled(_ enabled: Bool) {
        lock.lock(); _debugEnabled = enabled; lock.unlock()
    }

    // MARK: - Private

    private let session         = ARSession()
    private let queue           = DispatchQueue(label: "com.PhotoDex.navigation.depth", qos: .userInitiated)
    private let processor       = DepthFrameProcessor()
    private let heatmapRenderer = DepthHeatmapRenderer()

    private let lock = NSLock()
    private var _isRunning        = false
    private var _isGuidanceActive = false
    private var _debugEnabled     = false
    private var _processingHz     = 12
    private var _hapticsEngine:   RadarHapticsEngine?
    private var _audioEngine:     SpatialAudioEngine?

    // All accessed only on `queue` — no lock needed
    private var lastProcessed:       CFTimeInterval = 0
    private var lastAllBlockedFired: CFTimeInterval = 0
    private var lastHeatmapTime:     CFTimeInterval = 0
    private var lastYaw:             Float          = .nan  // NaN = not yet initialized

    private override init() {
        super.init()
        session.delegateQueue = queue
        session.delegate = self
    }

    // MARK: - Lifecycle

    func start() throws {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) else {
            throw NavigationError.lidarNotAvailable
        }

        let haptics = try RadarHapticsEngine()
        let audio   = try SpatialAudioEngine()

        lock.lock()
        _hapticsEngine = haptics
        _audioEngine   = audio
        _isRunning     = true
        lock.unlock()

        session.run(makeARConfig(), options: [.resetTracking, .removeExistingAnchors])
        AppLogger.navigation.info("Navigation session started")
    }

    func stop() {
        session.pause()

        lock.lock()
        _isRunning        = false
        _isGuidanceActive = false
        _debugEnabled     = false
        let h = _hapticsEngine
        let a = _audioEngine
        _hapticsEngine = nil
        _audioEngine   = nil
        lock.unlock()

        // Reset per-frame state for the next session
        lastYaw              = .nan
        lastProcessed        = 0
        lastAllBlockedFired  = 0
        lastHeatmapTime      = 0

        h?.stop()
        a?.stop()
        AppLogger.navigation.info("Navigation session stopped")
    }

    func setAudioEnabled(_ enabled: Bool) {
        lock.lock()
        let a = _audioEngine
        lock.unlock()
        a?.setMuted(!enabled)
    }

    // MARK: - ARWorldTrackingConfiguration

    private func makeARConfig() -> ARWorldTrackingConfiguration {
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal, .vertical]

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            cfg.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            cfg.frameSemantics.insert(.sceneDepth)
        }

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            cfg.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            cfg.sceneReconstruction = .mesh
        }

        cfg.environmentTexturing     = .none
        cfg.isLightEstimationEnabled = false
        return cfg
    }
}

// MARK: - ARSessionDelegate

extension DepthNavigator: ARSessionDelegate {

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = NavigationTrackingState(camera.trackingState)
        Task { @MainActor [weak self] in self?.onTrackingStateChange?(state) }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Running on self.queue (delegateQueue = queue)
        let now = CACurrentMediaTime()
        lock.lock()
        let hz             = _processingHz
        let running        = _isRunning
        let guidanceActive = _isGuidanceActive
        let debugEnabled   = _debugEnabled
        lock.unlock()
        guard running else { return }

        // --- Motion guard ---
        // Fast lateral sweeps contaminate the depth map with motion-blur artifacts,
        // producing false "close obstacle" readings.  Two checks:
        //   1. ARKit's own excessive-motion flag (coarse, but authoritative).
        //   2. Per-frame yaw-rate limit: skip frames where the camera rotated
        //      more than π/8 (22.5°) since the previous delivered frame.
        let currentYaw = frame.camera.eulerAngles.y
        if case .limited(let reason) = frame.camera.trackingState, reason == .excessiveMotion {
            lastYaw = currentYaw
            return
        }
        if !lastYaw.isNaN {
            let delta = abs(currentYaw - lastYaw)
            let wrapped = min(delta, .pi * 2 - delta)   // handle ±π wraparound
            if wrapped > .pi / 8 {
                lastYaw = currentYaw
                return
            }
        }
        lastYaw = currentYaw

        // --- Processing throttle ---
        let minInterval = 1.0 / Double(hz)
        guard now - lastProcessed >= minInterval else {
            // Still render heatmap at ≈8 Hz even during throttle windows
            if debugEnabled, now - lastHeatmapTime >= 1.0 / 8.0,
               let img = heatmapRenderer.render(frame: frame) {
                lastHeatmapTime = now
                Task { @MainActor [weak self] in self?.onHeatmap?(img) }
            }
            return
        }
        lastProcessed = now

        guard let snapshot = processor.process(frame: frame) else { return }

        lock.lock()
        let haptics = _hapticsEngine
        let audio   = _audioEngine
        lock.unlock()

        // Deliver snapshot to ViewModel (always — used by heatmap zone overlay too)
        Task { @MainActor [weak self] in self?.onSnapshot?(snapshot) }

        // Heatmap at ≈8 Hz (independent of guidance state)
        if debugEnabled, now - lastHeatmapTime >= 1.0 / 8.0,
           let img = heatmapRenderer.render(frame: frame) {
            lastHeatmapTime = now
            Task { @MainActor [weak self] in self?.onHeatmap?(img) }
        }

        // --- Guidance pipeline (suppressed during calibration scan) ---
        guard guidanceActive else { return }

        // Continuous haptic intensity
        haptics?.update(nearest: snapshot.nearest?.distance ?? .infinity)

        // Spatial audio guide tone
        audio?.update(snapshot: snapshot)

        // Stair / dropoff heuristic
        let pitch = frame.camera.eulerAngles.x
        if let event = processor.detectStep(snapshot: snapshot, cameraPitch: pitch) {
            haptics?.fireTransient(for: event)
            Task { @MainActor [weak self] in self?.onEvent?(event) }
        }

        // All-blocked: rate-limited to one event per 3 s
        let lowers = [snapshot.lowerLeft, snapshot.lowerCenter, snapshot.lowerRight]
            .compactMap { $0?.distance }.filter(\.isFinite)
        if !lowers.isEmpty, lowers.allSatisfy({ $0 < 0.5 }),
           now - lastAllBlockedFired >= 3.0 {
            lastAllBlockedFired = now
            haptics?.fireTransient(for: .allBlocked)
            Task { @MainActor [weak self] in self?.onEvent?(.allBlocked) }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        AppLogger.navigation.error("AR session error: \(error.localizedDescription)")
        Task { @MainActor [weak self] in self?.onEvent?(.allBlocked) }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        AppLogger.navigation.info("AR session interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        AppLogger.navigation.info("AR session interruption ended — resuming")
        session.run(makeARConfig())
    }
}

// MARK: - RadarAudioGate conformance

extension DepthNavigator: RadarAudioGate {
    /// Called by DangerAnnouncer before / after TTS utterances.
    func setRadarMuted(_ muted: Bool) {
        setAudioEnabled(!muted)
        if !muted {
            try? AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default,
                options: [.duckOthers]
            )
        }
    }
}

// MARK: - NavigationTrackingState initializer (ARKit → model)

private extension NavigationTrackingState {
    init(_ state: ARCamera.TrackingState) {
        switch state {
        case .notAvailable:                        self = .notAvailable
        case .normal:                              self = .normal
        case .limited(.excessiveMotion):           self = .limitedExcessiveMotion
        case .limited(.insufficientFeatures):      self = .limitedInsufficientFeatures
        default:                                   self = .initializing
        }
    }
}
