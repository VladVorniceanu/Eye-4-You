//
//  FocusView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.04.2024.
//

import SwiftUI

struct FocusView: View {
    @Binding var position: CGPoint

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 76, height: 76)
            .shadow(color: .yellow.opacity(0.35), radius: 8)
            .position(x: position.x, y: position.y)
    }
}
