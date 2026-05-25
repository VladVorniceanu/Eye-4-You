//
//  DangerAnnouncer.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/18/26.
//

import AVFoundation
import Foundation

// Announces path hazards detected by the live YOLO model using text-to-speech.
// A label must appear ≥5 times/sec for ≥2 continuous seconds before the first
// announcement, then a per-label cooldown prevents constant repetition.
// While a scene description is playing, danger-warning speech is suppressed.
@MainActor
final class DangerAnnouncer: NSObject {
    static let shared = DangerAnnouncer()

    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    private var labelTimestamps: [String: [Date]] = [:]
    private var lastAnnouncedAt: [String: Date] = [:]

    // Guards against danger warnings queuing on top of an in-progress description
    private var isDescribing = false
    private var onDescriptionComplete: (() -> Void)?

    // 5 detections/sec × 2 sec = 10 hits inside the 2-second window
    private let windowDuration: TimeInterval = 2.0
    private let requiredHits = 10
    private let announceCooldown: TimeInterval = 5.0

    // YOLOv5s COCO classes that are path hazards → spoken warning phrase.
    // Hazards not in COCO 80 (potholes, bollards, curbs, crosswalks) require
    // a custom-trained model and will be added in a future step.
    private let dangerPhrases: [String: String] = [
        "car":           "Car ahead",
        "truck":         "Truck ahead",
        "bus":           "Bus ahead",
        "motorcycle":    "Motorcycle nearby",
        "bicycle":       "Bicycle nearby",
        "person":        "Person in the way",
        "traffic light": "Traffic light ahead",
        "stop sign":     "Stop sign",
        "fire hydrant":  "Fire hydrant on path",
        "bench":         "Bench on path",
        "chair":         "Chair in the way",
        "dining table":  "Table in the way",
        "suitcase":      "Luggage on path",
        "backpack":      "Bag on path",
        "umbrella":      "Umbrella in the way",
        "handbag":       "Bag on path",
        "sports ball":   "Ball on path",
        "skateboard":    "Skateboard on path",
        "dog":           "Dog nearby",
        "cat":           "Cat nearby",
        "horse":         "Horse nearby",
    ]

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func process(predictions: [Prediction]) {
        guard isEnabled, !isDescribing else { return }

        let now = Date()
        let cutoff = now.addingTimeInterval(-windowDuration)

        let detectedDangers = Set(predictions.compactMap { dangerPhrases[$0.label] != nil ? $0.label : nil })

        for label in detectedDangers {
            var times = labelTimestamps[label] ?? []
            times.append(now)
            times = times.filter { $0 > cutoff }
            labelTimestamps[label] = times

            guard times.count >= requiredHits else { continue }

            if let last = lastAnnouncedAt[label], now.timeIntervalSince(last) < announceCooldown {
                continue
            }

            speak(label: label, at: now)
        }

        for label in labelTimestamps.keys where !detectedDangers.contains(label) {
            labelTimestamps[label] = labelTimestamps[label]?.filter { $0 > cutoff }
        }
    }

    // Reads aloud everything currently visible, closest first (largest bounding box = nearest).
    // Each object gets a left / ahead / right positional cue.
    // Suppresses danger warnings until speech finishes; calls onComplete when done.
    func describeScene(predictions: [Prediction], onComplete: @escaping () -> Void) {
        synthesizer.stopSpeaking(at: .immediate)
        isDescribing = true
        onDescriptionComplete = onComplete

        let top = predictions
            .compactMap { p -> (Prediction, CGFloat)? in
                guard let box = p.boundingBox else { return nil }
                return (p, box.width * box.height)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }

        guard !top.isEmpty else {
            utter("Nothing detected around you.")
            return
        }

        let phrases = top.map { p -> String in
            let pos = p.boundingBox.map { positionLabel(for: $0) } ?? "ahead"
            return "\(p.label.capitalized) \(pos)"
        }

        let text: String
        if phrases.count == 1 {
            text = "I can see \(phrases[0])."
        } else {
            let head = phrases.dropLast().joined(separator: ", ")
            text = "I can see \(head), and \(phrases.last!)."
        }

        utter(text)
    }

    func reset() {
        synthesizer.stopSpeaking(at: .immediate)
        isDescribing = false
        onDescriptionComplete = nil
        labelTimestamps = [:]
        lastAnnouncedAt = [:]
    }

    private func positionLabel(for box: CGRect) -> String {
        switch box.midX {
        case ..<0.33: return "on the left"
        case 0.67...: return "on the right"
        default:      return "ahead"
        }
    }

    private func utter(_ text: String) {
        // Activate audio session for speech output; camera session can otherwise prevent it
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    private func speak(label: String, at time: Date) {
        guard let phrase = dangerPhrases[label] else { return }
        lastAnnouncedAt[label] = time
        utter(phrase)
    }
}

extension DangerAnnouncer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleFinished()
        }
    }

    private func handleFinished() {
        guard isDescribing else { return }
        isDescribing = false
        let completion = onDescriptionComplete
        onDescriptionComplete = nil
        completion?()
    }
}
