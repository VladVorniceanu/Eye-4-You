//
//  CircleButton.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 02.04.2024.
//

import SwiftUI

import SwiftUI

struct CircleButton: View {
    var action: () -> Void
    var label: String
    let size = UIScreen.main.bounds.width * 0.2

    var body: some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(.white)
                .font(.custom("eu", size: 9))
                .padding()
                .frame(width: CGFloat(size), height: CGFloat(size))
                .background(.quinary.opacity(0.8))
                .clipShape(Circle())
        }
    }
}


#Preview {
    VStack {
        CircleButton(action: {}, label: "0.5x")
    }}
