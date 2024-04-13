//
//  MLAnalysysView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import SwiftUI

struct MLAnalysysView: View {
    let image: UIImage
    @State private var prediction: [YOLOv3Model.Prediction] = []
    @State private var analysisErrors: Error?
    
    var body: some View {
        VStack {
            if prediction.isEmpty {
                if let error = analysisErrors {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                } else {
                    Text("analyzing...")
                }
            } else {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(predictionOverlay())
            }
        }
        .onAppear {
            performAnalysis()
        }
    }
    
    private func performAnalysis() {
        do {
        let yoloModel = YOLOv3Model()
            try yoloModel.makePredictions(for: image) { predictions in
                DispatchQueue.main.async {
                    self.prediction = predictions ?? []
                }
            }
        } catch {
            self.analysisErrors = error
        }
    }
    private func predictionOverlay() -> some View {
            // You can customize this function to display the predictions in any way you like
            // For example, you can draw bounding boxes around detected objects
            // Or you can simply display the predictions as text overlay
            // Here, I'm displaying the predictions as a list of text views
            return VStack(alignment: .leading, spacing: 5) {
                ForEach(prediction, id: \.clasiffication) { prediction in
                    Text("\(prediction.clasiffication): \(prediction.confidencePercentage)")
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(10)
        }
    }
    

