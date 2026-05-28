//
//  HapticEngine.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import UIKit

// Provides stratified haptic feedback tied to obstacle proximity and path relation.
// Heavy for immediate in-path hazards, medium for near in-path, light for adjacent.
// Peripheral / out-of-relevance detections produce no haptic to avoid sensory noise.
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let light  = UIImpactFeedbackGenerator(style: .light)

    private init() {
        heavy.prepare()
        medium.prepare()
        light.prepare()
    }

    func warn(proximity: Proximity, inPath: Bool) {
        switch (proximity, inPath) {
        case (.immediate, true):  heavy.impactOccurred()
        case (.near, true):       medium.impactOccurred()
        case (_, true):           break
        case (_, false):          light.impactOccurred()
        }
    }
}
