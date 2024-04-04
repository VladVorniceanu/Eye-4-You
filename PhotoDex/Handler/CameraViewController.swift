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

class CameraViewController: NSObject, ObservableObject {
    
    private var captureSession: AVCaptureSession?
    private var delegate: AVCapturePhotoCaptureDelegate?
    
    let output = AVCapturePhotoOutput()
    
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    func start(delegate: AVCapturePhotoCaptureDelegate, completion: @escaping (Error?) -> ()) {
        self.delegate = delegate
        checkPermission(completion: completion)
    }
    
    func checkPermission(completion: @escaping (Error?) -> ()) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        self?.setUpCaptureSession(completion: completion)
                    }
                }
            case .restricted:
                break
            case .denied:
                break
            case .authorized:
                setUpCaptureSession(completion: completion)
            @unknown default:
                break
            }
        }

    func capturePhoto(with settings: AVCapturePhotoSettings = AVCapturePhotoSettings()) {
        output.capturePhoto(with: settings, delegate: delegate!)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    @Published var frame: CGImage?
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    var photoCaptureCompletionHandler: ((CGImage?) -> Void)?
    
//    override init() {
//        self.delegate = delegate
//        super.init()
//        self.checkPermission()
//        
//        sessionQueue.async { [unowned self] in
//            guard permissionGranted else { return }
//            self.setUpCaptureSession()
//            self.captureSession.startRunning()
//        }
//    }
    
    deinit {
        self.stopCaptureSession();
    }
    
    func stopCaptureSession() {
        sessionQueue.sync {
            if captureSession!.isRunning {
                captureSession!.stopRunning()
            }
        }
    }
    
    

    func setUpCaptureSession(completion: @escaping (Error?) -> ()) {
        let session = AVCaptureSession()
        guard permissionGranted else { return }
        
        session.beginConfiguration()
        
        switchAVDevices(.builtInWideAngleCamera)
        
        setUpAVCaptureVideoPreviewLayer(captureSession: session)
        
        if let photoOutput = session.outputs.first(where: { $0 is AVCapturePhotoOutput }) as? AVCapturePhotoOutput {
                // No need to add the output again, it's already added
            } else {
                print("Capture session cannot find photo output")
            }

        session.commitConfiguration()
        session.startRunning()
        self.captureSession = session
    }
    
    func setUpAVCaptureVideoPreviewLayer(captureSession: AVCaptureSession) {
        let cameraLiveFeed = AVCaptureVideoDataOutput()
        cameraLiveFeed.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        guard captureSession.canAddOutput(cameraLiveFeed) else {
            print("Cannot add video output to capture session")
            return
        }
        captureSession.addOutput(cameraLiveFeed)
    }

    
    func switchAVDevices(_ cameraType: AVCaptureDevice.DeviceType) {
        if let captureSession = captureSession {
            sessionQueue.async {
                captureSession.inputs.forEach { input in
                    captureSession.removeInput(input)
                }
                
                // Set the device used (camera/mic)
                guard let avDevice = AVCaptureDevice.default(cameraType,
                                                              for: .video,
                                                              position: .back)
                else { return }
                
                // Get the input from the used device
                guard let avDeviceInput = try? AVCaptureDeviceInput(device: avDevice) else { return }
                
                // Check if the input can be transmitted to the captureSession, else exit the func
                guard captureSession.canAddInput(avDeviceInput) else { return }
                captureSession.addInput(avDeviceInput)
                
                // Add outputs for photos
                let photoOutput = AVCapturePhotoOutput()
                guard captureSession.canAddOutput(photoOutput) else { return }
                captureSession.sessionPreset = .photo
                captureSession.addOutput(photoOutput)
            }
        }
    }
    
//    func capturePhoto(completion: @escaping (CGImage?) -> Void) {
//        guard let photoOutput = captureSession?.outputs.first as? AVCapturePhotoOutput else {
//                completion(nil)
//                print("Photo not taken")
//                return
//            }
//            
//            let settings = AVCapturePhotoSettings()
//            let processor = PhotoCaptureProcessor(with: settings, willCapturePhotoAnimation: {
//                // Add any animations or UI updates before capturing the photo if needed
//            }, livePhotoCaptureHandler: { _ in }, completionHandler: { processor in
//                guard let imageData = processor.photoData else {
//                    completion(nil)
//                    return
//                }
//                
//                // Convert photo data to UIImage
//                guard let uiImage = UIImage(data: imageData) else {
//                    completion(nil)
//                    print("Failed to convert photo data to UIImage")
//                    return
//                }
//                
//                // Convert UIImage to CGImage
//                guard let cgImage = uiImage.cgImage else {
//                    completion(nil)
//                    print("Failed to convert UIImage to CGImage")
//                    return
//                }
//                
//                completion(cgImage)
//            })
//            
//            photoOutput.capturePhoto(with: settings, delegate: processor)
//        }
    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return cgImage
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.frame = cgImage
        }
    }
}

