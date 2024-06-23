//
//  CameraSwitchButton.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.04.2024.
//

import SwiftUI

struct CameraSwitchButton: View {
    var action: () -> Void
    let size = UIScreen.main.bounds.width * 0.15
    
    var body: some View {
        Button(action: action,
               label: {
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
                    Image(
                        systemName: "camera.rotate.fill"
                    )
                    .foregroundStyle(.white)
                }
        })
    }
}
#Preview {
    CameraSwitchButton {
    }
}
