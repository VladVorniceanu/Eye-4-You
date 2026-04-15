import AVFoundation
import SwiftUI
import UIKit

enum Status {
    case configured
    case unconfigured
    case unauthorized
    case failed
}

final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var status = Status.unconfigured
    @Published var shouldShowAlertView = false
    @Published var capturedImage: UIImage?

    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()

    var videoDeviceInput: AVCaptureDeviceInput?
    var position: AVCaptureDevice.Position = .back
    var alertError = AlertError()
    var onFrame: ((CMSampleBuffer) -> Void)?

    private var cameraDelegate: CameraDelegate?
    private let sessionQueue = DispatchQueue(label: "com.PhotoDex.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.PhotoDex.camera.videoOutput", qos: .userInitiated)

    func setUpCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.status == .unconfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.setupVideoInput()
            self.setupPhotoOutput()
            self.setupVideoOutput()
            self.session.commitConfiguration()
            self.startCapturing()
        }
    }

    func startCapturing() {
        if status == .configured {
            sessionQueue.async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        } else if status == .unconfigured || status == .unauthorized {
            DispatchQueue.main.async {
                self.alertError = AlertError(
                    title: "Camera Error",
                    message: "Camera configuration failed. Either your device camera is not available or permissions are missing.",
                    primaryButtonTitle: "OK"
                )
                self.shouldShowAlertView = true
            }
        }
    }

    func stopCapturing() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleTorch(torchIsOn: Bool) {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }

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
            AppLogger.camera.error("Failed to set torch mode: \(error.localizedDescription)")
        }
    }

    func setFocusOnTap(devicePoint: CGPoint) {
        guard let cameraDevice = videoDeviceInput?.device else { return }

        sessionQueue.async {
            do {
                try cameraDevice.lockForConfiguration()

                if cameraDevice.isFocusModeSupported(.autoFocus), cameraDevice.isFocusPointOfInterestSupported {
                    cameraDevice.focusPointOfInterest = devicePoint
                    cameraDevice.focusMode = .autoFocus
                }

                if cameraDevice.isExposurePointOfInterestSupported, cameraDevice.isExposureModeSupported(.autoExpose) {
                    cameraDevice.exposurePointOfInterest = devicePoint
                    cameraDevice.exposureMode = .autoExpose
                }

                cameraDevice.isSubjectAreaChangeMonitoringEnabled = false
                cameraDevice.unlockForConfiguration()
            } catch {
                AppLogger.camera.error("Failed to configure focus: \(error.localizedDescription)")
            }
        }
    }

    func switchCamera() {
        sessionQueue.async {
            guard let currentInput = self.videoDeviceInput else { return }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            self.position = self.position == .back ? .front : .back
            self.setupVideoInput()
            self.session.commitConfiguration()
        }
    }

    func captureImage() async -> UIImage? {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                guard self.session.isRunning, self.session.outputs.contains(self.photoOutput) else {
                    continuation.resume(returning: nil)
                    return
                }

                var photoSettings = AVCapturePhotoSettings()
                if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                }

                if self.videoDeviceInput?.device.isFlashAvailable == true {
                    photoSettings.flashMode = self.flashMode
                }

                photoSettings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                photoSettings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization

                if let previewPixelFormat = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelFormat]
                }

                self.cameraDelegate = CameraDelegate { image in
                    self.capturedImage = image
                    continuation.resume(returning: image)
                }

                guard let cameraDelegate = self.cameraDelegate else {
                    continuation.resume(returning: nil)
                    return
                }

                self.photoOutput.capturePhoto(with: photoSettings, delegate: cameraDelegate)
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }

    private func setupVideoInput() {
        do {
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)

            guard let camera else {
                AppLogger.camera.error("Video device is unavailable")
                status = .unconfigured
                return
            }

            let videoInput = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(videoInput) else {
                AppLogger.camera.error("Could not add video device input")
                status = .failed
                return
            }

            session.addInput(videoInput)
            videoDeviceInput = videoInput
            status = .configured
        } catch {
            AppLogger.camera.error("Could not create video device: \(error.localizedDescription)")
            status = .failed
        }
    }

    private func setupPhotoOutput() {
        guard session.canAddOutput(photoOutput) else {
            AppLogger.camera.error("Could not add photo output to the session")
            status = .failed
            return
        }

        session.addOutput(photoOutput)
        if let supportedMaxPhotoDimensions = videoDeviceInput?.device.activeFormat.supportedMaxPhotoDimensions.last {
            photoOutput.maxPhotoDimensions = supportedMaxPhotoDimensions
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
        status = .configured
    }

    private func setupVideoOutput() {
        guard session.canAddOutput(videoOutput) else {
            AppLogger.camera.error("Could not add video output to the session")
            status = .failed
            return
        }

        session.addOutput(videoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        status = .configured
    }
}

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

public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?

    public init(
        title: String = "",
        message: String = "",
        primaryButtonTitle: String = "Accept",
        secondaryButtonTitle: String? = nil,
        primaryAction: (() -> ())? = nil,
        secondaryAction: (() -> ())? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}
