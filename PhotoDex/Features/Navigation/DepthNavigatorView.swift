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
                Spacer()
                stopButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .alert(isRomanian ? "Eroare" : "Error",
               isPresented: Binding(
                   get: { viewModel.errorMessage != nil },
                   set: { if !$0 { viewModel.errorMessage = nil } }
               )) {
            Button(isRomanian ? "OK" : "OK") { dismiss() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isRomanian ? "Mod Navigare" : "Navigation Mode")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                if viewModel.isRunning {
                    Label(isRomanian ? "LiDAR activ" : "LiDAR active",
                          systemImage: "sensor.tag.radiowaves.forward.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Audio radar toggle (haptics are always on)
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
        .accessibilityHidden(true)  // direction card conveys the key info
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
        case .none:   return .red
        case .center: return .green
        case .left, .right: return .yellow
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
