//
//  OnboardingView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import SwiftUI

struct OnboardingView: View {
    var onDismiss: () -> Void

    private var isRO: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color.indigo.opacity(0.06), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection
                        featureCards
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 52)
                    .padding(.bottom, 24)
                }

                startButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                    .padding(.top, 12)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Eye 4 You")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(isRO ? "Asistentul tău vizual" : "Your vision assistant")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(
                isRO
                    ? "Aplicația detectează obstacole, anunță pericolele vocal și haptic, și descrie împrejurimile tale — totul pe dispozitiv, fără cloud."
                    : "The app detects obstacles, announces hazards with speech and haptics, and describes your surroundings — all on-device, no cloud."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
    }

    private var featureCards: some View {
        VStack(spacing: 14) {
            OnboardingCard(
                systemImage: "livephoto",
                accentColor: .blue,
                title: isRO ? "Detecție live" : "Live Detection",
                description: isRO
                    ? "Îndreaptă camera în fața ta. Obstacolele din calea ta sunt anunțate vocal și cu vibrații, în timp real."
                    : "Point the camera ahead. Obstacles in your path are announced with speech and haptic pulses in real time."
            )

            OnboardingCard(
                systemImage: "iphone.gen3.radiowaves.left.and.right",
                accentColor: .indigo,
                title: isRO ? "Scutură pentru descriere" : "Shake to Describe",
                description: isRO
                    ? "Scutură telefonul pentru a auzi o descriere sonoră a tot ce vede camera în jurul tău. Funcționează și când căștile sunt conectate."
                    : "Shake your phone to hear a spoken description of everything the camera sees around you. Works with earphones connected."
            )

            OnboardingCard(
                systemImage: "camera",
                accentColor: .orange,
                title: isRO ? "Analiză foto" : "Photo Analysis",
                description: isRO
                    ? "Fă o fotografie sau alege una din galerie pentru o analiză detaliată cu etichete și poziție pentru fiecare obiect detectat."
                    : "Capture a photo or pick one from your gallery for a detailed analysis with labels and position for every detected object."
            )
        }
    }

    private var startButton: some View {
        Button(action: onDismiss) {
            Text(isRO ? "Să începem" : "Get Started")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRO ? "Să începem" : "Get Started")
        .accessibilityHint(isRO ? "Închide onboarding-ul și deschide aplicația" : "Dismiss onboarding and open the app")
    }
}

private struct OnboardingCard: View {
    let systemImage: String
    let accentColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(0.13))
                    .frame(width: 52, height: 52)
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}
