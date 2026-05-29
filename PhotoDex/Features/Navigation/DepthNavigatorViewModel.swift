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

    private let navigator = DepthNavigator.shared
    private let announcer = DangerAnnouncer.shared
    private var calibrationTask: Task<Void, Never>?

    private static let calibrationKey = "nav.calibrationCompleted"

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
            navigator.onSnapshot            = { [weak self] snap  in self?.handleSnapshot(snap) }
            navigator.onEvent               = { [weak self] event in self?.handleEvent(event) }
            navigator.onHeatmap             = { [weak self] img   in self?.debugHeatmap = img }
            navigator.onTrackingStateChange = { [weak self] state in self?.trackingState = state }

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
        announcer.radarGate = nil

        isRunning           = false
        isCalibrating       = false
        calibrationProgress = 0
        clearDirection      = .none
        clearDistance       = 0
        nearestDistance     = .infinity
        zoneDistances       = [.infinity, .infinity, .infinity]
        debugHeatmap        = nil
        isDebugMode         = false
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
}
