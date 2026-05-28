//
//  SettingsView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import SwiftUI

// Shared key names — used here and read directly from UserDefaults
// by DangerAnnouncer and HapticEngine so they pick up changes at call time.
enum AppSettingsKeys {
    static let speechRateMultiplier    = "eye4you.speechRateMultiplier"
    static let hapticsEnabled          = "eye4you.hapticsEnabled"
    static let peripheralAnnouncements = "eye4you.peripheralAnnouncements"
}

struct SettingsView: View {
    @AppStorage(AppSettingsKeys.speechRateMultiplier)    private var rateMultiplier: Double = 1.0
    @AppStorage(AppSettingsKeys.hapticsEnabled)          private var hapticsEnabled: Bool   = true
    @AppStorage(AppSettingsKeys.peripheralAnnouncements) private var peripheralOn: Bool     = true

    private var isRO: Bool { Locale.preferredLanguages.first?.hasPrefix("ro") == true }

    var body: some View {
        Form {
            Section(isRO ? "Voce" : "Voice") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isRO ? "Viteză voce" : "Speech Speed")
                        .font(.subheadline.weight(.medium))

                    Picker(isRO ? "Viteză voce" : "Speech Speed", selection: $rateMultiplier) {
                        Text(isRO ? "Lent" : "Slow").tag(0.8)
                        Text(isRO ? "Normal" : "Normal").tag(1.0)
                        Text(isRO ? "Rapid" : "Fast").tag(1.2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(isRO ? "Viteză voce" : "Speech speed")
                }
                .padding(.vertical, 4)
            }

            Section(isRO ? "Notificări" : "Alerts") {
                Toggle(isOn: $hapticsEnabled) {
                    Label(
                        isRO ? "Feedback haptic" : "Haptic Feedback",
                        systemImage: "water.waves"
                    )
                }
                .accessibilityHint(isRO
                    ? "Activează sau dezactivează vibrațiile la detectarea unui obstacol"
                    : "Enable or disable vibrations when an obstacle is detected")

                Toggle(isOn: $peripheralOn) {
                    Label(
                        isRO ? "Anunțuri periferice" : "Peripheral Announcements",
                        systemImage: "speaker.wave.2"
                    )
                }
                .accessibilityHint(isRO
                    ? "Anunță și obiectele din afara căii directe de mers"
                    : "Also announce objects outside your direct walking path")
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text(isRO ? "Eye 4 You" : "Eye 4 You")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(isRO ? "Lucrare de dizertație — ASE București" : "Master's thesis — ASE București")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(isRO ? "Setări" : "Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
