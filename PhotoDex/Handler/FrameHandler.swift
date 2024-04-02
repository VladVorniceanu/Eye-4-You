//
//  FrameHandler.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import Foundation
import AVFoundation
import CoreImage

class FrameHandler: NSObject, ObservableObject {
    @Published var frame: CGImage?
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    private var currentCamera: AVCaptureDevice?
    
    override init() {
        super.init()
        self.checkPermission()
        sessionQueue.async { [unowned self] in
            self.setUpCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    deinit {
        self.stopCaptureSession();
    }
    
    func stopCaptureSession() {
        sessionQueue.sync {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
        case .notDetermined:
            self.requestPermission()
            
        default:
            self.permissionGranted = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
        }
    }

    func setUpCaptureSession() {
        // Set up the capture session.
        
        guard permissionGranted else { return }
        
        captureSession.beginConfiguration()
        switchToCamera(.builtInWideAngleCamera)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        guard captureSession.canAddOutput(videoOutput) else {
            print("Cannot add video output to capture session")
            return
        }
        captureSession.addOutput(videoOutput)

        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    
    func switchToCamera(_ cameraType: AVCaptureDevice.DeviceType) {
        sessionQueue.async {
            self.captureSession.inputs.forEach { input in
                self.captureSession.removeInput(input)
            }
            
            guard let videoDevice = AVCaptureDevice.default(cameraType, for: .video, position: .back) else { return }
            guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {return}
            guard self.captureSession.canAddInput(videoDeviceInput) else {return}
            
            self.captureSession.addInput(videoDeviceInput)
            self.currentCamera = videoDevice
        }
    }
  
}

extension FrameHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.frame = cgImage
        }
    }
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return nil}
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return cgImage
    }
}
