//
//  CalibrationOverlay.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import SwiftUI

/// Full-screen overlay shown while the ARKit session calibrates ground height.
/// Displays a pulsing LiDAR icon with a circular progress ring and tracking-state badge.
struct CalibrationOverlay: View {
    let progress: Double
    let trackingState: NavigationTrackingState
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var isRO: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                progressRing
                instructionBlock
                trackingStateLabel

                Button(action: onStart) {
                    Text(isRO ? "Începe Navigarea" : "Start Navigation")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .accessibilityLabel(isRO ? "Începe navigarea" : "Start navigation")
                .accessibilityHint(isRO ? "Pornește ghidajul LiDAR" : "Starts LiDAR guidance")
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Sub-components

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                .frame(width: 144, height: 144)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 144, height: 144)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Color.purple)
                .scaleEffect(isPulsing ? 1.12 : 0.92)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: isPulsing
                )
        }
        .onAppear { isPulsing = true }
    }

    private var instructionBlock: some View {
        VStack(spacing: 10) {
            Text(isRO ? "Scanare mediu..." : "Scanning environment...")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(isRO
                 ? "Mișcă ușor telefonul în jur și îndreaptă-l spre podea pentru a calibra înălțimea."
                 : "Slowly pan the phone around and tilt toward the floor to calibrate ground height.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var trackingStateLabel: some View {
        let info = trackingInfo
        Label(info.text, systemImage: info.icon)
            .font(.subheadline.bold())
            .foregroundStyle(info.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(info.color.opacity(0.12), in: Capsule())
    }

    private var trackingInfo: (icon: String, text: String, color: Color) {
        switch trackingState {
        case .normal:
            return ("checkmark.circle.fill",
                    isRO ? "Semnal bun — puteți continua" : "Good signal — ready",
                    .green)
        case .limitedExcessiveMotion:
            return ("exclamationmark.circle.fill",
                    isRO ? "Mișcare prea rapidă — încetinește" : "Moving too fast — slow down",
                    .orange)
        case .limitedInsufficientFeatures:
            return ("light.max",
                    isRO ? "Puține detalii — îmbunătățește iluminarea" : "Low features — try better lighting",
                    .yellow)
        case .initializing, .notAvailable:
            return ("circle.dotted",
                    isRO ? "Inițializare..." : "Initializing...",
                    .gray)
        }
    }
}
