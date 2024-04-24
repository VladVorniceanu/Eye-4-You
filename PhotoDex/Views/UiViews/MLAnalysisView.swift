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
                .overlay{(predictionOverlay())}
            }
        }
        .onAppear() {
            performAnalysis()
        }
    }
    
    private func performAnalysis() {
        do {
            let mlModel = CustomMLModel()
            try mlModel.makePredictions(for: image) { predictions in
                DispatchQueue.main.async {
                    self.prediction = predictions ?? []
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
            ForEach(prediction.indices, id: \.self) { index in
                let prediction = self.prediction[index]
                let boundingBox = prediction.boundingBox

                // Convert the normalized coordinates to the image size.
                let x = boundingBox.origin.x * geometry.size.width
                let y = (1 - boundingBox.origin.y - boundingBox.size.height) * geometry.size.height
                let width = boundingBox.size.width * geometry.size.width
                let height = boundingBox.size.height * geometry.size.height

                // Create a rectangle for the bounding box.
                Rectangle()
                    .stroke(Color(hue: Double(index) / Double(self.prediction.count), saturation: 1, brightness: 1), lineWidth: 2)
                    .frame(width: width, height: height)
                    .position(x: x + width / 2, y: y + height / 2)

                // Create a text view for the label and confidence.
                Text("\(prediction.label) \(String(format: "%.2f", prediction.confidence * 100))%")
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .position(x: x + width / 2, y: y + height)
            }
        }
    }
}

