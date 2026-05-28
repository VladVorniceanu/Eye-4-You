//
//  DangerAnnouncer.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/18/26.
//

import AVFoundation
import Foundation
import UIKit

// Announces path hazards detected by the live YOLO model using text-to-speech.
// Each frame, candidate detections are classified against a walking corridor
// (Corridor.default) and scored by `pathWeight × bboxHeight × labelWeight`;
// only the single highest-priority detection is considered for speech.
// Anything `inPath` is eligible regardless of label, so unfamiliar obstacles
// directly ahead still get called out; `adjacent` / `peripheral` detections
// are filtered through the curated hazard list to keep audio uncluttered.
// A label must accumulate ≥10 hits inside a 2-second window to clear debounce,
// and per-label + global cooldowns prevent constant repetition.
// Voice language follows the device's first preferred language (ro-RO or en-US).
@MainActor
final class DangerAnnouncer: NSObject {
    static let shared = DangerAnnouncer()

    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    private var labelTimestamps: [String: [Date]] = [:]
    private var lastAnnouncedAt: [String: Date] = [:]
    private var lastGlobalAnnouncementAt: Date?

    private var isDescribing = false
    private var onDescriptionComplete: (() -> Void)?

    private let windowDuration: TimeInterval = 2.0
    private let requiredHits = 10
    private let announceCooldown: TimeInterval = 5.0
    // Hard cap on overall announcement rate so the user isn't talked over
    // when several hazards trip their per-label cooldowns at the same time.
    private let globalAnnounceCooldown: TimeInterval = 2.0
    // Hazards whose composite priority falls below this are kept out of the
    // speech queue entirely — they remain available for describeScene.
    private let minPriorityToAnnounce: Double = 0.05

