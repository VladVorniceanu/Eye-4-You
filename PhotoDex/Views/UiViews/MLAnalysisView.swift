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
    @State private var selectedItem: CustomMLModel.Prediction?
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isAnalyzing {
                    ProgressView("Se analizează...")
                } else if let error = analysisErrors {
                    Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
                } else {
                    Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width)
                    .clipped()
                    .overlay{(predictionOverlay())}
                    
                    if !prediction.isEmpty {
                        Text("Apasă pe un element din listă pentru a îl afișa")
                        List(prediction, id: \.self) { item in
                            HStack {
                                Text(item.label.capitalized)
                                Spacer()
                                Text("\(item.confidence*100)%")
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = item
                            }
                        }.padding(.all, 0)
                    }
                }
            }
            .onAppear() {
                performAnalysis()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) 
            .padding(.all, 0)
        }.navigationTitle("Imaginea analizată")
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
                if prediction[index] == selectedItem {
                    let prediction = self.prediction[index]
                let boundingBox = prediction.boundingBox

                let x = boundingBox.origin.x * geometry.size.width
                let y = (1 - boundingBox.origin.y - boundingBox.size.height) * geometry.size.height
                let width = boundingBox.size.width * geometry.size.width
                let height = boundingBox.size.height * geometry.size.height

                Rectangle()
                    .stroke(Color(hue: Double(index) / Double(self.prediction.count), saturation: 1, brightness: 1), lineWidth: 2)
                    .frame(width: width, height: height)
                    .position(x: x + width / 2, y: y + height / 2)

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
}

