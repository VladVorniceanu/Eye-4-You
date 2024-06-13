//
//  CustomMLModel.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import Foundation
import CoreML
import Vision
import UIKit

class CustomMLModel : ObservableObject {
    static let shared = CustomMLModel() // Singleton instance

    static let yoloModel = createYOLOModel()
    static let mobileNetModel = createMobileNetModel()
    private var predictionHandlers = [VNRequest: ImagePredictionHandler]()

    typealias ImagePredictionHandler = (_ predictions: [Prediction]?) -> Void

    // MARK: - Prediction Structure
    struct Prediction: Equatable, Hashable, Identifiable {
        let id = UUID()
        var label: String
        var confidence: VNConfidence
        var boundingBox: CGRect?
        var contourPath: UIBezierPath?
        var isSelected: Bool = false

        static func ==(lhs: Prediction, rhs: Prediction) -> Bool {
            return lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // MARK: - Creating the Models
    private static func createYOLOModel() -> VNCoreMLModel {
        let defaultConfiguration = MLModelConfiguration()
        guard let yoloModel = try? yolov5s(configuration: defaultConfiguration).model else {
            fatalError("Failed to create YOLO model instance")
        }
        guard let yoloVisionModel = try? VNCoreMLModel(for: yoloModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for YOLOv5")
        }
        return yoloVisionModel
    }

    private static func createMobileNetModel() -> VNCoreMLModel {
        let defaultConfiguration = MLModelConfiguration()
        guard let mobileNetModel = try? MobileNetV2(configuration: defaultConfiguration).model else {
            fatalError("Failed to create MobileNet model instance")
        }
        guard let mobileNetVisionModel = try? VNCoreMLModel(for: mobileNetModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for MobileNetV2")
        }
        return mobileNetVisionModel
    }

    // MARK: - Making Predictions
    func makePredictions(for photo: UIImage, completionHandler: @escaping ImagePredictionHandler) throws {
        let yoloRequest = createYOLOAnalysisRequest()

        predictionHandlers[yoloRequest] = { yoloPredictions in
            guard let yoloPredictions = yoloPredictions else {
                completionHandler(nil)
                return
            }

            self.handleYOLOPredictions(yoloPredictions: yoloPredictions, photo: photo, completionHandler: completionHandler)
        }

        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: photo) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto)
        let requests: [VNRequest] = [yoloRequest]

        try handler.perform(requests)
    }

    private func createYOLOAnalysisRequest() -> VNCoreMLRequest {
        let yoloRequest = VNCoreMLRequest(model: CustomMLModel.yoloModel, completionHandler: visionRequestHandler)
        yoloRequest.imageCropAndScaleOption = .scaleFill
        return yoloRequest
    }

    private func visionRequestHandler(_ request: VNRequest, error: Error?) {
        guard let predictionHandler = predictionHandlers.removeValue(forKey: request) else {
            fatalError("Every request must have a prediction handler.")
        }
        var predictions: [Prediction]? = nil
        defer {
            predictionHandler(predictions)
        }
        if let error = error {
            print("Vision image classification error...\n\n\(error.localizedDescription)")
            return
        }
        if request.results == nil {
            print("Vision request had no results.")
            return
        }
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        predictions = results.filter({ observation in
            observation.confidence >= 0.51
        }).map({ result in
            guard let label = result.labels.first?.identifier else { return Prediction(label: "", confidence: VNConfidence.zero, boundingBox: .zero)}
            let confidence = result.labels.first?.confidence ?? 0.0
            let boundingBox = result.boundingBox
            let predictedObject: Prediction = Prediction(label: label, confidence: confidence, boundingBox: boundingBox)
            return predictedObject
        })
    }

    private func handleYOLOPredictions(yoloPredictions: [Prediction], photo: UIImage, completionHandler: @escaping ImagePredictionHandler) {
        var finalPredictions: [Prediction] = []

        let group = DispatchGroup()

        for yoloPrediction in yoloPredictions {
            group.enter()
            guard let boundingBox = yoloPrediction.boundingBox else {
                print("Bounding box not found for YOLO prediction.")
                group.leave()
                continue
            }

            let croppedImage = cropImage(image: photo, boundingBox: boundingBox)

            do {
                try makeMobileNetPrediction(for: croppedImage) { mobileNetPredictions in
                    if let mobileNetPredictions = mobileNetPredictions, let firstMobileNetPrediction = mobileNetPredictions.first {
                        // Create a copy of the YOLO prediction to modify it
                        var finalPrediction = yoloPrediction
                        finalPrediction.label = firstMobileNetPrediction.label
                        finalPrediction.confidence = firstMobileNetPrediction.confidence
                        finalPredictions.append(finalPrediction)
                    } else {
                        // Handle case where mobileNetPredictions is nil
                        // For now, append yoloPrediction as is
                        finalPredictions.append(yoloPrediction)
                    }
                    group.leave()
                }
            } catch {
                print("Error making MobileNet prediction: \(error)")
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completionHandler(finalPredictions)
        }
    }

    private func makeMobileNetPrediction(for photo: UIImage, completionHandler: @escaping ImagePredictionHandler) throws {
        let mobileNetRequest = createMobileNetAnalysisRequest()

        predictionHandlers[mobileNetRequest] = { mobileNetPredictions in
            if let mobileNetPredictions = mobileNetPredictions, let mobileNetPrediction = mobileNetPredictions.first {
                completionHandler([Prediction(label: mobileNetPrediction.label,
                                               confidence: mobileNetPrediction.confidence,
                                               boundingBox: nil, contourPath: nil, isSelected: false)])
            } else {
                completionHandler(nil)
            }
        }

        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: photo) else {
            throw NSError(domain: "CustomMLModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to pixel buffer"])
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto)
        let requests: [VNRequest] = [mobileNetRequest]

        try handler.perform(requests)
    }

    private func createMobileNetAnalysisRequest() -> VNCoreMLRequest {
        let mobileNetRequest = VNCoreMLRequest(model: CustomMLModel.mobileNetModel, completionHandler: visionRequestHandler)
        mobileNetRequest.imageCropAndScaleOption = .scaleFill
        return mobileNetRequest
    }

    func convertToCVPixelBuffer(toConvert: UIImage) -> CVPixelBuffer? {
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(toConvert.size.width), Int(toConvert.size.height), kCVPixelFormatType_32ARGB, attributes, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(toConvert.size.width), height: Int(toConvert.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: toConvert.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        toConvert.draw(in: CGRect(x: 0, y: 0, width: toConvert.size.width, height: toConvert.size.height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

        return buffer
    }

    private func cropImage(image: UIImage, boundingBox: CGRect) -> UIImage {
        let size = image.size
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        let x = boundingBox.minX * size.width
        let y = (1 - boundingBox.maxY) * size.height

        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        guard let croppedCGImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCGImage)
    }

    private func convertContourToBezierPath(_ contour: VNContour) -> UIBezierPath {
        let path = UIBezierPath()
        let points = contour.normalizedPoints
        for i in 0..<points.count {
            let point = points[i]
            let scaledPoint = CGPoint(x: Int(point.x), y: 1 - Int(point.y))
            if i == 0 {
                path.move(to: scaledPoint)
            } else {
                path.addLine(to: scaledPoint)
            }
        }
        path.close()
        return path
    }
}