    private var isRomanian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    private let dangerPhrasesEN: [String: String] = [
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

    private let dangerPhrasesRO: [String: String] = [
        "car":           "Mașină în față",
        "truck":         "Camion în față",
        "bus":           "Autobuz în față",
        "motorcycle":    "Motocicletă aproape",
        "bicycle":       "Bicicletă aproape",
        "person":        "Persoană în cale",
        "traffic light": "Semafor în față",
        "stop sign":     "Semn de stop",
        "fire hydrant":  "Hidrant pe trotuar",
        "bench":         "Bancă în cale",
        "chair":         "Scaun în cale",
        "dining table":  "Masă în cale",
        "suitcase":      "Bagaj pe drum",
        "backpack":      "Rucsac pe drum",
        "umbrella":      "Umbrelă în cale",
        "handbag":       "Geantă pe drum",
        "sports ball":   "Minge pe drum",
        "skateboard":    "Skateboard pe drum",
        "dog":           "Câine aproape",
        "cat":           "Pisică aproape",
        "horse":         "Cal aproape",
    ]

    // Romanian display names for all YOLO COCO-80 labels used in scene descriptions.
    private let labelNamesRO: [String: String] = [
        "person": "Persoană", "bicycle": "Bicicletă", "car": "Mașină",
        "motorcycle": "Motocicletă", "airplane": "Avion", "bus": "Autobuz",
        "train": "Tren", "truck": "Camion", "boat": "Barcă",
        "traffic light": "Semafor", "fire hydrant": "Hidrant", "stop sign": "Semn de stop",
        "parking meter": "Parcomat", "bench": "Bancă", "bird": "Pasăre",
        "cat": "Pisică", "dog": "Câine", "horse": "Cal",
        "sheep": "Oaie", "cow": "Vacă", "elephant": "Elefant",
        "bear": "Urs", "zebra": "Zebră", "giraffe": "Girafă",
        "backpack": "Rucsac", "umbrella": "Umbrelă", "handbag": "Geantă",
        "tie": "Cravată", "suitcase": "Bagaj", "frisbee": "Frisbee",
        "skis": "Schiuri", "snowboard": "Snowboard", "sports ball": "Minge",
        "kite": "Zmeu", "baseball bat": "Bâtă", "baseball glove": "Mănușă baseball",
        "skateboard": "Skateboard", "surfboard": "Placă de surf", "tennis racket": "Rachetă tenis",
        "bottle": "Sticlă", "wine glass": "Pahar", "cup": "Cană",
        "fork": "Furculiță", "knife": "Cuțit", "spoon": "Lingură",
        "bowl": "Bol", "banana": "Banană", "apple": "Măr",
        "sandwich": "Sandviș", "orange": "Portocală", "broccoli": "Broccoli",
        "carrot": "Morcov", "hot dog": "Hotdog", "pizza": "Pizza",
        "donut": "Gogoașă", "cake": "Tort", "chair": "Scaun",
        "couch": "Canapea", "potted plant": "Plantă", "bed": "Pat",
        "dining table": "Masă", "toilet": "Toaletă", "tv": "Televizor",
        "laptop": "Laptop", "mouse": "Mouse", "remote": "Telecomandă",
        "keyboard": "Tastatură", "cell phone": "Telefon", "microwave": "Microunde",
        "oven": "Cuptor", "toaster": "Toaster", "sink": "Chiuvetă",
        "refrigerator": "Frigider", "book": "Carte", "clock": "Ceas",
        "vase": "Vază", "scissors": "Foarfecă", "teddy bear": "Ursuleț",
        "hair drier": "Uscător", "toothbrush": "Periuță de dinți",
    ]

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // Kept available (read-only) for diagnostics / fallback callers; the live
    // pipeline now composes phrases dynamically via `composePhrase(for:)`.
    var dangerPhrases: [String: String] {
        isRomanian ? dangerPhrasesRO : dangerPhrasesEN
    }

    func process(predictions: [Prediction]) {
        guard isEnabled else { return }

        let corridor = Corridor.default
        let scored = scoredHazards(from: predictions, corridor: corridor)

        // Continuous haptic runs every frame, independent of TTS cooldowns,
        // so the user feels the obstacle as long as it stays in the corridor.
        HapticEngine.shared.updateContinuousFeedback(for: scored.first)

        guard !isDescribing else { return }

        let now = Date()
        let cutoff = now.addingTimeInterval(-windowDuration)
        let currentLabels = Set(scored.map { $0.prediction.label })

        for label in currentLabels {
            var times = labelTimestamps[label] ?? []
            times.append(now)
            times = times.filter { $0 > cutoff }
            labelTimestamps[label] = times
        }
        for label in labelTimestamps.keys where !currentLabels.contains(label) {
            labelTimestamps[label] = labelTimestamps[label]?.filter { $0 > cutoff }
        }

        guard let top = scored.first else { return }

        if let lastGlobal = lastGlobalAnnouncementAt,
           now.timeIntervalSince(lastGlobal) < globalAnnounceCooldown {
            return
        }
        if let last = lastAnnouncedAt[top.prediction.label],
           now.timeIntervalSince(last) < announceCooldown {
            return
        }
        guard (labelTimestamps[top.prediction.label]?.count ?? 0) >= requiredHits else {
            return
        }

        announce(hazard: top, at: now)
    }

    private func scoredHazards(from predictions: [Prediction], corridor: Corridor) -> [ScoredHazard] {
        predictions
            .compactMap { p -> ScoredHazard? in
                guard let bbox = p.boundingBox else { return nil }
                let relation = corridor.classify(bbox)
                guard relation != .outsideRelevance else { return nil }
                // Anything in the walking corridor is worth announcing, even if
                // its COCO label isn't in the curated hazard list — an unknown
                // obstacle right in front of the user is still a tripping risk.
                // Adjacent/peripheral detections stay gated by the curated list
                // to keep the audio channel from getting noisy.
                if relation != .inPath, !isCuratedHazard(p.label) { return nil }
                // Peripheral detections suppressed when the setting is off.
                if relation == .peripheral,
                   !((UserDefaults.standard.object(forKey: AppSettingsKeys.peripheralAnnouncements) as? Bool) ?? true) {
                    return nil
                }
                let score = pathWeight(for: relation) * Double(bbox.height) * labelWeight(for: p.label)
                guard score >= minPriorityToAnnounce else { return nil }
                return ScoredHazard(
                    prediction: p,
                    relation: relation,
                    proximity: Proximity.from(bbox),
                    side: corridor.side(for: bbox),
                    score: score
                )
            }
            .sorted { $0.score > $1.score }
    }

    private func isCuratedHazard(_ label: String) -> Bool {
        dangerPhrasesEN[label] != nil
    }

    private func pathWeight(for relation: PathRelation) -> Double {
        switch relation {
        case .inPath:           return 1.0
        case .adjacent:         return 0.4
        case .peripheral:       return 0.15
        case .outsideRelevance: return 0
        }
    }

    private func labelWeight(for label: String) -> Double {
        switch label {
        case "car", "truck", "bus", "motorcycle":
            return 1.0
        case "person", "bicycle":
            return 0.8
        case "traffic light", "stop sign", "fire hydrant",
            "chair", "bench", "dining table", "bed", "desk":
            return 0.5
        case "dog", "cat", "horse":
            return 0.3
        default:
            return 0.4
        }
    }

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
            utter(isRomanian ? "Nu am detectat nimic în jurul tău." : "Nothing detected around you.")
            return
        }

