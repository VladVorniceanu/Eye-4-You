//
//  ShutterButton.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.04.2024.
//

import SwiftUI

struct ShutterButton: View {
    let action: () -> Void
    let size = UIScreen.main.bounds.width * 0.2
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "button.programmable")
                .font(.system(size: CGFloat(size)))
                .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9, opacity: 1))
                .padding(10)
                .shadow(radius: 10)
        }
    }
}

#Preview {
    ShutterButton(action: {})
}
