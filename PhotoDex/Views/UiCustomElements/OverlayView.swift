//
//  OverlayView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 22.06.2024.
//

import Foundation
import SwiftUI

struct OverlayView: View {
    @Binding var predictions: [CustomMLModel.Prediction]
    @Binding var selectedItems: Set<UUID>

    var body: some View {
        GeometryReader { geometry in
            ForEach(predictions.indices, id: \.self) { index in
                let prediction = predictions[index]

                if let boundingBox = prediction.boundingBox {
                    let x = boundingBox.origin.x * geometry.size.width
                    let y = (1 - boundingBox.origin.y - boundingBox.size.height) * geometry.size.height
                    let width = boundingBox.size.width * geometry.size.width
                    let height = boundingBox.size.height * geometry.size.height

                    Rectangle()
                        .stroke(Color(hue: Double(index) / Double(predictions.count), saturation: 1, brightness: 1), lineWidth: 2)
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
