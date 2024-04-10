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
    var size: Int
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(.white)
                .font(.custom("eu", size: 9))
                .padding()
                .frame(width: CGFloat(size), height: CGFloat(size))
                .background(.quinary .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/))
                .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
        }
    }
}

struct ShutterButton: View {
    let action: () -> Void
    var size: Int
    
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
    VStack {
        CircleButton(action: {}, label: "0.5x", size: 50)
        ShutterButton(action: {}, size: 40)
    }
    
}
