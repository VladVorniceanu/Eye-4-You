//  YoloCoreML.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 13.04.2024.
//

import Foundation
import CoreML
import Vision
import UIKit

class YoloCoreML {
    
    // MARK: - Core ML Model Creation
    static func createYOLOModel() -> VNCoreMLModel {
        let defaultConfiguration = MLModelConfiguration()
        guard let yoloModel = try? yolov5s(configuration: defaultConfiguration).model else {
            fatalError("Failed to create YOLO model instance")
        }
        guard let yoloVisionModel = try? VNCoreMLModel(for: yoloModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for YOLOv5")
        }
        return yoloVisionModel
    }
    
    // MARK: - Making Predictions Using YOLO Only (Live Camera Feed)
    static func makePredictionsUsingYOLO(for image: UIImage, model: VNCoreMLModel, completionHandler: @escaping (Result<[CustomMLModel.Prediction], Error>) -> Void) {
        guard let cvPixelBuffer = convertToCVPixelBuffer(toConvert: image) else {
            completionHandler(.failure(NSError(domain: "YoloCoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to CVPixelBuffer"])))
            return
        }
        
        let yoloRequest = createYOLOAnalysisRequest(model: model) { predictions, error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            guard let predictions = predictions else {
                completionHandler(.failure(NSError(domain: "YoloCoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "No predictions found"])))
                return
            }
            
            let formattedPredictions = predictions.map { prediction in
                return CustomMLModel.Prediction(label: prediction.labels.first?.identifier ?? "Unknown", confidence: prediction.confidence, boundingBox: prediction.boundingBox)
            }
            
            completionHandler(.success(formattedPredictions))
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBuffer, options: [:])
        let requests: [VNRequest] = [yoloRequest]
        
        do {
            try handler.perform(requests)
        } catch {
            completionHandler(.failure(error))
        }
    }

    private static func createYOLOAnalysisRequest(model: VNCoreMLModel, completion: @escaping ([VNRecognizedObjectObservation]?, Error?) -> Void) -> VNCoreMLRequest {
        let yoloRequest = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                completion(nil, NSError(domain: "YoloCoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "No results from Vision request"]))
                return
            }
            
            completion(results, nil)
        }
        yoloRequest.imageCropAndScaleOption = .scaleFill
        return yoloRequest
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
