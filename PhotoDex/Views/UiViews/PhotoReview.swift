//
//  PhotoPreviewView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 04.04.2024.
//

import SwiftUI

struct PhotoReview: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    @State private var showAnalysisView: Bool = false
    @State private var analysisView: MLAnalysisView? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    HStack (spacing: 20) {
                        Button("Retake") {
                            self.isPresented = false;
                        }
                        .padding()
                        .background(Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                        
                        NavigationLink(destination: MLAnalysisView(image: image)) {
                            Text("Analyze image...")
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                        }.padding()
                    }
                } else {
                    Text("No image captured")
                        .font(.title)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}
