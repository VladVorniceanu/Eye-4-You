//
//  YOLOv3Model.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import Foundation
import CoreML
import Vision
import UIKit
import CoreGraphics

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}

class CustomMLModel {
    private static let imageClassifier = createModel()
    private var predictionHandlers = [VNRequest: ImagePredictionHandler]()
    typealias ImagePredictionHandler = (_ predictions: [Prediction]?) -> Void

    struct Prediction: Equatable, Hashable {
        let label: String
        let confidence: VNConfidence
        let boundingBox: CGRect
        
        static func ==(lhs: Prediction, rhs: Prediction) -> Bool {
            return lhs.label == rhs.label &&
                   lhs.confidence == rhs.confidence &&
                   lhs.boundingBox == rhs.boundingBox
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(label)
            hasher.combine(confidence)
            hasher.combine(boundingBox)
        }
    }
    
    static func createModel() -> VNCoreMLModel {
        let defaultConfiguration = MLModelConfiguration()
        let imageClassifierWrapper = try? yolov5s(configuration: defaultConfiguration)
        guard let imageClassifier = imageClassifierWrapper else {
            fatalError("Failed to create an image classifier instance")
        }
        let imageClassifierModel = imageClassifier.model
        guard let imageClassifierVisionModel = try? VNCoreMLModel(for: imageClassifierModel) else {
            fatalError("App failed to create a `VNCoreMLModel` instance.")
        }
        return imageClassifierVisionModel
    }
    
    func makePredictions(for photo: UIImage, completionHandler: @escaping ImagePredictionHandler) throws {
        let imageAnalysisRequest = createImageAnalysisRequest()
        
        predictionHandlers[imageAnalysisRequest] = completionHandler
        
        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: photo) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto)
        let requests: [VNRequest] = [imageAnalysisRequest]
        
        try handler.perform(requests)
    }
    
    private func createImageAnalysisRequest() -> VNImageBasedRequest {
        let imageAnalysisRequest = VNCoreMLRequest(model: CustomMLModel.imageClassifier, completionHandler: visionRequestHandler)
        return imageAnalysisRequest
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
            let boundedBox = result.boundingBox
            let predictedObject: Prediction = Prediction(label: label, confidence: confidence, boundingBox: boundedBox)
            return predictedObject
        })
        print(predictions ?? "No predictions")
    }
    
    func convertToCVPixelBuffer(toConvert: UIImage) -> CVPixelBuffer? {
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(toConvert.size.width), Int(toConvert.size.height), kCVPixelFormatType_32ARGB, attributes, &pixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(toConvert.size.width), height: Int(toConvert.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: toConvert.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        toConvert.draw(in: CGRect(x: 0, y: 0, width: toConvert.size.width, height: toConvert.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}
