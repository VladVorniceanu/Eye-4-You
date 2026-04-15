import Foundation
import SwiftUI

struct OverlayView: View, Equatable {
    let predictions: [Prediction]
    let selectedItems: Set<UUID>
    var mirrorHorizontally: Bool = false
    var previewRect: CGRect? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(predictions.enumerated()), id: \.offset) { index, prediction in
                    if selectedItems.contains(prediction.id), prediction.boundingBox != nil {
                        PredictionOverlayItem(
                            prediction: prediction,
                            index: index,
                            totalCount: predictions.count,
                            geometrySize: geometry.size,
                            previewRect: previewDrawingRect(in: geometry.size),
                            mirrorHorizontally: mirrorHorizontally,
                            isPrimary: prediction.id == primaryPrediction?.id
                        )
                    }
                }
            }
        }
    }

    private var primaryPrediction: Prediction? {
        predictions
            .filter { selectedItems.contains($0.id) && $0.boundingBox != nil }
            .max { $0.confidence < $1.confidence }
    }

    private func previewDrawingRect(in geometrySize: CGSize) -> CGRect {
        guard let previewRect, previewRect.width > 0, previewRect.height > 0 else {
            return CGRect(origin: .zero, size: geometrySize)
        }
        return previewRect
    }
}

private struct PredictionOverlayItem: View, Equatable {
    let prediction: Prediction
    let index: Int
    let totalCount: Int
    let geometrySize: CGSize
    let previewRect: CGRect
    let mirrorHorizontally: Bool
    let isPrimary: Bool

    var body: some View {
        let boundingBox = prediction.boundingBox ?? .zero
        let mirroredOriginX = 1 - boundingBox.origin.x - boundingBox.size.width
        let originX = mirrorHorizontally ? mirroredOriginX : boundingBox.origin.x
        let x = previewRect.origin.x + (originX * previewRect.size.width)
        let y = previewRect.origin.y + ((1 - boundingBox.origin.y - boundingBox.size.height) * previewRect.size.height)
        let width = boundingBox.size.width * previewRect.size.width
        let height = boundingBox.size.height * previewRect.size.height

        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(primaryStrokeColor, lineWidth: isPrimary ? 3 : 1.5)
                .frame(width: width, height: height)
                .position(x: x + width / 2, y: y + height / 2)
                .shadow(color: isPrimary ? primaryStrokeColor.opacity(0.45) : .clear, radius: 12)

            Text("\(prediction.label) \(String(format: "%.2f", prediction.confidence * 100))%")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(labelBackground, in: Capsule())
                .position(x: x + width / 2, y: labelPositionY(y: y, height: height))
        }
    }

    private var primaryStrokeColor: Color {
        isPrimary ? .white : Color(hue: Double(index) / Double(max(totalCount, 1)), saturation: 0.75, brightness: 1)
    }

    private var labelBackground: Color {
        Color.black.opacity(0.72)
    }

    private func labelPositionY(y: CGFloat, height: CGFloat) -> CGFloat {
        let candidate = y + height + 18
        let minPosition = y + min(height - 20, 24)
        return min(candidate, max(minPosition, 24))
    }
}
