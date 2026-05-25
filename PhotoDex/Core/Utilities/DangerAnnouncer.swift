//
//  DangerAnnouncer.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/18/26.
//

import AVFoundation
import Foundation

// Announces path hazards detected by the live YOLO model using text-to-speech.
// A label must appear ≥10 times inside a 2-second window before the first
// announcement, then a per-label cooldown prevents constant repetition.
// Voice language follows the device's first preferred language (ro-RO or en-US).
@MainActor
final class DangerAnnouncer: NSObject {
    static let shared = DangerAnnouncer()

    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    private var labelTimestamps: [String: [Date]] = [:]
    private var lastAnnouncedAt: [String: Date] = [:]

    private var isDescribing = false
    private var onDescriptionComplete: (() -> Void)?

    private let windowDuration: TimeInterval = 2.0
    private let requiredHits = 10
    private let announceCooldown: TimeInterval = 5.0

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

    var dangerPhrases: [String: String] {
        isRomanian ? dangerPhrasesRO : dangerPhrasesEN
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
        isDescribing = false
        onDescriptionComplete = nil
        labelTimestamps = [:]
        lastAnnouncedAt = [:]
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
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)
        let languageCode = isRomanian ? "ro-RO" : "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
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
