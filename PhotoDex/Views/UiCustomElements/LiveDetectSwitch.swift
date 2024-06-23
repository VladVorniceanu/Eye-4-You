//
//  LiveDetectSwitch.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 22.06.2024.
//

import SwiftUI

struct LiveDetectSwitch: View {
    var action: () -> Void
    let size = UIScreen.main.bounds.width * 0.20
    
    var body: some View {
        Button(action: action) {
            Circle()
                .foregroundStyle(
                    Color.gray.opacity(0.2)
                )
                .frame(
                    width: size,
                    height: size,
                    alignment: .center
                )
                .overlay {
                    Image(systemName: "photo.stack")
                        .foregroundStyle(Color.gray)
                        .overlay {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                                .offset(x: 27, y: -27)
                                .shadow(color: .gray, radius: 3)
                        }
                }
                .font(.system(size: 30))
        }
    }
}

#Preview {
    LiveDetectSwitch(action: {})
}
