//
//  MLAnalysysView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import SwiftUI
import CoreML
import Vision

struct MLAnalysysView: View {
    let image: UIImage
    @State private var prediction: [CustomMLModel.Prediction] = []
    @State private var analysisErrors: Error?
    
    var body: some View {
        VStack {
            if prediction.isEmpty {
                if let error = analysisErrors {
                    Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
                } else {
                    ProgressView("Analyzing...")
                }
            } else {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 416, height: 416)
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
                }
            }
        } catch {
            self.analysisErrors = error
        }
    }
    
    private func predictionOverlay() -> some View {
        return GeometryReader { geometry in
            ZStack {
                ForEach(prediction, id: \.label) { prediction in
                    Text("\(prediction.label)")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
    }
}
