import CoreML
import ImageIO
import UIKit
import Vision

enum YoloCoreML {
    static func createYOLOModel() throws -> VNCoreMLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        return try VNCoreMLModel(for: yolo11n(configuration: configuration).model)
    }

    static func makePredictionsUsingYOLO(
        for image: UIImage,
        model: VNCoreMLModel
    ) throws -> [Prediction] {
        guard let fixedImage = image.fixedOrientation(), let cgImage = fixedImage.cgImage else {
            throw NSError(domain: "YoloCoreML", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }

        return try performRequest(
            model: model,
            handler: VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        )
    }

    static func makePredictionsUsingYOLO(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        model: VNCoreMLModel
    ) throws -> [Prediction] {
        try performRequest(
            model: model,
            handler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        )
    }

    // yolo11n outputs a raw [1, 84, 8400] tensor — no Vision NMS pipeline.
    private static func performRequest(model: VNCoreMLModel, handler: VNImageRequestHandler) throws -> [Prediction] {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        try handler.perform([request])

        guard
            let observation = request.results?.first as? VNCoreMLFeatureValueObservation,
            let multiArray = observation.featureValue.multiArrayValue
        else { return [] }

        return decodeYOLO11Output(multiArray)
    }

    // MARK: - YOLO11n decoder

    private static let confidenceThreshold: Float = 0.50
    private static let iouThreshold: Float = 0.45
    private static let inputSize: Float = 640.0

    private static let cocoNames: [Int: String] = [
        0: "person", 1: "bicycle", 2: "car", 3: "motorcycle", 4: "airplane",
        5: "bus", 6: "train", 7: "truck", 8: "boat", 9: "traffic light",
        10: "fire hydrant", 11: "stop sign", 12: "parking meter", 13: "bench",
        14: "bird", 15: "cat", 16: "dog", 17: "horse", 18: "sheep", 19: "cow",
        20: "elephant", 21: "bear", 22: "zebra", 23: "giraffe", 24: "backpack",
        25: "umbrella", 26: "handbag", 27: "tie", 28: "suitcase", 29: "frisbee",
        30: "skis", 31: "snowboard", 32: "sports ball", 33: "kite",
        34: "baseball bat", 35: "baseball glove", 36: "skateboard",
        37: "surfboard", 38: "tennis racket", 39: "bottle", 40: "wine glass",
        41: "cup", 42: "fork", 43: "knife", 44: "spoon", 45: "bowl",
        46: "banana", 47: "apple", 48: "sandwich", 49: "orange", 50: "broccoli",
        51: "carrot", 52: "hot dog", 53: "pizza", 54: "donut", 55: "cake",
        56: "chair", 57: "couch", 58: "potted plant", 59: "bed",
        60: "dining table", 61: "toilet", 62: "tv", 63: "laptop", 64: "mouse",
        65: "remote", 66: "keyboard", 67: "cell phone", 68: "microwave",
        69: "oven", 70: "toaster", 71: "sink", 72: "refrigerator", 73: "book",
        74: "clock", 75: "vase", 76: "scissors", 77: "teddy bear",
        78: "hair drier", 79: "toothbrush"
    ]

    // Output shape [1, 84, 8400]: axis-1 = 4 box coords + 80 class scores, axis-2 = anchors.
    // Coordinates are absolute pixels in the 640×640 input space (cx, cy, w, h).
    // Class scores are post-sigmoid; no separate objectness score in YOLO v8/v11.
    private static func decodeYOLO11Output(_ array: MLMultiArray) -> [Prediction] {
        let numAnchors = 8400
        let numFeatures = 84

        guard array.count == numAnchors * numFeatures else {
            AppLogger.analysis.error("Unexpected yolo11n output shape: \(array.shape)")
            return []
        }

        let ptr = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        let s1 = array.strides[1].intValue  // stride along feature axis  (= 8400)
        let s2 = array.strides[2].intValue  // stride along anchor axis   (= 1)

        var candidates: [Prediction] = []

        for i in 0 ..< numAnchors {
            var bestScore: Float = 0
            var bestClass = 0
            for c in 4 ..< numFeatures {
                let score = ptr[s1 * c + s2 * i]
                if score > bestScore {
                    bestScore = score
                    bestClass = c - 4
                }
            }

            guard bestScore >= confidenceThreshold else { continue }

            let cx = ptr[s2 * i]
            let cy = ptr[s1 * 1 + s2 * i]
            let w  = ptr[s1 * 2 + s2 * i]
            let h  = ptr[s1 * 3 + s2 * i]

            let cxN = cx / inputSize
            let cyN = cy / inputSize
            let wN  = w  / inputSize
            let hN  = h  / inputSize

            // Convert to Vision normalised coordinates (bottom-left origin, y-axis flipped)
            let box = CGRect(
                x: CGFloat(cxN - wN / 2),
                y: CGFloat(1.0 - cyN - hN / 2),
                width: CGFloat(wN),
                height: CGFloat(hN)
            )

            let label = cocoNames[bestClass] ?? "class_\(bestClass)"
            candidates.append(Prediction(label: label, confidence: bestScore, boundingBox: box))
        }

        return nonMaxSuppression(candidates)
    }

    private static func nonMaxSuppression(_ predictions: [Prediction]) -> [Prediction] {
        let sorted = predictions.sorted { $0.confidence > $1.confidence }
        var kept: [Prediction] = []

        for candidate in sorted {
            let suppressed = kept.contains {
                guard let a = $0.boundingBox, let b = candidate.boundingBox else { return false }
                return $0.label == candidate.label && iou(a, b) > iouThreshold
            }
            if !suppressed { kept.append(candidate) }
        }
        return kept
    }

    private static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let inter = a.intersection(b)
        guard !inter.isNull else { return 0 }
        let interArea = Float(inter.width * inter.height)
        let unionArea = Float(a.width * a.height) + Float(b.width * b.height) - interArea
        return unionArea > 0 ? interArea / unionArea : 0
    }
}
