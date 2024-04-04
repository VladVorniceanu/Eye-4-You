//
//  ShutterButton.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 03.04.2024.
//

import SwiftUI

struct ShutterButton: View {
    let action: () -> Void
    
    var body: some View {
            Button(action: action) {
                Image(systemName: "button.programmable")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9, opacity: 1))
                    .padding(10)
//                    .background(Color.blue)
                    .shadow(radius: 10)
            }
    }
}

#Preview {
    ShutterButton(action: {})
}
