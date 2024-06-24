//  CustomMLModel.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import Foundation
import CoreML
import Vision
import UIKit

class CustomMLModel: ObservableObject {
    // MARK: - Properties
    static let shared = CustomMLModel()
    static var yoloModel: VNCoreMLModel!
    static var mobileNetModel: VNCoreMLModel!
    private static let modelLoadingGroup = DispatchGroup()

    private var predictionHandlers = [VNRequest: ImagePredictionHandler]()
    typealias ImagePredictionHandler = ([Prediction]?) -> Void

    // MARK: - Prediction Structure
    struct Prediction: Equatable, Hashable, Identifiable {
        let id = UUID()
        var label: String
        var confidence: VNConfidence
        var boundingBox: CGRect?
        var contourPath: UIBezierPath?
        var isSelected: Bool = false
        var humanAnalysis: HumanAnalysisResult?

        static func ==(lhs: Prediction, rhs: Prediction) -> Bool {
            return lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    // MARK: - Initialization
    static func initializeModels(completion: @escaping (Bool) -> Void) {
        modelLoadingGroup.enter()
        DispatchQueue.global().async {
            yoloModel = YoloCoreML.createYOLOModel()
            modelLoadingGroup.leave()
        }

        modelLoadingGroup.enter()
        DispatchQueue.global().async {
            mobileNetModel = MobileNetV2CoreML.createMobileNetModel()
            modelLoadingGroup.leave()
        }

        modelLoadingGroup.notify(queue: .main) {
            let modelsLoaded = (yoloModel != nil && mobileNetModel != nil)
            completion(modelsLoaded)
        }
    }

    
    // MARK: - Combined Predictions
    func makePredictionsUsingYOLOAndMobileNet(for image: UIImage, completionHandler: @escaping ([CustomMLModel.Prediction]?) -> Void) {
        // Wait for the models to be ready
        CustomMLModel.modelLoadingGroup.notify(queue: .main) {
            // Utilize YOLO for initial object detection
            YoloCoreML.makePredictionsUsingYOLO(for: image, model: CustomMLModel.yoloModel) { result in
                switch result {
                case .success(let yoloPredictions):
                    print("YOLO Predictions: \(yoloPredictions)\n\n")
                    guard !yoloPredictions.isEmpty else {
                        completionHandler(nil) // No objects detected by YOLO
                        return
                    }

                    // Create a dispatch group to handle the MobileNet and Human Analysis predictions
                    let dispatchGroup = DispatchGroup()
                    var finalPredictions: [CustomMLModel.Prediction] = []

                    for yoloPrediction in yoloPredictions {
                        guard let boundingBox = yoloPrediction.boundingBox else {
                            finalPredictions.append(yoloPrediction)
                            continue
                        }

                        // Add a 10px padding around the bounding box
                        let croppedImage = self.cropImage(image: image, boundingBox: boundingBox, padding: 10)

                        dispatchGroup.enter()
                        if yoloPrediction.label == "person" {
                            HumanAnalysisManager.shared.analyzeHuman(in: croppedImage) { humanAnalysisResult in
                                var updatedPrediction = yoloPrediction
                                updatedPrediction.humanAnalysis = humanAnalysisResult
                                finalPredictions.append(updatedPrediction)
                                dispatchGroup.leave()
                            }
                        } else {
                            MobileNetV2CoreML.makePredictionMobileNetV2(for: croppedImage, model: CustomMLModel.mobileNetModel) { mobileNetResult in
                                switch mobileNetResult {
                                case .success(let mobileNetPrediction):
                                    print("MobileNet Prediction for cropped image: \(mobileNetPrediction)\n\n")
                                    var updatedPrediction = yoloPrediction
                                    updatedPrediction.label = mobileNetPrediction.label
                                    updatedPrediction.confidence = mobileNetPrediction.confidence
                                    finalPredictions.append(updatedPrediction)
                                case .failure(let error):
                                    print("MobileNet prediction failed: \(error.localizedDescription)\n\n")
                                    finalPredictions.append(yoloPrediction)
                                }
                                dispatchGroup.leave()
                            }
                        }
                    }

                    dispatchGroup.notify(queue: .main) {
                        print("Final Combined Predictions: \(finalPredictions)\n\n")
                        completionHandler(finalPredictions)
                    }

                case .failure(let error):
                    print("YOLO prediction failed: \(error.localizedDescription)\n\n")
                    completionHandler(nil)
                }
            }
        }
    }

    // Utility method for cropping the image with padding
    private func cropImage(image: UIImage, boundingBox: CGRect, padding: CGFloat) -> UIImage {
        let size = image.size
        let x = max(boundingBox.origin.x * size.width - padding, 0)
        let y = max((1 - boundingBox.maxY) * size.height - padding, 0)
        let width = min(boundingBox.width * size.width + padding * 2, size.width - x)
        let height = min(boundingBox.height * size.height + padding * 2, size.height - y)

        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        guard let croppedCGImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCGImage)
    }
}
