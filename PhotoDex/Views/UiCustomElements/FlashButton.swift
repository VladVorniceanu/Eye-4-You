//
//  FlashButton.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.04.2024.
//

import SwiftUI

struct FlashButton: View {
    @ObservedObject var model: CameraViewModel
    var body: some View {
        Button (action: {
            model.switchFlash()
        },
                label: {
            Image(
                systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash.fill"
            )
            .font(
                .system(
                    size: 20,
                    weight: .medium
                )
            )
        }).tint(
            model.isFlashOn ? .yellow : .white
        )
    }
}