        let phrases = top.map { p -> String in
            let pos = p.boundingBox.map { positionLabel(for: $0) } ?? (isRomanian ? "în față" : "ahead")
            let name = isRomanian ? (labelNamesRO[p.label] ?? p.label.capitalized) : p.label.capitalized
            return "\(name) \(pos)"
        }

        let text: String
        if isRomanian {
            if phrases.count == 1 {
                text = "Văd \(phrases[0])."
            } else {
                let head = phrases.dropLast().joined(separator: ", ")
                text = "Văd \(head) și \(phrases.last!)."
            }
        } else {
            if phrases.count == 1 {
                text = "I can see \(phrases[0])."
            } else {
                let head = phrases.dropLast().joined(separator: ", ")
                text = "I can see \(head), and \(phrases.last!)."
            }
        }

        utter(text)
    }

    func reset() {
        synthesizer.stopSpeaking(at: .immediate)
        HapticEngine.shared.stopPulsing()
        isDescribing = false
        onDescriptionComplete = nil
        labelTimestamps = [:]
        lastAnnouncedAt = [:]
        lastGlobalAnnouncementAt = nil
    }

    private func positionLabel(for box: CGRect) -> String {
        if isRomanian {
            switch box.midX {
            case ..<0.33: return "la stânga"
            case 0.67...: return "la dreapta"
            default:      return "în față"
            }
        } else {
            switch box.midX {
            case ..<0.33: return "on the left"
            case 0.67...: return "on the right"
            default:      return "ahead"
            }
        }
    }

    private func utter(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothHFP])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)
        let languageCode = isRomanian ? "ro-RO" : "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        let multiplier = (UserDefaults.standard.object(forKey: AppSettingsKeys.speechRateMultiplier) as? Double) ?? 1.0
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(multiplier)
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    private func announce(hazard: ScoredHazard, at time: Date) {
        lastAnnouncedAt[hazard.prediction.label] = time
        lastGlobalAnnouncementAt = time
        HapticEngine.shared.warn(proximity: hazard.proximity, inPath: hazard.relation == .inPath)
        utter(composePhrase(for: hazard))
    }

    private func composePhrase(for hazard: ScoredHazard) -> String {
        let label = hazard.prediction.label
        let name = isRomanian
            ? (labelNamesRO[label] ?? label.capitalized)
            : label.capitalized
        return isRomanian
            ? phraseRO(name: name, relation: hazard.relation, proximity: hazard.proximity, side: hazard.side)
            : phraseEN(name: name, relation: hazard.relation, proximity: hazard.proximity, side: hazard.side)
    }

    private func phraseRO(name: String, relation: PathRelation, proximity: Proximity, side: HazardSide) -> String {
        switch (relation, proximity) {
        case (.inPath, .immediate):
            return "\(name) foarte aproape, în fața ta"
        case (.inPath, .near):
            return "\(name) în cale"
        case (.inPath, _):
            return "\(name) în față"
        case (.adjacent, .immediate), (.adjacent, .near):
            return "\(name) foarte aproape, \(sideRO(side))"
        case (.adjacent, _):
            return "\(name) \(sideRO(side))"
        case (.peripheral, _):
            return "Atenție, \(name.lowercased()) \(sideRO(side))"
        case (.outsideRelevance, _):
            return name
        }
    }

    private func phraseEN(name: String, relation: PathRelation, proximity: Proximity, side: HazardSide) -> String {
        switch (relation, proximity) {
        case (.inPath, .immediate):
            return "\(name) very close, right ahead"
        case (.inPath, .near):
            return "\(name) in your path"
        case (.inPath, _):
            return "\(name) ahead"
        case (.adjacent, .immediate), (.adjacent, .near):
            return "\(name) very close, \(sideEN(side))"
        case (.adjacent, _):
            return "\(name) \(sideEN(side))"
        case (.peripheral, _):
            return "Heads up, \(name.lowercased()) \(sideEN(side))"
        case (.outsideRelevance, _):
            return name
        }
    }

    private func sideRO(_ side: HazardSide) -> String {
        switch side {
        case .left:   return "în stânga"
        case .right:  return "în dreapta"
        case .center: return "în față"
        }
    }

    private func sideEN(_ side: HazardSide) -> String {
        switch side {
        case .left:   return "on the left"
        case .right:  return "on the right"
        case .center: return "ahead"
        }
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
