//
//  Gallery.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.04.2024.
//

import SwiftUI

struct GalleryThumbnail: View {
    @Binding var image: UIImage?
    let size = UIScreen.main.bounds.width * 0.15
    
    var body: some View {
        if let image {
            Image(
                uiImage: image
            )
            .resizable()
            .aspectRatio(
                contentMode: .fill
            )
            .frame(
                width: size,
                height: size
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
        } else {
            Circle()
                .foregroundStyle(
                    Color.gray.opacity(
                        0.2
                    )
                )
                .frame(
                    width: size,
                    height: size,
                    alignment: .center
                )
                .overlay {
                    Image(
                        systemName: "photo.on.rectangle.fill"
                    )
                    .foregroundStyle(
                        .white
                    )
                }
        }
    }
}
