//
//  DepthNavigator.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import ARKit
import AVFoundation
import Foundation

/// Singleton facade that owns the ARSession and drives the full navigation
/// pipeline: depth processing → haptics → spatial audio → callbacks.
///
/// Threading:
///   • `start()` / `stop()` / `setAudioEnabled()` may be called from any context.
///   • `onSnapshot` and `onEvent` closures are always delivered on @MainActor.
///   • All frame processing and engine updates happen on the private serial queue.
final class DepthNavigator: NSObject {

    static let shared = DepthNavigator()

    /// Delivered on @MainActor at up to `processingHz` per second.
    var onSnapshot: ((ObstacleSnapshot) -> Void)?
    /// Delivered on @MainActor for discrete events (step, door, blocked).
    var onEvent: ((NavigationEvent) -> Void)?

    // MARK: - Public state (thread-safe via lock)

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }; return _isRunning
    }

    var processingHz: Int {
        get { lock.lock(); defer { lock.unlock() }; return _processingHz }
        set { lock.lock(); defer { lock.unlock() }; _processingHz = max(1, min(30, newValue)) }
    }

    // MARK: - Private

    private let session   = ARSession()
    private let queue     = DispatchQueue(label: "com.PhotoDex.navigation.depth", qos: .userInitiated)
    private let processor = DepthFrameProcessor()

    private let lock = NSLock()
    private var _isRunning    = false
    private var _processingHz = 12
    private var _hapticsEngine: RadarHapticsEngine?
    private var _audioEngine:   SpatialAudioEngine?
    private var lastProcessed: CFTimeInterval = 0
    private var lastAllBlockedFired: CFTimeInterval = 0

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
        _isRunning = false
        let h = _hapticsEngine
        let a = _audioEngine
        _hapticsEngine = nil
        _audioEngine   = nil
        lock.unlock()

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

        cfg.environmentTexturing    = .none
        cfg.isLightEstimationEnabled = false
        return cfg
    }
}

// MARK: - ARSessionDelegate

extension DepthNavigator: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Running on self.queue (delegateQueue = queue)
        let now = CACurrentMediaTime()
        lock.lock()
        let hz      = _processingHz
        let running = _isRunning
        lock.unlock()
        guard running else { return }

        let minInterval = 1.0 / Double(hz)
        guard now - lastProcessed >= minInterval else { return }
        lastProcessed = now

        guard let snapshot = processor.process(frame: frame) else { return }

        lock.lock()
        let haptics = _hapticsEngine
        let audio   = _audioEngine
        lock.unlock()

        // --- Continuous haptic intensity (thread-safe CHHapticEngine call) ---
        haptics?.update(nearest: snapshot.nearest?.distance ?? .infinity)

        // --- Spatial audio guide tone ---
        audio?.update(snapshot: snapshot)

        // --- Stair / dropoff heuristic ---
        let pitch = frame.camera.eulerAngles.x
        if let event = processor.detectStep(snapshot: snapshot, cameraPitch: pitch) {
            haptics?.fireTransient(for: event)
            Task { @MainActor [weak self] in self?.onEvent?(event) }
        }

        // --- All-blocked: rate-limited to one event per 3 s ---
        let lowers = [snapshot.lowerLeft, snapshot.lowerCenter, snapshot.lowerRight]
            .compactMap { $0?.distance }.filter(\.isFinite)
        if !lowers.isEmpty, lowers.allSatisfy({ $0 < 0.5 }),
           now - lastAllBlockedFired >= 3.0 {
            lastAllBlockedFired = now
            haptics?.fireTransient(for: .allBlocked)
            Task { @MainActor [weak self] in self?.onEvent?(.allBlocked) }
        }

        // --- Deliver snapshot to ViewModel on main actor ---
        Task { @MainActor [weak self] in self?.onSnapshot?(snapshot) }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        AppLogger.navigation.error("AR session error: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.onEvent?(.allBlocked)
        }
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
    /// Mutes the spatial audio engine and, on unmute, restores the audio
    /// session to .default mode so HRTF rendering works correctly again.
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
