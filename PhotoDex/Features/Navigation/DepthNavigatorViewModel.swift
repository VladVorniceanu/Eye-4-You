//
//  DepthNavigatorViewModel.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import AVFoundation
import SwiftUI

@MainActor
final class DepthNavigatorViewModel: ObservableObject {

    // Navigation state
    @Published private(set) var isRunning       = false
    @Published var isAudioEnabled               = false
    @Published private(set) var clearDirection: ClearDirection = .none
    @Published private(set) var clearDistance:  Float = 0
    @Published private(set) var nearestDistance: Float = .infinity
    @Published private(set) var zoneDistances:  [Float] = [.infinity, .infinity, .infinity]
    @Published var errorMessage: String?
    @Published private(set) var lastEvent: NavigationEvent?

    // Calibration
    @Published private(set) var isCalibrating:       Bool   = false
    @Published private(set) var calibrationProgress: Double = 0
    @Published private(set) var trackingState: NavigationTrackingState = .initializing

    // Debug heatmap
    @Published private(set) var isDebugMode:  Bool     = false
    @Published private(set) var debugHeatmap: UIImage? = nil

    // YOLO fusion
    @Published private(set) var lastObjectAlert: NavigationObjectAlert?
    /// All raw YOLO predictions from the last inference cycle — used by the debug overlay.
    @Published private(set) var rawDetections: [Prediction] = []

    // Trajectory / stop detection
    @Published private(set) var movementDirection: ClearDirection = .none
    @Published private(set) var isStationary: Bool = false

    // VFH steering state — updated from onSteering, consumed by PathAwareFilter
    @Published private(set) var latestSteering: SteeringResult?

    // Session stats — refreshed at ≤1 Hz for the debug panel
    @Published private(set) var sessionAvgLatencyMs: String = "—"
    @Published private(set) var sessionNearMisses:   Int    = 0
    @Published private(set) var sessionSupprPct:     String = "—"
    private var lastStatsRefresh: Date = .distantPast

    private let navigator      = DepthNavigator.shared
    private let announcer      = DangerAnnouncer.shared
    private let pathFilter     = PathAwareFilter()
    private var calibrationTask: Task<Void, Never>?

    private static let calibrationKey = "nav.calibrationCompleted"

    private var lastSnapshot: ObstacleSnapshot?
    private var hasFiredStationaryScan = false

    private let navLabelNamesRO: [String: String] = [
        "person": "Persoană", "bicycle": "Bicicletă", "car": "Mașină",
        "motorcycle": "Motocicletă", "bus": "Autobuz", "truck": "Camion",
        "traffic light": "Semafor", "stop sign": "Semn de stop",
        "fire hydrant": "Hidrant", "bench": "Bancă", "chair": "Scaun",
        "dog": "Câine", "cat": "Pisică", "horse": "Cal",
    ]

