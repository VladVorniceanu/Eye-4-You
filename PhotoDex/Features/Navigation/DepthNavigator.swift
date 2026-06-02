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
    /// Delivered on @MainActor for each navigation-relevant YOLO detection (≈3 Hz, per-label cooldown in ViewModel).
    var onObjectAlert: ((NavigationObjectAlert) -> Void)?
    /// Delivered on @MainActor with the full batch of navigation-relevant alerts from one YOLO cycle.
    /// Used by PathAwareFilter for batch suppression — fires after all individual onObjectAlert calls.
    var onObjectAlerts: (([NavigationObjectAlert]) -> Void)?
    /// Delivered on @MainActor with ALL raw YOLO predictions for the debug overlay (no label filter).
    var onDetections: (([Prediction]) -> Void)?
    /// Delivered on @MainActor when movement direction or stationarity changes.
    /// direction = predominant walking direction; stationary = speed < 0.05 m/s for ≥0.3 s.
    var onTrajectoryUpdate: ((ClearDirection, Bool) -> Void)?
    /// Delivered on @MainActor with the VFH+ steering result at processingHz.
    var onSteering: ((SteeringResult) -> Void)?

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
    private let pathPlanner     = PathPlanner()

    private let lock = NSLock()
    private var _isRunning        = false
    private var _isGuidanceActive = false
    private var _debugEnabled     = false
    private var _processingHz     = 12
    private var _hapticsEngine:   RadarHapticsEngine?
    private var _audioEngine:     SpatialAudioEngine?

    // All accessed only on `queue` — no lock needed
    private var lastProcessed:          CFTimeInterval = 0
    private var lastAllBlockedFired:    CFTimeInterval = 0
    private var lastHeatmapTime:        CFTimeInterval = 0
    private var lastYoloTime:           CFTimeInterval = 0
    private var lastYaw:                Float          = .nan  // NaN = not yet initialized
    private var vfhLowConfidenceFrames: Int            = 0

    // Motion tracking — position ring buffer for trajectory + stop detection
    private struct PosSample { let time: CFTimeInterval; let position: SIMD3<Float> }
    private var posHistory: [PosSample] = []
    private var lastPublishedTrajectory: (direction: ClearDirection, stationary: Bool)?
    private var latestSteering:          SteeringResult?

    private static let yoloHz: Double = 3.0
    private static let yoloMinBBoxArea: Double = 0.015
    // internal so ViewModel can reference them for the stationary scan
    static let navigationLabels: Set<String> = [
        "person", "bicycle", "car", "motorcycle", "bus", "truck",
        "traffic light", "stop sign", "fire hydrant",
        "bench", "chair", "dog", "cat", "horse",
    ]

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

        NavigationSessionLogger.shared.startSession()
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

        // Export session metrics to the log before resetting
        let summary = NavigationSessionLogger.shared.exportSummary()
        AppLogger.navigation.info("\(summary)")
        NavigationSessionLogger.shared.reset()

        // Reset per-frame state for the next session
        lastYaw                  = .nan
        lastProcessed            = 0
        lastAllBlockedFired      = 0
        lastHeatmapTime          = 0
        lastYoloTime             = 0
        vfhLowConfidenceFrames   = 0
        posHistory               = []
        lastPublishedTrajectory  = nil
        latestSteering           = nil
        pathPlanner.reset()

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

        // Trajectory tracking runs on every frame for accurate motion data
        updateMotion(frame: frame, now: now)

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

        // VFH+ path planning — runs every processed frame regardless of guidance state
        let headingSector = Self.headingSector(for: lastPublishedTrajectory?.direction)
        let rawSteering   = pathPlanner.computeSteering(frame: frame, currentHeadingSector: headingSector)

        // Confidence fallback: if VFH confidence stays below 0.1 for more than 1 s
        // (e.g. depth sensor temporarily degraded), derive steering from the zone-based
        // snapshot so downstream audio/haptic guidance never silently goes dark.
        if rawSteering.confidence < 0.1 { vfhLowConfidenceFrames += 1 }
        else                            { vfhLowConfidenceFrames  = 0 }

        let steering: SteeringResult
        if vfhLowConfidenceFrames > hz {
            let fallbackAngle: Float = {
                switch snapshot.clearDirection {
                case .left:  return -.pi / 4
                case .right: return  .pi / 4
                default:     return  0
                }
            }()
            steering = SteeringResult(
                angle:       fallbackAngle,
                clearance:   snapshot.clearDistance,
                confidence:  0,
                direction:   snapshot.clearDirection,
                valleyCount: 0
            )
            AppLogger.navigation.warning("VFH confidence sustained low — zone fallback active")
        } else {
            steering = rawSteering
        }

        latestSteering = steering
        Task { @MainActor [weak self] in self?.onSteering?(steering) }

        // --- Guidance pipeline (suppressed during calibration scan) ---
        guard guidanceActive else { return }

        // Suppress the continuous guide tone and haptic pulse while the user is standing still.
        // A guide dog doesn't pull when stationary. Exception: imminent threat (< 0.8 m or all-blocked).
        let isStationary     = lastPublishedTrajectory?.stationary == true
        let isImminentThreat = steering.clearance < 0.8 || steering.direction == .none
        if !isStationary || isImminentThreat {
            haptics?.update(steering: steering)
            audio?.update(steering: steering)
        }

        // Stair / dropoff heuristic — can be disabled in Navigation Preferences
        let stepsEnabled = UserDefaults.standard.object(forKey: NavPreferenceKeys.stepsDetection) as? Bool ?? true
        if stepsEnabled {
            let pitch = frame.camera.eulerAngles.x
            if let event = processor.detectStep(snapshot: snapshot, cameraPitch: pitch) {
                haptics?.fireTransient(for: event)
                Task { @MainActor [weak self] in self?.onEvent?(event) }
            }
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

        // YOLO fusion — run at yoloHz, independent of haptic/audio cadence
        runYOLOIfNeeded(frame: frame, snapshot: snapshot, now: now)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for case let plane as ARPlaneAnchor in anchors where plane.alignment == .horizontal {
            pathPlanner.calibrateFloor(planeAnchor: plane)
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for case let plane as ARPlaneAnchor in anchors where plane.alignment == .horizontal {
            pathPlanner.calibrateFloor(planeAnchor: plane)
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

// MARK: - YOLO fusion

extension DepthNavigator {

    /// Launches YOLO inference on the AR frame's camera image at ≈yoloHz.
    /// Fires onDetections with all predictions (for the debug overlay), then
    /// fires onObjectAlert for each navigation-relevant detection above the size threshold.
    /// Both step detection and YOLO can be individually disabled in Navigation Preferences.
    private func runYOLOIfNeeded(frame: ARFrame, snapshot: ObstacleSnapshot, now: CFTimeInterval) {
        guard UserDefaults.standard.object(forKey: NavPreferenceKeys.yoloDetection) as? Bool ?? true else { return }
        guard now - lastYoloTime >= 1.0 / Self.yoloHz else { return }
        lastYoloTime = now

        let pixelBuffer = frame.capturedImage
        Task {
            do {
                let predictions = try await CustomMLModel.shared.detectObjects(pixelBuffer: pixelBuffer)

                // All predictions → debug overlay
                Task { @MainActor [weak self] in self?.onDetections?(predictions) }

                // Navigation-relevant predictions → audio alerts
                let alerts: [NavigationObjectAlert] = predictions.compactMap { prediction in
                    guard Self.navigationLabels.contains(prediction.label),
                          let bbox = prediction.boundingBox,
                          Double(bbox.width * bbox.height) >= Self.yoloMinBBoxArea
                    else { return nil }
                    return NavigationObjectAlert(
                        label: prediction.label,
                        confidence: prediction.confidence,
                        direction: Self.direction(from: bbox),
                        estimatedDistance: Self.estimatedDistance(from: snapshot, bbox: bbox),
                        boundingBox: bbox
                    )
                }
                for alert in alerts {
                    Task { @MainActor [weak self] in self?.onObjectAlert?(alert) }
                }
                if !alerts.isEmpty {
                    Task { @MainActor [weak self] in self?.onObjectAlerts?(alerts) }
                }
            } catch {
                AppLogger.navigation.error("Navigation YOLO error: \(error.localizedDescription)")
            }
        }
    }

    /// Maps a Vision bounding-box centre X to a left/center/right direction.
    /// Internal so ViewModel can reuse it for the stationary-scan announcement.
    static func direction(from bbox: CGRect) -> ClearDirection {
        switch bbox.midX {
        case ..<0.33: return .left
        case 0.67...: return .right
        default:      return .center
        }
    }

    /// Maintains a 2-second position ring buffer and publishes trajectory direction
    /// + stationarity whenever either value changes. Runs on every ARKit frame for
    /// maximum accuracy; change-detects before dispatching to @MainActor.
    private func updateMotion(frame: ARFrame, now: CFTimeInterval) {
        let col3 = frame.camera.transform.columns.3
        let pos   = SIMD3<Float>(col3.x, col3.y, col3.z)
        posHistory.append(PosSample(time: now, position: pos))
        // Prune to 2-second window
        posHistory = posHistory.filter { now - $0.time <= 2.0 }

        guard let oldest = posHistory.first, let newest = posHistory.last,
              newest.time - oldest.time > 0.3
        else { return }

        let elapsed      = Float(newest.time - oldest.time)
        let displacement = newest.position - oldest.position
        let speed        = simd_length(displacement) / elapsed  // m/s

        let isStationary = speed < 0.05

        let direction: ClearDirection
        if isStationary {
            direction = .none
        } else {
            // Project displacement onto camera's right axis to classify lateral drift
            let col0     = frame.camera.transform.columns.0
            let camRight = SIMD3<Float>(col0.x, col0.y, col0.z)
            let lateral  = simd_dot(displacement, camRight) / elapsed   // m/s in right direction
            if lateral > 0.08 {
                direction = .right
            } else if lateral < -0.08 {
                direction = .left
            } else {
                direction = .center
            }
        }

        guard lastPublishedTrajectory?.direction != direction ||
              lastPublishedTrajectory?.stationary != isStationary
        else { return }
        lastPublishedTrajectory = (direction, isStationary)
        Task { @MainActor [weak self] in self?.onTrajectoryUpdate?(direction, isStationary) }
    }

    /// Maps a discrete walking direction to the nearest polar-histogram sector index.
    /// Used to seed the VFH+ cost function with the current heading.
    private static func headingSector(for direction: ClearDirection?) -> Int {
        switch direction {
        case .right: return 9    // 90° right = sector 9 (10° per sector)
        case .left:  return 27   // 270° = sector 27 (90° left, wrapping around)
        default:     return 0    // forward
        }
    }

    /// Returns the LiDAR depth reading for the lower-row zone that corresponds
    /// to the horizontal position of the bounding box.
    private static func estimatedDistance(from snapshot: ObstacleSnapshot, bbox: CGRect) -> Float? {
        let col: Int
        switch bbox.midX {
        case ..<0.33: col = 0
        case 0.67...: col = 2
        default:      col = 1
        }
        guard snapshot.cells.indices.contains(1),
              snapshot.cells[1].indices.contains(col)
        else { return nil }
        let d = snapshot.cells[1][col].distance
        return d.isFinite ? d : nil
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
