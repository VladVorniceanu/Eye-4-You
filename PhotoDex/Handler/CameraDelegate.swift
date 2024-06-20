//
//  CameraDelegate.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 10.04.2024.
//

import Foundation
import AVFoundation
import UIKit
import Photos

class CameraDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("CameraManager: Error while capturing photo: \(error)")
            completion(nil)
            return
        }
        
        if let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) {
            saveImageToGallery(capturedImage)
            print("CameraDelegate: Image captured and processed successfully")
            completion(capturedImage)
        } else {
            print("CameraDelegate: Image data is nil or cannot be created")
            completion(nil)
        }
    }
    
    func saveImageToGallery (_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if success {
                print("Image saved to gallery")
            } else if let error {
                print("Error saving image to gallery: \(error)")
            }
        }
        
    }
}
