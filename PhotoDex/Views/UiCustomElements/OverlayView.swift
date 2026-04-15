import Foundation
import SwiftUI

struct OverlayView: View, Equatable {
    let predictions: [Prediction]
    let selectedItems: Set<UUID>

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(predictions.enumerated()), id: \.element.id) { index, prediction in
                    if selectedItems.contains(prediction.id), prediction.boundingBox != nil {
                        PredictionOverlayItem(
                            prediction: prediction,
                            index: index,
                            totalCount: predictions.count,
                            geometrySize: geometry.size
                        )
                    }
                }
            }
        }
    }
}

private struct PredictionOverlayItem: View, Equatable {
    let prediction: Prediction
    let index: Int
    let totalCount: Int
    let geometrySize: CGSize

    var body: some View {
        let boundingBox = prediction.boundingBox ?? .zero
        let x = boundingBox.origin.x * geometrySize.width
        let y = (1 - boundingBox.origin.y - boundingBox.size.height) * geometrySize.height
        let width = boundingBox.size.width * geometrySize.width
        let height = boundingBox.size.height * geometrySize.height

        ZStack {
            Rectangle()
                .stroke(color, lineWidth: 2)
                .frame(width: width, height: height)
                .position(x: x + width / 2, y: y + height / 2)

            if let humanAnalysis = prediction.humanAnalysis {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vârsta: \(humanAnalysis.age) ani")
                    Text("Sex: \(humanAnalysis.gender == "Female" ? "Femeie" : "Bărbat")")
                    Text("Emoție: \(humanAnalysis.emotion)")
                }
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .position(x: x + width / 2, y: y + height - 20)
            } else {
                Text("\(prediction.label) \(String(format: "%.2f", prediction.confidence * 100))%")
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .position(x: x + width / 2, y: y + height)
            }
        }
    }

    private var color: Color {
        Color(hue: Double(index) / Double(max(totalCount, 1)), saturation: 1, brightness: 1)
    }
}
