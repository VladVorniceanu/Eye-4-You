//
//  FocusView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.04.2024.
//

import SwiftUI

struct FocusView: View {
    @Binding var position: CGPoint
    let size = UIScreen.main.bounds.width * 0.2
    var body: some View {
        Circle()
            .frame(width: size, height: size)
            .foregroundColor(.clear)
            .border(.yellow, width: 1.5)
            .position(x: position.x, y: position.y)
    }
}
