//
//  MLAnalysysView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import SwiftUI
import CoreML
import Vision

struct MLAnalysisView: View {
    let image: UIImage
    @State private var prediction: [CustomMLModel.Prediction] = []
    @State private var analysisErrors: Error?
    @State private var isAnalyzing: Bool = true
    
    var body: some View {
        VStack {
            if isAnalyzing {
                ProgressView("Analyzing...")
            } else if let error = analysisErrors {
                Text("Error: \(error.localizedDescription)")
                .foregroundStyle(.red)
            } else {
                Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
//                .frame(width: 416, height: 416)
                .overlay(predictionOverlay())
            }
        }
        .onAppear {
            performAnalysis()
        }
    }
    
    private func performAnalysis() {
        do {
            let mlModel = CustomMLModel()
            try mlModel.makePredictions(for: image) { predictions in
                DispatchQueue.main.async {
                    self.prediction = predictions ?? []
                    print("Predictions: \(self.prediction)")
                    self.isAnalyzing = false
                }
            }
        } catch {
            self.analysisErrors = error
            self.isAnalyzing = false
        }
    }
    
    private func predictionOverlay() -> some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(prediction, id: \.label) { prediction in
                    
                    let boundingBox = prediction.boundingBox
                    let label = prediction.label

                    // Convert the normalized coordinates to the image size.
                    let x = boundingBox.origin.x * geometry.size.width
                    let y = boundingBox.origin.y * geometry.size.height
                    let width = boundingBox.size.width * geometry.size.width
                    let height = boundingBox.size.height * geometry.size.height

                    // Create a rectangle for the bounding box.
                    Rectangle()
                        .path(in: CGRect(x: x, y: y, width: width, height: height))
                        .stroke(Color.red, lineWidth: 2)

                    // Create a text view for the label.
                    Text(label)
                        .position(x: x, y: y)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}
