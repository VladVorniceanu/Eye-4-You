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
    @State private var cameraFrame: CGImage? 
    
    var body: some View{
        if let image = image {
            Image(image, scale: 1.5, orientation: .right, label: label)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.green
        }
    }
}

#Preview {
    FrameView()
}
