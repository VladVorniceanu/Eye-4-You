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
    @Published var isLiveDetectionRunning = false
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
        checkAndRequestPermissions()
        cameraManager.setUpCaptureSession()
    }
    
    //MARK: - Permission Requests
    func checkAndRequestPermissions() {
            PermissionsManager.shared.checkAndRequestCameraPermission { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.isPermissionGranted = true
                        self.cameraManager.setUpCaptureSession()
                    } else {
                        self.showSettingAlert = true
                    }
                }
            }

            PermissionsManager.shared.checkAndRequestGalleryPermission { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if !granted {
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
    
    func toggleLiveDetection() {
        DispatchQueue.main.async {
            self.isLiveDetectionRunning.toggle()
            self.cameraManager.isLiveDetectionFlow = self.isLiveDetectionRunning
        }
    }
      
    func captureImage(completion: @escaping (UIImage?) -> Void) {
        let permission = PermissionsManager.shared.checkGalleryPermissionStatus()
        if permission.rawValue != 2 {
            cameraManager.captureImage(completion: completion)
        }
    }
}
