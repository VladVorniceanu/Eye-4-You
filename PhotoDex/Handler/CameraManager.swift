//
//  CameraManager.swift
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

class CameraManager: NSObject, ObservableObject {
    @Published var isLiveDetectionFlow: Bool = false
    @Published private var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var status = Status.unconfigured
    @Published var shouldShowAlertView = false
    @Published var capturedImage: UIImage? = nil
    @Published var frame: UIImage? = nil
    @Published var predictions: [CustomMLModel.Prediction] = []
    @Published var analysisError: Error? = nil
    private var cameraDelegate: CameraDelegate?
    private let sessionQueue = DispatchQueue(label: "com.PhotoDex.sessionQueue")
    private let queue = DispatchQueue(label: "camera-queue")
    private let customMLModel = CustomMLModel.shared
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    var videoDeviceInput: AVCaptureDeviceInput?
    var position: AVCaptureDevice.Position = .back
    var alertError: AlertError = AlertError()
    
    //MARK: - Setuping session and devices input
    func setUpCaptureSession() {
        self.sessionQueue.async { [weak self] in
            guard let self, self.status == .unconfigured else { return }
            session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.setupVideoInput()
            self.setupPhotoOutput()
            self.setupVideoOutput()
            self.session.commitConfiguration()
            self.startCapturing()
        }
    }

    private func setupVideoInput() {
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
    
    private func setupVideoOutput() {
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            status = .configured
        } else {
            print("CameraManager: could not add video output to the session")
            status = .failed
            session.commitConfiguration()
            return
        }
    }
    
    //MARK: - Functional methods and functions
    func startCapturing() {
        if status == .configured {
            sessionQueue.async {
                self.session.startRunning()
            }
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
        guard let cameraDevice = self.videoDeviceInput?.device else { return }
        sessionQueue.async {
            do {
                try cameraDevice.lockForConfiguration()
                
                if cameraDevice.isFocusModeSupported(.autoFocus) && cameraDevice.isFocusPointOfInterestSupported {
                    cameraDevice.focusPointOfInterest = devicePoint
                    cameraDevice.focusMode = .autoFocus
                }
                
                if cameraDevice.isExposurePointOfInterestSupported && cameraDevice.isExposureModeSupported(.autoExpose) {
                    cameraDevice.exposurePointOfInterest = devicePoint
                    cameraDevice.exposureMode = .autoExpose
                    
                }
                
                cameraDevice.isSubjectAreaChangeMonitoringEnabled = false
                cameraDevice.unlockForConfiguration()
            } catch {
                print("Failed to configure focus: \(error)")
            }
        }
    }
    
    func switchCamera() {
        guard let videoDeviceInput else { return }
        session.removeInput(videoDeviceInput)
        setupVideoInput()
    }
    
    func captureImage(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.session.isRunning else {
                print("CameraManager: Session is not running")
                completion(nil)
                return
            }

            // Check if the photoOutput is properly added to the session
            guard self.session.outputs.contains(self.photoOutput) else {
                print("CameraManager: Photo output is not added to the session")
                completion(nil)
                return
            }
        
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
            
            self.cameraDelegate = CameraDelegate { image in
                if let imagineCapturata = image {
                    self.capturedImage = imagineCapturata
                    print("CameraManager: Image captured successfully")
                    completion(imagineCapturata)
                } else {
                    print("CameraManager: No image captured")
                    completion(nil)
                }
            }
            
            if let cameraDelegate = self.cameraDelegate {
                print("CameraManager: Starting photo capture")
                self.photoOutput.capturePhoto(with: photoSettings, delegate: cameraDelegate)
            } else {
                print("CameraManager: cameraDelegate is nil")
                completion(nil)
            }
        }
    }
}
//MARK: - Extension for CameraManager to handle video output
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        if !isLiveDetectionFlow {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        DispatchQueue.global(qos: .background).async {
            do {
                try self.customMLModel.makePredictions(on: pixelBuffer) { predictions in
                    DispatchQueue.main.async {
                        if let predictions = predictions {
                            self.predictions = predictions
                            self.analysisError = nil
                        } else {
                            self.analysisError = NSError(domain: "Prediction Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get predictions."])
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.analysisError = error
                }
            }
        }
    }
}
//MARK: - Extension of UIImage to create an image from a pixel buffer
extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        self.init(cgImage: cgImage)
    }
}

//MARK: - Declaration of an AlertError type of message
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

