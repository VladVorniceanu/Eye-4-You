import Foundation
import Vision
import UIKit

class ObjectDetector {
    private var request: VNCoreMLRequest!
    private var contourRequest: VNDetectContoursRequest!

    // MARK: - Prediction structure
    struct Prediction: Identifiable, Equatable{
        let id = UUID()
        let label: String
        let confidence: VNConfidence
        var boundingBox: CGRect?
        var contours: [VNContour]?
        
    }

    init() {
        // Initialize the Vision Core ML model for object detection
        do {
            // Load the Core ML model
            guard let model = try? MobileNetV2(configuration: MLModelConfiguration()).model else {
                fatalError("Failed to load MobileNetV2 model")
            }

            // Create VNCoreMLModel instance
            let visionModel = try VNCoreMLModel(for: model)
            
            // Create VNCoreMLRequest
            request = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                self.processObservations(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFill

            // Initialize the Vision Contour detection request
            contourRequest = VNDetectContoursRequest(completionHandler: { (request, error) in
                self.processContours(for: request, error: error)
            })
            contourRequest.maximumImageDimension = 512 // Example of setting properties specific to VNDetectContoursRequest

        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }

    // MARK: - Prediction making
    func makePredictions(for photo: UIImage, completionHandler: @escaping ([Prediction]?) -> Void) {
        guard let cvPixelBufferPhoto = convertToCVPixelBuffer(toConvert: photo) else {
            completionHandler(nil)
            return
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: cvPixelBufferPhoto)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([self.request, self.contourRequest])
            } catch {
                print("Failed to perform Vision request: \(error.localizedDescription)")
                completionHandler(nil)
                return
            }
        }
    }

    private func processObservations(for request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            print("Vision object detection request failed to return results.")
            return
        }

        var predictions: [Prediction] = []

        for observation in observations {
            let label = observation.labels.first?.identifier ?? ""
            let confidence = observation.confidence
            let boundingBox = observation.boundingBox

            let prediction = Prediction(label: label, confidence: confidence, boundingBox: boundingBox, contours: nil)
            predictions.append(prediction)
        }

        DispatchQueue.main.async {
            // Call the completion handler with the predictions
            print("Object predictions:", predictions)
        }
    }

    private func processContours(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNContoursObservation] else {
            print("Vision contour detection request failed to return results.")
            return
        }

        var predictions: [Prediction] = []

        for result in results {
            let contours = result.topLevelContours
            for contour in contours {
                let prediction = Prediction(label: "Contour", confidence: 1.0, boundingBox: nil, contours: [contour])
                predictions.append(prediction)
            }
        }

        DispatchQueue.main.async {
            // Call the completion handler with the contour predictions
            print("Contour predictions:", predictions)
        }
    }

    func convertToCVPixelBuffer(toConvert: UIImage) -> CVPixelBuffer? {
        guard let image = toConvert.cgImage else {
            return nil
        }

        let width = image.width
        let height = image.height

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        guard let ctx = context else {
            return nil
        }

        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(ctx)
        toConvert.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}
