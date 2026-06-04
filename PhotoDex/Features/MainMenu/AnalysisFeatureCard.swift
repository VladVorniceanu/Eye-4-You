//
//  AnalysisFeatureCard.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import SwiftUI

/// Secondary-row card used for analysis features: live detection, capture, gallery.
struct AnalysisFeatureCard: View, Equatable {
    let systemImage: String
    let title: String
    let subtitle: String
    let accentColor: Color
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(isDisabled ? 0.06 : 0.13))
                    .frame(width: 52, height: 52)

                if isLoading {
                    ProgressView()
                        .tint(accentColor)
                } else {
                    Image(systemName: systemImage)
                        .font(.title3.bold())
                        .foregroundStyle(isDisabled ? accentColor.opacity(0.4) : accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isDisabled ? .secondary : .primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accentColor.opacity(isDisabled ? 0.08 : 0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
}
