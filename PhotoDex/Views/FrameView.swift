//
//  FrameView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

struct FrameView: View {
    var image: CGImage?
    private let label = Text("frame")
    
    var body: some View{
        ZStack {
            if let image = image {
                Image(image, scale: 2, orientation: .up, label: label)
            } else {
                Color.black
            }
        }.ignoresSafeArea()
    }
}

#Preview {
    FrameView()
}
