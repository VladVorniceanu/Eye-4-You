// MobileNetV2CoreML.swift
// PhotoDex
//
// Created by Vlad Vorniceanu on 21.06.2024.
//

import Foundation
import CoreML
import Vision
import UIKit

class MobileNetV2CoreML {

    // MARK: - Core ML Model Creation
    static func createMobileNetModel() -> VNCoreMLModel {
        let defaultConfiguration = MLModelConfiguration()
        guard let mobileNetModel = try? MobileNetV2(configuration: defaultConfiguration).model else {
            fatalError("Failed to create MobileNet model instance")
        }
        guard let mobileNetVisionModel = try? VNCoreMLModel(for: mobileNetModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for MobileNetV2")
        }
        return mobileNetVisionModel
    }

    // MARK: - Making Predictions Using MobileNetV2
    static func makePredictionMobileNetV2(for image: UIImage, model: VNCoreMLModel, completionHandler: @escaping (Result<CustomMLModel.Prediction, Error>) -> Void) {
        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: image) else {
            completionHandler(.failure(NSError(domain: "MobileNetV2CoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to CVPixelBuffer"])))
            return
        }
        
        let mobileNetRequest = createMobileNetAnalysisRequest(model: model) { predictions, error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            guard let predictions = predictions, let highestConfidencePrediction = predictions.max(by: { $0.confidence < $1.confidence }) else {
                completionHandler(.failure(NSError(domain: "MobileNetV2CoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "No predictions found"])))
                return
            }
            
            let formattedPrediction = CustomMLModel.Prediction(label: highestConfidencePrediction.identifier, confidence: highestConfidencePrediction.confidence, boundingBox: nil)
            
            print("Highest Confidence MobileNetV2 Prediction: \(formattedPrediction)")
            completionHandler(.success(formattedPrediction))
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto, options: [:])
        let requests: [VNRequest] = [mobileNetRequest]
        
        do {
            try handler.perform(requests)
        } catch {
            completionHandler(.failure(error))
        }
    }

    private static func createMobileNetAnalysisRequest(model: VNCoreMLModel, completion: @escaping ([VNClassificationObservation]?, Error?) -> Void) -> VNCoreMLRequest {
        let mobileNetRequest = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let results = request.results as? [VNClassificationObservation] else {
                completion(nil, NSError(domain: "MobileNetV2CoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "No results from Vision request"]))
                return
            }
            
            completion(results, nil)
        }
        mobileNetRequest.imageCropAndScaleOption = .centerCrop
        return mobileNetRequest
    }

    // MARK: - Utility Methods
    private static func convertToCVPixelBuffer(toConvert: UIImage) -> CVPixelBuffer? {
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
}
