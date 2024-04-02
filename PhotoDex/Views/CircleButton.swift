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
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(.white)
                .font(.custom("eu", size: 9))
                .padding()
                .frame(width: 50, height: 50)
                .background(.quinary .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/))
                .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
        }
    }
}

#Preview {
    CircleButton(action: {}, label: "0.5x")
}
