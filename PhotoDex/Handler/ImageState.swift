//
//  ImageState.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 22.06.2024.
//

import SwiftUI

class ImageState: ObservableObject {
    @Published var uiImage: UIImage?
    @Published var cgImage: CGImage?

    init(uiImage: UIImage? = nil, cgImage: CGImage? = nil) {
        self.uiImage = uiImage
        self.cgImage = cgImage
    }

    func setUIImage(_ image: UIImage) {
        self.uiImage = image
        self.cgImage = image.cgImage
    }

    func setCGImage(_ image: CGImage) {
        self.cgImage = image
        self.uiImage = UIImage(cgImage: image)
    }
}