    private var isRomanian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard !isRunning else { return }
        start()
    }

    func onDisappear() {
        calibrationTask?.cancel()
        calibrationTask = nil
        stop()
    }

    func start() {
        do {
            navigator.onSnapshot            = { [weak self] snap       in self?.handleSnapshot(snap) }
            navigator.onEvent               = { [weak self] event      in self?.handleEvent(event) }
            navigator.onHeatmap             = { [weak self] img        in self?.debugHeatmap = img }
            navigator.onTrackingStateChange = { [weak self] state      in self?.trackingState = state }
            navigator.onObjectAlert         = { [weak self] alert      in self?.lastObjectAlert = alert }
            navigator.onObjectAlerts        = { [weak self] alerts     in self?.handleObjectAlerts(alerts) }
            navigator.onDetections          = { [weak self] preds      in self?.rawDetections = preds }
            navigator.onTrajectoryUpdate    = { [weak self] dir, stat  in self?.handleTrajectoryUpdate(dir, stationary: stat) }
            navigator.onSteering            = { [weak self] s          in self?.latestSteering = s; self?.refreshStatsIfNeeded() }

            try navigator.start()
            isRunning    = true
            errorMessage = nil

            announcer.radarGate = navigator

            let message = isRomanian
                ? "Mod Navigare activ. Ține telefonul în față, ușor înclinat spre podea."
                : "Navigation Mode active. Hold the phone in front of you, slightly tilted toward the ground."
            UIAccessibility.post(notification: .announcement, argument: message)

            if UserDefaults.standard.bool(forKey: Self.calibrationKey) {
                // Calibration already done on a previous launch — start guidance immediately
                navigator.setGuidanceActive(true)
            } else {
                beginCalibration()
            }

        } catch {
            errorMessage = error.localizedDescription
            AppLogger.navigation.error("Failed to start navigation: \(error.localizedDescription)")
        }
    }

    func stop() {
        calibrationTask?.cancel()
        calibrationTask = nil

        navigator.stop()
        navigator.onSnapshot            = nil
        navigator.onEvent               = nil
        navigator.onHeatmap             = nil
        navigator.onTrackingStateChange = nil
        navigator.onObjectAlert         = nil
        navigator.onObjectAlerts        = nil
        navigator.onDetections          = nil
        navigator.onTrajectoryUpdate    = nil
        navigator.onSteering            = nil
        announcer.radarGate = nil
        pathFilter.reset()

        isRunning              = false
        isCalibrating          = false
        calibrationProgress    = 0
        clearDirection         = .none
        clearDistance          = 0
        nearestDistance        = .infinity
        zoneDistances          = [.infinity, .infinity, .infinity]
        debugHeatmap           = nil
        isDebugMode            = false
        lastObjectAlert        = nil
        rawDetections          = []
        movementDirection      = .none
        isStationary           = false
        latestSteering         = nil
        lastSnapshot           = nil
        hasFiredStationaryScan = false
        sessionAvgLatencyMs    = "—"
        sessionNearMisses      = 0
        sessionSupprPct        = "—"
        lastStatsRefresh       = .distantPast
    }

    func toggleAudio() {
        isAudioEnabled.toggle()
        navigator.setAudioEnabled(isAudioEnabled)
    }

    func toggleDebug() {
        isDebugMode.toggle()
        navigator.setDebugEnabled(isDebugMode)
        if !isDebugMode { debugHeatmap = nil }
    }

    /// Called when the user taps "Start Navigation" in the calibration overlay,
    /// or automatically after the 5-second countdown completes.
    func completeCalibration() {
        calibrationTask?.cancel()
        calibrationTask = nil

        UserDefaults.standard.set(true, forKey: Self.calibrationKey)
        navigator.setGuidanceActive(true)

        withAnimation(.easeInOut(duration: 0.4)) {
            isCalibrating = false
        }
        calibrationProgress = 1

        let message = isRomanian
            ? "Calibrare completă. Navigarea a început."
            : "Calibration complete. Guidance started."
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    // MARK: - Computed UI helpers

    var statusTitle: String {
        switch clearDirection {
        case .none:   return isRomanian ? "Drum blocat" : "Path blocked"
        default:      return isRomanian ? "Mergi \(clearDirection.localizedName)" : "Go \(clearDirection.localizedName)"
        }
    }

    var distanceText: String {
        clearDistance > 0 && clearDistance.isFinite
            ? String(format: isRomanian ? "%.1f m liber" : "%.1f m clear", clearDistance)
            : (isRomanian ? "Distanță nedeterminată" : "Distance unknown")
    }

    var directionSymbol: String {
        switch clearDirection {
        case .left:   return "arrow.turn.up.left"
        case .center: return "arrow.up"
        case .right:  return "arrow.turn.up.right"
        case .none:   return "exclamationmark.triangle"
        }
    }

    // MARK: - Private

    private func beginCalibration() {
        isCalibrating       = true
        calibrationProgress = 0

        // Auto-complete after 5 s (50 × 0.1 s steps); user can skip earlier.
        calibrationTask = Task {
            let steps = 50
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 s
                guard !Task.isCancelled else { return }
                calibrationProgress = Double(i) / Double(steps)
            }
            completeCalibration()
        }
    }

    private func handleSnapshot(_ snapshot: ObstacleSnapshot) {
        lastSnapshot    = snapshot
        clearDirection  = snapshot.clearDirection
        clearDistance   = snapshot.clearDistance
        nearestDistance = snapshot.nearest?.distance ?? .infinity
        zoneDistances = [
            snapshot.lowerLeft?.distance   ?? .infinity,
            snapshot.lowerCenter?.distance ?? .infinity,
            snapshot.lowerRight?.distance  ?? .infinity,
        ]
    }

    private func handleEvent(_ event: NavigationEvent) {
        lastEvent = event
        announceEvent(event)
    }

    private func announceEvent(_ event: NavigationEvent) {
        let text: String = {
            switch event {
            case .stepUp:    return isRomanian ? "Treaptă sus"              : "Step up"
            case .stepDown:  return isRomanian ? "Treaptă jos — atenție"    : "Step down — caution"
            case .doorAhead: return isRomanian ? "Ușă înainte"              : "Door ahead"
            case .allBlocked:return isRomanian ? "Calea este blocată — oprește-te" : "Path blocked — stop"
            }
        }()

        let utterance = AVSpeechUtterance(string: text)
        let langCode  = isRomanian ? "ro-RO" : "en-US"
        utterance.voice  = AVSpeechSynthesisVoice(language: langCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.volume = 1.0
        announcer.speakNavigationAlert(utterance)
    }

    private func handleTrajectoryUpdate(_ direction: ClearDirection, stationary: Bool) {
        movementDirection = direction
        isStationary      = stationary

        if stationary && !hasFiredStationaryScan {
            hasFiredStationaryScan = true
            runStationaryScan()
        } else if !stationary {
            hasFiredStationaryScan = false
        }
    }

    /// Receives the full batch of YOLO alerts from one inference cycle,
    /// runs them through PathAwareFilter (which enforces the VFH suppression rules),
    /// and speaks the single highest-priority threat via DangerAnnouncer.
    private func handleObjectAlerts(_ alerts: [NavigationObjectAlert]) {
        guard !isStationary else { return }
        guard let steering = latestSteering else { return }
        let raw       = UserDefaults.standard.integer(forKey: NavPreferenceKeys.verbosityLevel)
        let verbosity = NavVerbosityLevel(rawValue: raw) ?? .balanced
        let top       = pathFilter.filter(alerts: alerts, steering: steering, verbosity: verbosity)
        guard let detection = top.first else { return }
        announcer.processPathAwareDetection(detection)
    }

    /// Called when user has been stationary for ≥2 s. Announces up to 3 detected
    /// navigation objects in a single compound utterance for a wider scene summary.
    private func runStationaryScan() {
        guard UserDefaults.standard.object(forKey: NavPreferenceKeys.yoloDetection) as? Bool ?? true else { return }

        let top = rawDetections
            .filter { DepthNavigator.navigationLabels.contains($0.label) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)

        guard !top.isEmpty else { return }

        let intro = isRomanian ? "Stai pe loc. " : "Standing still. "
        let parts: [String] = top.map { pred in
            let bbox = pred.boundingBox ?? .zero
            let dir  = DepthNavigator.direction(from: bbox)
            let dist = lastSnapshot.flatMap { estimatedDistanceFromLastSnapshot($0, bbox: bbox) }
            return labelPhrase(label: pred.label, direction: dir, distance: dist)
        }

        speak(text: intro + parts.joined(separator: ". "), rate: 1.0)
    }

    // MARK: - Shared speech helpers

    private func speak(text: String, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        let langCode  = isRomanian ? "ro-RO" : "en-US"
        utterance.voice  = AVSpeechSynthesisVoice(language: langCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate * rate
        utterance.volume = 1.0
        announcer.speakNavigationAlert(utterance)
    }

    private func labelPhrase(label: String, direction: ClearDirection, distance: Float?) -> String {
        let name    = isRomanian ? (navLabelNamesRO[label] ?? label.capitalized) : label.capitalized
        let dirWord = directionWord(direction)
        let distPart: String
        if let d = distance, d.isFinite, d >= 0.5 {
            distPart = isRomanian
                ? String(format: ", la %.0f metri", d)
                : String(format: ", %.0f meters away", d)
        } else {
            distPart = ""
        }
        return "\(name) \(dirWord)\(distPart)"
    }

    private func directionWord(_ direction: ClearDirection) -> String {
        if isRomanian {
            switch direction {
            case .left:          return "la stânga"
            case .right:         return "la dreapta"
            case .center, .none: return "în față"
            }
        } else {
            switch direction {
            case .left:          return "on the left"
            case .right:         return "on the right"
            case .center, .none: return "ahead"
            }
        }
    }

    private func refreshStatsIfNeeded() {
        guard Date().timeIntervalSince(lastStatsRefresh) >= 1.0 else { return }
        lastStatsRefresh    = Date()
        let logger          = NavigationSessionLogger.shared
        sessionAvgLatencyMs = String(format: "%.1f ms", logger.averageLatencyMs)
        sessionNearMisses   = logger.nearMissCount
        let rate            = logger.suppressionRate
        sessionSupprPct     = rate > 0 ? String(format: "%.0f%%", rate * 100) : "—"
    }

    private func estimatedDistanceFromLastSnapshot(_ snapshot: ObstacleSnapshot, bbox: CGRect) -> Float? {
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
