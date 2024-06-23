//
//  PermissionsManager.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 22.06.2024.
//

import AVFoundation
import PhotosUI

class PermissionsManager {
    static let shared = PermissionsManager()

    func checkAndRequestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.global(qos: .background).async {
            switch status {
            case .authorized:
                completion(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            case .denied, .restricted:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
        
    }

    func checkAndRequestGalleryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        DispatchQueue.global(qos: .background).async {
            switch status {
            case .authorized, .limited:
                completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    DispatchQueue.main.async {
                        completion(newStatus == .authorized || newStatus == .limited)
                    }
                }
            case .denied, .restricted:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
    
    func checkGalleryPermissionStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }
}
