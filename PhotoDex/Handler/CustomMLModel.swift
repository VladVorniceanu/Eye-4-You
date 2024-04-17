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

class CustomMLModel {
    private static let imageClassifier = createModel()
    private var predictionHandlers = [VNRequest: ImagePredictionHandler]()
    typealias ImagePredictionHandler = (_ predictions: [Prediction]?) -> Void

    struct Prediction {
        let label: String
        let confidence: VNConfidence
        let boundingBox: CGRect
    }
    
    static func createModel() -> VNCoreMLModel {
        let defaultConfiguration = MLModelConfiguration()
        let imageClassifierWrapper = try? YOLOv3(configuration: defaultConfiguration)
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
        // Start the image classification request.
        try handler.perform(requests)
    }
    
    private func createImageAnalysisRequest() -> VNImageBasedRequest {
        // Create an image classification request with an image classifier model.
        let imageAnalysisRequest = VNCoreMLRequest(model: CustomMLModel.imageClassifier, completionHandler: visionRequestHandler)
        imageAnalysisRequest.imageCropAndScaleOption = .centerCrop
        return imageAnalysisRequest
    }
    
    private func visionRequestHandler(_ request: VNRequest, error: Error?) {
        // Remove the caller's handler from the dictionary and keep a reference to it.
        guard let predictionHandler = predictionHandlers.removeValue(forKey: request) else {
            fatalError("Every request must have a prediction handler.")
        }
        // Start with a `nil` value in case there's a problem.
        var predictions: [Prediction]? = nil
        // Call the client's completion handler after the method returns.
        defer {
            // Send the predictions back to the client.
            predictionHandler(predictions)
        }
        // Check for an error first.
        if let error = error {
            print("Vision image classification error...\n\n\(error.localizedDescription)")
            return
        }
        // Check that the results aren't `nil`.
        if request.results == nil {
            print("Vision request had no results.")
            return
        }
        // Cast the request's results as an `VNClassificationObservation` array.
        guard let observations = request.results as? [VNClassificationObservation] else {
            print("VNRequest produced the wrong result type: \(type(of: request.results)).")
            return
        }
        // Create a prediction array from the observations.
        predictions = observations.map { observation in
            Prediction(label: observation.identifier,
                       confidence: observation.confidence,
                       boundingBox: observation.accessibilityFrame)
        }
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
