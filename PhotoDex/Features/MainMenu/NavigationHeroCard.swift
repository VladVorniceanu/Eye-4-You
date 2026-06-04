//
//  NavigationHeroCard.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import SwiftUI

/// Full-width hero card that surfaces LiDAR Navigation as the app's primary feature.
/// Shows a pulsing sensor icon, description, and availability badge.
struct NavigationHeroCard: View {
    let isAvailable: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var isRO: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                sensorIcon
                titleBlock
                Spacer(minLength: 8)
                disclosureIndicator
            }

            Text(isAvailable
                 ? (isRO
                    ? "Ghidaj haptic și audio spațial prin LiDAR. Urmează sunetul pentru a naviga în siguranță."
                    : "Spatial audio and haptic guidance powered by LiDAR. Follow the sound to navigate safely.")
                 : (isRO
                    ? "Necesită iPhone Pro cu senzor LiDAR."
                    : "Requires an iPhone Pro with a LiDAR sensor."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            availabilityBadge
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            if isAvailable {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color.purple.opacity(colorScheme == .dark ? 0.20 : 0.09),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isAvailable ? Color.purple.opacity(0.40) : Color.secondary.opacity(0.15),
                    lineWidth: 1.5
                )
        }
        .shadow(
            color: isAvailable
                ? Color.purple.opacity(colorScheme == .dark ? 0.28 : 0.12)
                : Color.black.opacity(0.04),
            radius: 22,
            y: 10
        )
        .onAppear {
            if isAvailable && !reduceMotion {
                isPulsing = true
            }
        }
    }

    // MARK: - Sub-components

    private var sensorIcon: some View {
        ZStack {
            Circle()
                .fill(isAvailable ? Color.purple.opacity(0.14) : Color.secondary.opacity(0.08))
                .frame(width: 64, height: 64)

            if isAvailable && !reduceMotion {
                Circle()
                    .stroke(Color.purple.opacity(0.38), lineWidth: 2)
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPulsing ? 1.50 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.75)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }

            Image(systemName: isAvailable
                  ? "sensor.tag.radiowaves.forward.fill"
                  : "sensor.tag.radiowaves.forward")
                .font(.title2)
                .foregroundStyle(isAvailable ? Color.purple : Color.secondary)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(isRO ? "MOD NAVIGARE" : "NAVIGATION MODE")
                .font(.caption.bold())
                .foregroundStyle(isAvailable ? Color.purple : Color.secondary)
                .kerning(0.5)

            Text(isRO ? "LiDAR & Ghidaj spațial" : "LiDAR & Spatial Guidance")
                .font(.title3.bold())
                .foregroundStyle(isAvailable ? .primary : .secondary)
        }
    }

    private var disclosureIndicator: some View {
        Image(systemName: isAvailable ? "chevron.right.circle.fill" : "lock.circle.fill")
            .font(.title3)
            .foregroundStyle(isAvailable ? Color.purple : Color.secondary)
    }

    private var availabilityBadge: some View {
        Group {
            if isAvailable {
                Label(isRO ? "LiDAR disponibil" : "LiDAR available",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.13), in: Capsule())
            } else {
                Label(isRO ? "Indisponibil pe acest dispozitiv" : "Unavailable on this device",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.13), in: Capsule())
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NavigationHeroCard(isAvailable: true)
        NavigationHeroCard(isAvailable: false)
    }
    .padding()
}
