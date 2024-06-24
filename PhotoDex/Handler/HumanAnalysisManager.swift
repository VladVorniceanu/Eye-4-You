//
//  HumanAnalysisManager.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 24.06.2024.
//

import Vision
import UIKit

class HumanAnalysisManager {
    //MARK: - Variables
    static let shared = HumanAnalysisManager()
    private var ageRequest: VNCoreMLRequest!
    private var genderRequest: VNCoreMLRequest!
    private var emotionRequest: VNCoreMLRequest!
    private var ageResults: String?
    private var genderResults: String?
    private var emotionResults: String?
    
    //MARK: - Initialisation of the models and the reqests
    init() {
        let defaultConfiguration = MLModelConfiguration()
        
        guard let ageModel = try? AgeNet(configuration: defaultConfiguration).model else {
            fatalError("Failed to create AgeNet model instance")
        }
        guard let ageVisionModel = try? VNCoreMLModel(for: ageModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for AgeNet")
        }
        ageRequest = VNCoreMLRequest(model: ageVisionModel, completionHandler: handleAgeAnalysis)
        
        guard let genderModel = try? GenderNet(configuration: defaultConfiguration).model else {
            fatalError("Failed to create GenderNet model instance")
        }
        guard let genderVisionModel = try? VNCoreMLModel(for: genderModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for GenderNet")
        }
        genderRequest = VNCoreMLRequest(model: genderVisionModel, completionHandler: handleGenderAnalysis)
        
        guard let emotionModel = try? EmotionNet(configuration: defaultConfiguration).model else {
            fatalError("Failed to create AgenNet model instance")
        }
        guard let emotionVisionModel = try? VNCoreMLModel(for: emotionModel) else {
            fatalError("Failed to create a 'VNCoreMlModel' instance for EmotionNet")
        }
        emotionRequest = VNCoreMLRequest(model: emotionVisionModel, completionHandler: handleEmotionAnalysis)
        
    }
    
    //MARK: - Request handlers
    private func handleAgeAnalysis(request: VNRequest, error: Error?) {
        if let results = request.results as? [VNClassificationObservation], let result = results.first {
            ageResults = result.identifier
        }
    }

    private func handleGenderAnalysis(request: VNRequest, error: Error?) {
        if let results = request.results as? [VNClassificationObservation], let result = results.first {
            genderResults = result.identifier
        }
    }

    private func handleEmotionAnalysis(request: VNRequest, error: Error?) {
        if let results = request.results as? [VNClassificationObservation], let result = results.first {
            emotionResults = result.identifier
        }
    }
    
    func analyzeHuman(in image: UIImage, completion: @escaping (HumanAnalysisResult?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        try? handler.perform([ageRequest])
        dispatchGroup.leave()

        dispatchGroup.enter()
        try? handler.perform([genderRequest])
        dispatchGroup.leave()

        dispatchGroup.enter()
        try? handler.perform([emotionRequest])
        dispatchGroup.leave()

        dispatchGroup.notify(queue: .main) {
            if let age = self.ageResults, let gender = self.genderResults, let emotion = self.emotionResults {
                let result = HumanAnalysisResult(age: age, gender: gender, emotion: emotion)
                completion(result)
            } else {
                completion(nil)
            }
        }
    }
}

struct HumanAnalysisResult {
    let age: String
    let gender: String
    let emotion: String
}
