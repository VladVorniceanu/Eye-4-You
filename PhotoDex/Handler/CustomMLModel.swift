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
    // MARK: - Properties
    static let shared = CustomMLModel()
    static let yoloModel = createYOLOModel()
    static let mobileNetModel = createMobileNetModel()
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

        static func ==(lhs: Prediction, rhs: Prediction) -> Bool {
            return lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // MARK: - Core ML Model Creation
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

    // MARK: - Making Predictions Using YOLO Only (Live Camera Feed)
    func makePredictionsUsingYOLO(for image: UIImage, completionHandler: @escaping ImagePredictionHandler) {
        guard let cvPixelBuffer = convertToCVPixelBuffer(toConvert: image) else {
            completionHandler(nil)
            return
        }
        
        let yoloRequest = createYOLOAnalysisRequest()
        
        predictionHandlers[yoloRequest] = { yoloPredictions in
            guard let yoloPredictions = yoloPredictions else {
                completionHandler(nil)
                return
            }
            
            let predictions = yoloPredictions.map { prediction in
                return Prediction(label: prediction.label, confidence: prediction.confidence, boundingBox: prediction.boundingBox)
            }
            
            completionHandler(predictions)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBuffer, options: [:])
        let requests: [VNRequest] = [yoloRequest]
        
        do {
            try handler.perform(requests)
        } catch {
            print("Error performing YOLO request: \(error.localizedDescription)")
            completionHandler(nil)
        }
    }
    
    private func createYOLOAnalysisRequest() -> VNCoreMLRequest {
        let yoloRequest = VNCoreMLRequest(model: CustomMLModel.yoloModel, completionHandler: visionRequestHandler)
        yoloRequest.imageCropAndScaleOption = .scaleFill
        return yoloRequest
    }
    
    private func visionRequestHandler(request: VNRequest, error: Error?) {
        guard let predictionHandler = predictionHandlers.removeValue(forKey: request) else {
            fatalError("Every request must have a prediction handler.")
        }
        var predictions: [VNRecognizedObjectObservation]? = nil
        defer {
            predictionHandler(predictions?.map { observation in
                return Prediction(label: observation.labels.first?.identifier ?? "Unknown",
                                  confidence: observation.confidence,
                                  boundingBox: observation.boundingBox)
            })
        }
        
        if let error = error {
            print("Vision request error: \(error.localizedDescription)")
            return
        }
        
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            print("No results from Vision request")
            return
        }
        
        predictions = results
    }

    // MARK: - Making Predictions Using YOLO and MobileNetV2 (Standalone Picture)
    func makePredictionsUsingYOLOAndMobileNet(for image: UIImage, completionHandler: @escaping ImagePredictionHandler) {
        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: image) else {
            completionHandler(nil)
            return
        }
        
        let yoloRequest = createYOLOAnalysisRequest()
        
        predictionHandlers[yoloRequest] = { yoloPredictions in
            guard let yoloPredictions = yoloPredictions else {
                completionHandler(nil)
                return
            }
            
            self.handleYOLOPredictions(yoloPredictions: yoloPredictions, image: image, completionHandler: completionHandler)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto, options: [:])
        let requests: [VNRequest] = [yoloRequest]
        
        do {
            try handler.perform(requests)
        } catch {
            print("Error performing YOLO request: \(error.localizedDescription)")
            completionHandler(nil)
        }
    }
    
    private func handleYOLOPredictions(yoloPredictions: [Prediction], image: UIImage, completionHandler: @escaping ImagePredictionHandler) {
        var finalPredictions: [Prediction] = []
        
        let group = DispatchGroup()
        
        for yoloPrediction in yoloPredictions {
            group.enter()
            
            guard let boundingBox = yoloPrediction.boundingBox else {
                print("Bounding box not found for YOLO prediction")
                group.leave()
                continue
            }
            
            let croppedImage = cropImage(image: image, boundingBox: boundingBox)
            
            do {
                try makeMobileNetPrediction(for: croppedImage) { mobileNetPredictions in
                    if let mobileNetPrediction = mobileNetPredictions?.first {
                        var finalPrediction = yoloPrediction
                        finalPrediction.label = mobileNetPrediction.label
                        finalPrediction.confidence = mobileNetPrediction.confidence
                        finalPredictions.append(finalPrediction)
                    } else {
                        finalPredictions.append(yoloPrediction)
                    }
                    group.leave()
                }
            } catch {
                print("Error making MobileNet prediction: \(error.localizedDescription)")
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
            completionHandler(mobileNetPredictions)
        }
        
        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: photo) else {
            throw NSError(domain: "CustomMLModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to pixel buffer"])
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto, options: [:])
        let requests: [VNRequest] = [mobileNetRequest]
        
        do {
            try handler.perform(requests)
        } catch {
            print("Error performing MobileNet request: \(error.localizedDescription)")
            completionHandler(nil)
        }
    }
    
    private func createMobileNetAnalysisRequest() -> VNCoreMLRequest {
        let mobileNetRequest = VNCoreMLRequest(model: CustomMLModel.mobileNetModel, completionHandler: visionRequestHandler)
        mobileNetRequest.imageCropAndScaleOption = .scaleFill
        return mobileNetRequest
    }
    
    // MARK: - Utility Methods
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

