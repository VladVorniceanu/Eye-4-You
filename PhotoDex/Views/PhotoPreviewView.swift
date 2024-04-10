//
//  PhotoPreviewView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 04.04.2024.
//

import SwiftUI

struct PhotoPreviewView: View {
    @Binding var image: CGImage?
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                HStack (spacing: 20) {
                    Button("Retake") {
                        self.isPresented = false;
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(.red)
                    .cornerRadius(10)
                    
                    Button("Accept") {
                        
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(.green)
                    .cornerRadius(10)
                }
            } else {
                Text("No image captured")
                    .font(.title)
                    .foregroundStyle(.primary)
            }
        }
    }
}
