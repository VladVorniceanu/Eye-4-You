//
//  MenuLoadingOverlay.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import SwiftUI

/// Full-screen dimmed overlay with a spinner, shown while loading a gallery image.
struct MenuLoadingOverlay: View, Equatable {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(.primary)

                Text(text)
                    .font(.body.bold())
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
