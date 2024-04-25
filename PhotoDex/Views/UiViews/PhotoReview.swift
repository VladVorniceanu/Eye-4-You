//
//  PhotoPreviewView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 04.04.2024.
//

import SwiftUI

struct PhotoReview: View {
    var image: UIImage
    @Binding var isPresented: Bool
    @State private var showAnalysisView: Bool = false
    @State private var analysisView: MLAnalysisView? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    
                NavigationLink(destination: MLAnalysisView(image: image)) {
                    Text("Analyze image...")
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                }.padding()
            }
        }
    }
}
