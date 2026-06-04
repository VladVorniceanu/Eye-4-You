//
//  CircleButton.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 02.04.2024.
//

import SwiftUI

struct CircleButton: View {
    var action: () -> Void
    var label: String

    @ScaledMetric private var size: CGFloat = 60

    var body: some View {
        Button(label, action: action)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding()
            .frame(width: size, height: size)
            .background(.quinary.opacity(0.8))
            .clipShape(Circle())
    }
}

#Preview {
    VStack {
        CircleButton(action: {}, label: "0.5x")
    }
}
