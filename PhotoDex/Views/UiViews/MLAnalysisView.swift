import SwiftUI
import UIKit

struct MLAnalysisView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var prediction: [CustomMLModel.Prediction] = []
    @State private var analysisErrors: Error?
    @State private var isAnalyzing: Bool = true
    @State private var selectedItems: Set<UUID> = []

    var body: some View {
        NavigationStack {
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
                            List(prediction, id: \.self) { item in
                                HStack {
                                    Toggle(isOn: Binding(
                                        get: { selectedItems.contains(item.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedItems.insert(item.id)
                                            } else {
                                                selectedItems.remove(item.id)
                                            }
                                        }
                                    )) {
                                        VStack(alignment: .leading) {
                                            Text(item.label.capitalized)
                                            Text("\(String(format: "%.2f", (item.confidence) * 100))%")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            .padding(.all, 0)
                        }
                    }
                }
                .onAppear() {
                    performAnalysis()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.all, 0)
            }.navigationTitle("Rezultatele analizei")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Închide") {
                            isPresented = false
                        }
                    }
                }
        }
    }

    private func performAnalysis() {
        let mlModel = CustomMLModel.shared
        DispatchQueue.global(qos: .background).async {
            do {
                try mlModel.makePredictions(for: image) { predictions in
                    DispatchQueue.main.async {
                        if let predictions = predictions {
                            self.prediction = predictions
                            print(predictions)
                            self.isAnalyzing = false
                        } else {
                            self.analysisErrors = NSError(domain: "Prediction Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get predictions."])
                            self.isAnalyzing = false
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.analysisErrors = error
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func predictionOverlay() -> some View {
        GeometryReader { geometry in
            ForEach(prediction.indices, id: \.self) { index in
                let prediction = self.prediction[index]
                
                if selectedItems.contains(prediction.id), let boundingBox = prediction.boundingBox {
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
