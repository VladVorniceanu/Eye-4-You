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
    //MARK: - Variables declaration
    @ObservedObject var cameraManager = CameraManager()
    var session: AVCaptureSession = .init()
    private var cancelables = Set<AnyCancellable>()
    @Published var isFlashOn = false
    @Published var showAlertError = false
    @Published var showSettingAlert = false
    @Published var isPermissionGranted: Bool = false
    @Published var capturedImage: UIImage?
    var alertError: AlertError!
    
    //MARK: - Initialiser and deinitialiser
    init() {
        session = cameraManager.session
    }
    
    deinit {
        cameraManager.stopCapturing()
    }
    
    //MARK: - Configuration Setup
    func setupBindings() {
        cameraManager.$shouldShowAlertView.sink { [weak self] value in
            DispatchQueue.main.async {
                self?.alertError = self?.cameraManager.alertError
                self?.showAlertError = value
            }
        }
        .store(in: &cancelables)
        
        cameraManager.$capturedImage.sink { [weak self] image in
            DispatchQueue.main.async {
                self?.capturedImage = image
            }
        }.store(in: &cancelables)
    }
    
    func configureCamera() {
        checkForDevicePermission()
        cameraManager.setUpCaptureSession()
    }
    
    //MARK: - Permission Requests
    func checkForDevicePermission() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        DispatchQueue.main.async {
            if videoStatus == .authorized {
                self.isPermissionGranted = true
                self.cameraManager.setUpCaptureSession()
            } else if videoStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video, completionHandler: {_ in})
            } else if videoStatus == .denied {
                self.isPermissionGranted = false
                self.showSettingAlert = true
            }
        }
        requestGalleryPermission()
    }
    
    func requestGalleryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            switch status {
            case .authorized:
                break
            case .denied:
                DispatchQueue.main.async {
                    self.showSettingAlert = true
                }
            default:
                break
            }
        }
    }
    
    func checkGalleryPermissionStatus() -> PHAuthorizationStatus {
       return PHPhotoLibrary.authorizationStatus()
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
            guard let self = self else { return }
            if isGranted {
                DispatchQueue.main.async {
                    self.isPermissionGranted = true
                    self.configureCamera()
                }
            } else {
                DispatchQueue.main.async {
                    self.showSettingAlert = true
                }
            }
        }
    }
    
    //MARK: - Functional Methods
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
      
    func captureImage(completion: @escaping (UIImage?) -> Void) {
        let permission = checkGalleryPermissionStatus()
        if permission.rawValue != 2 {
            cameraManager.captureImage(completion: completion)
        }
    }
}
