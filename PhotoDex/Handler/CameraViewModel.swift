//
//  CameraViewModel.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 05.04.2024.
//

import Combine
import SwiftUI
import Photos
import AVFoundation

class CameraViewModel : ObservableObject {
    
    @ObservedObject var cameraManager = CameraManager()
    @Published var isFlashOn = false
    @Published var showAlertError = false
    @Published var showSettingAlert = false
    @Published var isPermissionGranted: Bool = false
    @Published var capturedImage: UIImage?
    
    var alertError: AlertError!
    var session: AVCaptureSession = .init()
    
    private var cancelables = Set<AnyCancellable>()
    
    init() {
        session = cameraManager.session
    }
    
    deinit {
        cameraManager.stopCapturing()
    }
    
    func setupBindings() {
        cameraManager.$shouldShowAlertView.sink { [weak self] value in
            self?.alertError = self?.cameraManager.alertError
            self?.showAlertError = value
        }
        .store(in: &cancelables)
        
        cameraManager.$capturedImage.sink { [weak self] image in
                    self?.capturedImage = image
                }.store(in: &cancelables)
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
            guard let self else { return }
            if isGranted {
                self.configureCamera()
                DispatchQueue.main.async {
                    self.isPermissionGranted = true
                }
            }
        }
    }
    
    func configureCamera() {
        checkForDevicePermission()
        cameraManager.setUpCaptureSession()
    }
    
    func checkForDevicePermission() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if videoStatus == .authorized {
            isPermissionGranted = true
            cameraManager.setUpCaptureSession()
        } else if videoStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {_ in})
        } else if videoStatus == .denied {
            isPermissionGranted = false
            showSettingAlert = true
        }
        requestGalleryPermission()
    }
    
    func switchFlash() {
        isFlashOn.toggle()
        cameraManager.toggleTorch(torchIsOn: isFlashOn)
    }
    
    func setFocus(point: CGPoint) {
        cameraManager.setFocusOnTap(devicePoint: point)
    }
    
    func switchCamera() {
        cameraManager.position = cameraManager.position == .back ? .front : .back
        cameraManager.switchCamera()
    }
      
    func captureImage(completion: @escaping (CGImage?) -> Void) {
        let permission = checkGalleryPermissionStatus()
        if permission.rawValue != 2 {
            cameraManager.captureImage(completion: completion)
        }
    }
    
    func requestGalleryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            switch status {
                case .authorized:
                    break
                case .denied:
                    self.showSettingAlert = true
                default:
                    break
            }
        }
    }
    func checkGalleryPermissionStatus() -> PHAuthorizationStatus {
       return PHPhotoLibrary.authorizationStatus()
    }
}
