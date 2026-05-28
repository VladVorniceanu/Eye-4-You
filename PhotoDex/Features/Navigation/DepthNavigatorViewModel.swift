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

    @Published private(set) var isRunning = false
    @Published var isAudioEnabled = false       // haptics only by default; user can toggle audio
    @Published private(set) var clearDirection: ClearDirection = .none
    @Published private(set) var clearDistance: Float = 0
    @Published private(set) var nearestDistance: Float = .infinity
    @Published private(set) var zoneDistances: [Float] = [.infinity, .infinity, .infinity]
    @Published var errorMessage: String?
    @Published private(set) var lastEvent: NavigationEvent?

    private let navigator = DepthNavigator.shared
    private let announcer = DangerAnnouncer.shared
    private var isRomanian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard !isRunning else { return }
        start()
    }

    func onDisappear() {
        stop()
    }

    func start() {
        do {
            navigator.onSnapshot = { [weak self] snapshot in self?.handleSnapshot(snapshot) }
            navigator.onEvent    = { [weak self] event    in self?.handleEvent(event) }

            try navigator.start()
            isRunning = true
            errorMessage = nil

            // Wire up DangerAnnouncer so it mutes spatial audio while speaking
            announcer.radarGate = navigator

            // Announce mode activation for VoiceOver users
            let message = isRomanian
                ? "Mod Navigare activ. Ține telefonul în față, ușor înclinat spre podea."
                : "Navigation Mode active. Hold the phone in front of you, slightly tilted toward the ground."
            UIAccessibility.post(notification: .announcement, argument: message)

        } catch {
            errorMessage = error.localizedDescription
            AppLogger.navigation.error("Failed to start navigation: \(error.localizedDescription)")
        }
    }

    func stop() {
        navigator.stop()
        navigator.onSnapshot = nil
        navigator.onEvent    = nil
        announcer.radarGate  = nil
        isRunning            = false
        clearDirection       = .none
        clearDistance        = 0
        nearestDistance      = .infinity
        zoneDistances        = [.infinity, .infinity, .infinity]
    }

    func toggleAudio() {
        isAudioEnabled.toggle()
        navigator.setAudioEnabled(isAudioEnabled)
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

    // MARK: - Private handlers

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
            case .stepUp:
                return isRomanian ? "Treaptă sus" : "Step up"
            case .stepDown:
                return isRomanian ? "Treaptă jos — atenție" : "Step down — caution"
            case .doorAhead:
                return isRomanian ? "Ușă înainte" : "Door ahead"
            case .allBlocked:
                return isRomanian ? "Calea este blocată — oprește-te" : "Path blocked — stop"
            }
        }()

        // Use a separate utterance so it does not fight the radar audio gate.
        let utterance = AVSpeechUtterance(string: text)
        let langCode  = isRomanian ? "ro-RO" : "en-US"
        utterance.voice  = AVSpeechSynthesisVoice(language: langCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.volume = 1.0
        announcer.speakNavigationAlert(utterance)
    }
}
