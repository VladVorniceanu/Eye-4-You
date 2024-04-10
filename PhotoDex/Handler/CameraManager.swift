//
//  FrameHandler.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import Foundation
import AVFoundation
import CoreImage
import UIKit
import SwiftUI

enum Status {
    case configured
    case unconfigured
    case unauthorized
    case failed
}

class CameraManager: ObservableObject {
    
    @Published var status = Status.unconfigured
    @Published var shouldShowAlertView = false
    @Published private var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var capturedImage: UIImage? = nil
    
    private var cameraDelegate: CameraDelegate?
    
    var position: AVCaptureDevice.Position = .back
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    var videoDeviceInput: AVCaptureDeviceInput?
    
    private let sessionQueue = DispatchQueue(label: "com.PhotoDex.sessionQueue")
    
    func setUpCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.status == .unconfigured else { return }
            session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.setupVideoInput()
            self.setupPhotoOutput()
            self.session.commitConfiguration()
            self.startCapturing()
        }
    }
        
    private func setupVideoInput() {
        print("setup camera manager")
        do {
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            
            guard let camera else {
                print("CameraManager: Video device is unavailable")
                status = .unconfigured
                session.commitConfiguration()
                return
            }
            
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
                status = .configured
            } else {
                print("CameraManager: Could not add video device input")
                status = .unconfigured
                session.commitConfiguration()
                return
            }
        } catch {
            print("CameraManager: Could not create video device")
            status = .failed
            session.commitConfiguration()
            return
        }
    }
    
    private func setupPhotoOutput() {
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            let supportedMaxPhotoDimensions = self.videoDeviceInput?.device.activeFormat.supportedMaxPhotoDimensions
            photoOutput.maxPhotoDimensions = (supportedMaxPhotoDimensions?.last)!
            photoOutput.maxPhotoQualityPrioritization = .quality
            status = .configured
        } else {
            print("CameraManager: could not add photo output to the session")
            status = .failed
            session.commitConfiguration()
            return
        }
    }
    
    var alertError: AlertError = AlertError()
    
    private func startCapturing() {
        if status == .configured {
            self.session.startRunning()
        } else if status == .unconfigured || status == .unauthorized {
            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or its missing permissions", primaryButtonTitle: "ok", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                self.shouldShowAlertView = true
                print("CameraManager: camera config failed");
                
            }
        }
    }
    
    func stopCapturing() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    func toggleTorch(torchIsOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                flashMode = torchIsOn ? .on : .off
                if torchIsOn {
                    try device.setTorchModeOn(level: 1.0)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("Failed to set torch mode: \(error).")
            }
        } else {
            print("Torch not available for this device")
        }
    }
    
    func setFocusOnTap(devicePoint: CGPoint) {
        print("set focus in manager")
        guard let cameraDevice = self.videoDeviceInput?.device else { return }
        sessionQueue.async {
            do {
                try cameraDevice.lockForConfiguration()
                
                if cameraDevice.isFocusModeSupported(.continuousAutoFocus) && cameraDevice.isFocusPointOfInterestSupported {
                    cameraDevice.focusPointOfInterest = devicePoint
                    cameraDevice.focusMode = .autoFocus
                }
                
                if cameraDevice.isExposurePointOfInterestSupported && cameraDevice.isExposureModeSupported(.autoExpose) {
                    cameraDevice.exposurePointOfInterest = devicePoint
                    cameraDevice.exposureMode = .autoExpose
                    
                }
                
                cameraDevice.isSubjectAreaChangeMonitoringEnabled = true
                cameraDevice.unlockForConfiguration()
            } catch {
                print("Failed to configure focus: \(error)")
            }
        }
    }
    
    func switchCamera() {
        print("switch camera manager")
        guard let videoDeviceInput else { return }
        print("switch camera manager after guard")
        // Remove the current video input
        session.removeInput(videoDeviceInput)
        
        // Add the new video input
        setupVideoInput()
    }
    
    func captureImage() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            var photoSettings = AVCapturePhotoSettings()
            
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoDeviceInput!.device.isFlashAvailable {
                photoSettings.flashMode = self.flashMode
            }
            
            photoSettings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            
            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
            }
            
            photoSettings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization
            
            if let videoConnextion = photoOutput.connection(with: .video), videoConnextion.isVideoRotationAngleSupported(90) {
                videoConnextion.videoRotationAngle = 90
            }
            
            cameraDelegate = CameraDelegate { [weak self] image in
                self?.capturedImage = image
            }
            
            if let cameraDelegate {
                self.photoOutput.capturePhoto(with: photoSettings, delegate: cameraDelegate)
            }
        }
    }
}


public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?
    
    public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}

