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
    @State private var showPreferences = false

    private var isRO: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if viewModel.isStationary && !viewModel.isCalibrating {
                    stationaryBanner
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
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
            .animation(.easeInOut(duration: 0.3), value: viewModel.isStationary)
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
        .toolbar(.hidden, for: .navigationBar)
        .statusBar(hidden: true)
        .onAppear  { viewModel.onAppear()    }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $showPreferences) { NavigationPreferencesView() }
        .alert(isRO ? "Eroare" : "Error",
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
                Text(isRO ? "Mod Navigare" : "Navigation Mode")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                if viewModel.isRunning && !viewModel.isCalibrating {
                    Label(isRO ? "LiDAR activ" : "LiDAR active",
                          systemImage: "sensor.tag.radiowaves.forward.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Button(action: { showPreferences = true }) {
                Label(isRO ? "Preferințe navigare" : "Navigation settings",
                      systemImage: "gearshape")
                    .labelStyle(.iconOnly)
                    .font(.subheadline.bold())
                    .foregroundStyle(.gray)
                    .padding(8)
                    .background(.white.opacity(0.08), in: Circle())
            }

            Button(action: viewModel.toggleDebug) {
                Label(
                    viewModel.isDebugMode
                        ? (isRO ? "Ascunde heatmap" : "Hide heatmap")
                        : (isRO ? "Arată heatmap"   : "Show heatmap"),
                    systemImage: viewModel.isDebugMode
                        ? "viewfinder.circle.fill"
                        : "viewfinder.circle"
                )
                .labelStyle(.iconOnly)
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.isDebugMode ? .cyan : .gray)
                .padding(8)
                .background(.white.opacity(0.08), in: Circle())
            }

            Button(action: viewModel.toggleAudio) {
                Label(
                    viewModel.isAudioEnabled
                        ? (isRO ? "Dezactivează ghidaj audio" : "Disable audio guidance")
                        : (isRO ? "Activează ghidaj audio"    : "Enable audio guidance"),
                    systemImage: viewModel.isAudioEnabled
                        ? "speaker.wave.3.fill"
                        : "speaker.slash.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.isAudioEnabled ? .yellow : .gray)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: Capsule())
            }
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
                [isRO ? "Stânga" : "Left",
                 isRO ? "Centru" : "Center",
                 isRO ? "Dreapta" : "Right"],
                viewModel.zoneDistances
            )), id: \.0) { label, dist in
                ZoneCell(label: label, distance: dist)
            }
        }
        .accessibilityHidden(true)
    }

    private var stationaryBanner: some View {
        Label(isRO ? "Stai pe loc — Scanare…" : "Stopped — Scanning scene…",
              systemImage: "radar")
            .font(.caption.bold())
            .foregroundStyle(.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.15), in: Capsule())
            .accessibilityLabel(isRO ? "Utilizator oprit" : "User stationary")
    }

    private var debugHeatmapPanel: some View {
        VStack(spacing: 4) {
            // Canvas draws the LiDAR heatmap and overlays YOLO bounding boxes.
            // Note: heatmap (256×192 landscape depth) and YOLO boxes (portrait camera)
            // share the same horizontal axis but differ vertically — treat as approximate.
            Canvas { ctx, size in
                if let img = viewModel.debugHeatmap {
                    ctx.draw(Image(uiImage: img), in: CGRect(origin: .zero, size: size))
                } else {
                    ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(.white.opacity(0.04)))
                }
                for pred in viewModel.rawDetections {
                    guard let box = pred.boundingBox else { continue }
                    // Vision coords (origin bottom-left, y up) → SwiftUI (origin top-left, y down)
                    let rect = CGRect(
                        x: box.minX * size.width,
                        y: (1 - box.maxY) * size.height,
                        width: box.width * size.width,
                        height: box.height * size.height
                    )
                    let color = yoloBoxColor(for: pred.label)
                    ctx.stroke(Path(rect), with: .color(color), lineWidth: 1.5)
                    ctx.draw(
                        Text(pred.label)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(color),
                        at: CGPoint(x: rect.minX + 2, y: rect.minY + 1),
                        anchor: .topLeading
                    )
                }
            }
            .overlay {
                if viewModel.debugHeatmap == nil {
                    Text(isRO ? "Se încarcă…" : "Loading…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            // Depth map is 128×96 with UIImage.orientation .right → displays as portrait 96×128.
            // Fix aspect ratio so the Canvas matches the portrait heatmap instead of
            // stretching to fill the full-width VStack.
            .aspectRatio(CGFloat(96) / CGFloat(128), contentMode: .fit)
            .frame(maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 0) {
                ForEach(Array(zip(["L", "C", "R"], viewModel.zoneDistances)), id: \.0) { lbl, dist in
                    Text(dist.isFinite ? String(format: "%.1f", dist) : "—")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(zoneTextColor(dist))
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 0) {
                ForEach([
                    ("cpu",                      viewModel.sessionAvgLatencyMs, Color.cyan),
                    ("exclamationmark.triangle", "\(viewModel.sessionNearMisses)",
                     viewModel.sessionNearMisses > 0 ? Color.red : Color.white.opacity(0.35)),
                    ("speaker.slash",            viewModel.sessionSupprPct,     Color.green),
                ], id: \.0) { icon, value, color in
                    VStack(spacing: 1) {
                        Text(value)
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(color)
                        Image(systemName: icon)
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var stopButton: some View {
        Button(action: { dismiss() }) {
            Text(isRO ? "Oprește Navigarea" : "Stop Navigation")
                .font(.title2.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .accessibilityLabel(isRO ? "Oprește navigarea" : "Stop navigation")
        .accessibilityHint(isRO ? "Apasă pentru a ieși din modul navigare" : "Tap to exit navigation mode")
    }

    // MARK: - Helpers

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

    private func yoloBoxColor(for label: String) -> Color {
        switch label {
        case "car", "truck", "bus", "motorcycle": return .red
        case "person":                             return .yellow
        case "traffic light":                      return .green
        case "stop sign":                          return .orange
        case "bicycle":                            return .cyan
        case "dog", "cat", "horse":               return .purple
        default:                                   return .white
        }
    }
}

#Preview {
    DepthNavigatorView()
}
