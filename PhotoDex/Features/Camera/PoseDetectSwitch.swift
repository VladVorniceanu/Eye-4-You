//
//  PoseDetectSwitch.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 23.06.2024.
//

import SwiftUI

struct PoseDetectSwitch: View {
    var action: () -> Void
    let size = UIScreen.main.bounds.width * 0.175
    
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
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.accent)
                        .font(.system(size: 40))
                        .shadow(color: .gray, radius: 2)
                }
                .font(.system(size: 30))
        }
    }
}


#Preview {
    PoseDetectSwitch(action: {})
}
