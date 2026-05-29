//
//  DepthNavigatorView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import SwiftUI

/// Deliberately minimal navigation screen — the user cannot see it.
/// Identification is by VoiceOver announcement and the large tactile Stop button.
struct DepthNavigatorView: View {

    @StateObject private var viewModel = DepthNavigatorViewModel()
    @Environment(\.dismiss) private var dismiss

    private var isRomanian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                directionCard
                Spacer()
                zoneGrid
                if viewModel.isDebugMode {
                    Spacer(minLength: 8)
                    debugHeatmapPanel
                }
                Spacer()
                stopButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if viewModel.isCalibrating {
                CalibrationOverlay(
                    progress: viewModel.calibrationProgress,
                    trackingState: viewModel.trackingState,
                    onStart: { viewModel.completeCalibration() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.isCalibrating)
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear  { viewModel.onAppear()    }
        .onDisappear { viewModel.onDisappear() }
        .alert(isRomanian ? "Eroare" : "Error",
               isPresented: Binding(
                   get: { viewModel.errorMessage != nil },
                   set: { if !$0 { viewModel.errorMessage = nil } }
               )) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isRomanian ? "Mod Navigare" : "Navigation Mode")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                if viewModel.isRunning && !viewModel.isCalibrating {
                    Label(isRomanian ? "LiDAR activ" : "LiDAR active",
                          systemImage: "sensor.tag.radiowaves.forward.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Debug heatmap toggle
            Button(action: viewModel.toggleDebug) {
                Image(systemName: viewModel.isDebugMode
                      ? "viewfinder.circle.fill"
                      : "viewfinder.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.isDebugMode ? .cyan : .gray)
                    .padding(8)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel(viewModel.isDebugMode
                ? (isRomanian ? "Ascunde heatmap" : "Hide heatmap")
                : (isRomanian ? "Arată heatmap"   : "Show heatmap"))

            // Spatial audio toggle (haptics are always on)
            Button(action: viewModel.toggleAudio) {
                Label(
                    isRomanian ? "Audio" : "Audio",
                    systemImage: viewModel.isAudioEnabled
                        ? "speaker.wave.3.fill"
                        : "speaker.slash.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(viewModel.isAudioEnabled ? .yellow : .gray)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: Capsule())
            }
            .accessibilityLabel(
                viewModel.isAudioEnabled
                    ? (isRomanian ? "Dezactivează ghidaj audio" : "Disable audio guidance")
                    : (isRomanian ? "Activează ghidaj audio"    : "Enable audio guidance")
            )
        }
    }

    private var directionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.directionSymbol)
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(directionColor)
                .contentTransition(.symbolEffect(.replace))

            Text(viewModel.statusTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(viewModel.distanceText)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.statusTitle), \(viewModel.distanceText)")
    }

    private var zoneGrid: some View {
        HStack(spacing: 8) {
            ForEach(Array(zip(
                [isRomanian ? "Stânga" : "Left",
                 isRomanian ? "Centru" : "Center",
                 isRomanian ? "Dreapta" : "Right"],
                viewModel.zoneDistances
            )), id: \.0) { label, dist in
                ZoneCell(label: label, distance: dist)
            }
        }
        .accessibilityHidden(true)
    }

    private var debugHeatmapPanel: some View {
        VStack(spacing: 4) {
            Group {
                if let img = viewModel.debugHeatmap {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.white.opacity(0.04)
                        .overlay {
                            Text(isRomanian ? "Se încarcă…" : "Loading…")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Zone distance strip below heatmap
            HStack(spacing: 0) {
                ForEach(Array(zip(["L", "C", "R"], viewModel.zoneDistances)), id: \.0) { lbl, dist in
                    Text(dist.isFinite ? String(format: "%.1f", dist) : "—")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(zoneTextColor(dist))
                        .frame(maxWidth: .infinity)
                }
            }

            Text(isRomanian ? "Debug Heatmap LiDAR" : "LiDAR Debug Heatmap")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private var stopButton: some View {
        Button(action: { dismiss() }) {
            Text(isRomanian ? "Oprește Navigarea" : "Stop Navigation")
                .font(.title2.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .accessibilityLabel(isRomanian ? "Oprește navigarea" : "Stop navigation")
        .accessibilityHint(isRomanian ? "Apasă pentru a ieși din modul navigare" : "Tap to exit navigation mode")
    }

    private var directionColor: Color {
        switch viewModel.clearDirection {
        case .none:          return .red
        case .center:        return .green
        case .left, .right:  return .yellow
        }
    }

    private func zoneTextColor(_ dist: Float) -> Color {
        guard dist.isFinite else { return .white.opacity(0.5) }
        switch dist {
        case ..<0.5:    return .red
        case 0.5..<1.5: return .orange
        case 1.5..<3.0: return .yellow
        default:        return .green
        }
    }
}

// MARK: - CalibrationOverlay

private struct CalibrationOverlay: View {

    let progress:      Double
    let trackingState: NavigationTrackingState
    let onStart:       () -> Void

    @State private var isPulsing = false

    private var isRomanian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 28) {

                // Pulsing LiDAR icon with circular progress ring
                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                        .frame(width: 144, height: 144)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.purple,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 144, height: 144)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)

                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(Color.purple)
                        .scaleEffect(isPulsing ? 1.12 : 0.92)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                }
                .onAppear { isPulsing = true }

                VStack(spacing: 10) {
                    Text(isRomanian ? "Scanare mediu..." : "Scanning environment...")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(isRomanian
                         ? "Mișcă ușor telefonul pentru a scana zona din jur."
                         : "Slowly pan the phone around so LiDAR can build the scene.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                trackingStateLabel

                Button(action: onStart) {
                    Text(isRomanian ? "Începe Navigarea" : "Start Navigation")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
        }
    }

    @ViewBuilder
    private var trackingStateLabel: some View {
        let info = trackingInfo
        Label(info.text, systemImage: info.icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(info.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(info.color.opacity(0.12), in: Capsule())
    }

    private var trackingInfo: (icon: String, text: String, color: Color) {
        switch trackingState {
        case .normal:
            return ("checkmark.circle.fill",
                    isRomanian ? "Semnal bun — puteți continua" : "Good signal — ready",
                    .green)
        case .limitedExcessiveMotion:
            return ("exclamationmark.circle.fill",
                    isRomanian ? "Mișcare prea rapidă — încetinește" : "Moving too fast — slow down",
                    .orange)
        case .limitedInsufficientFeatures:
            return ("light.max",
                    isRomanian ? "Puține detalii — îmbunătățește iluminarea" : "Low features — try better lighting",
                    .yellow)
        case .initializing, .notAvailable:
            return ("circle.dotted",
                    isRomanian ? "Inițializare..." : "Initializing...",
                    .gray)
        }
    }
}

// MARK: - ZoneCell

private struct ZoneCell: View {
    let label: String
    let distance: Float

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))

            Text(distanceString)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(zoneColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var distanceString: String {
        distance.isFinite ? String(format: "%.1f m", distance) : "—"
    }

    private var zoneColor: Color {
        guard distance.isFinite else { return .white.opacity(0.4) }
        switch distance {
        case ..<0.5:    return .red
        case 0.5..<1.5: return .orange
        case 1.5..<3.0: return .yellow
        default:        return .green
        }
    }
}

#Preview {
    DepthNavigatorView()
}
