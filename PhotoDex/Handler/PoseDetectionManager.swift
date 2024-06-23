//
//  PoseDetectionManager.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 23.06.2024.
//

import Vision
import UIKit

class PoseDetectionManager {
    static let shared = PoseDetectionManager()

    private var poseDetectionRequest: VNDetectHumanBodyPoseRequest!

    init() {
        poseDetectionRequest = VNDetectHumanBodyPoseRequest()
    }

    func detectPose(in image: UIImage, completion: @escaping ([VNHumanBodyPoseObservation.JointName: CGPoint]?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([poseDetectionRequest])
            guard let results = poseDetectionRequest.results as? [VNHumanBodyPoseObservation] else {
                completion(nil)
                return
            }

            var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for result in results {
                guard let recognizedPoints = try? result.recognizedPoints(.all) else { continue }
                for (jointName, point) in recognizedPoints {
                    if point.confidence > 0.1 {
                        points[jointName] = CGPoint(x: point.location.x, y: 1 - point.location.y)
                    }
                }
            }
            completion(points)
        } catch {
            completion(nil)
        }
    }
}
