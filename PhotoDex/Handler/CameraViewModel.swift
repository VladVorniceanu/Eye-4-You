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
    }
    
    func switchFlash() {
        isFlashOn.toggle()
        cameraManager.toggleTorch(torchIsOn: isFlashOn)
    }
    
}
