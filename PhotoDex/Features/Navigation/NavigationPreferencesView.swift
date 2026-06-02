//
//  NavigationPreferencesView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/31/26.
//

import SwiftUI

struct NavigationPreferencesView: View {

    @AppStorage(NavPreferenceKeys.stepsDetection)  private var stepsEnabled  = true
    @AppStorage(NavPreferenceKeys.yoloDetection)   private var yoloEnabled   = true
    @AppStorage(NavPreferenceKeys.verbosityLevel)  private var verbosityRaw  = NavVerbosityLevel.balanced.rawValue
    @AppStorage("nav.calibrationCompleted")         private var calibrationDone = false

    @Environment(\.dismiss) private var dismiss

    private var isRomanian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $verbosityRaw) {
                        ForEach(NavVerbosityLevel.allCases) { level in
                            Text(level.localizedTitle).tag(level.rawValue)
                        }
                    } label: {
                        Label(
                            isRomanian ? "Anunțuri vocale" : "Voice announcements",
                            systemImage: "waveform"
                        )
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(isRomanian ? "Nivel de verbozitate" : "Verbosity level")
                } footer: {
                    Text(NavVerbosityLevel(rawValue: verbosityRaw)?.localizedDescription ?? "")
                        .font(.footnote)
                }

                Section {
                    Toggle(isOn: $stepsEnabled) {
                        Label(
                            isRomanian ? "Detecție trepte" : "Step detection",
                            systemImage: "stairs"
                        )
                    }

                    Toggle(isOn: $yoloEnabled) {
                        Label(
                            isRomanian ? "Detecție obiecte (YOLO)" : "Object detection (YOLO)",
                            systemImage: "eye.fill"
                        )
                    }
                } header: {
                    Text(isRomanian ? "Funcții de detecție" : "Detection features")
                } footer: {
                    Text(isRomanian
                         ? "Detecția treptelor poate produce alerte false pe teren accidentat. Dezactivează dacă primești avertismente incorecte."
                         : "Step detection may produce false positives on uneven terrain. Disable it if you receive incorrect warnings.")
                        .font(.footnote)
                }

                Section {
                    Button(role: .destructive) {
                        calibrationDone = false
                    } label: {
                        Label(
                            isRomanian ? "Resetează calibrarea" : "Reset calibration",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                } footer: {
                    Text(isRomanian
                         ? "Calibrarea se va relua la următoarea sesiune de navigare."
                         : "Calibration will restart on the next navigation session.")
                        .font(.footnote)
                }
            }
            .navigationTitle(isRomanian ? "Preferințe Navigare" : "Navigation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRomanian ? "Gata" : "Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationPreferencesView()
}
