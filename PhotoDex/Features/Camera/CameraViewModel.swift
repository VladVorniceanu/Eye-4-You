//
//  CameraViewModel.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/18/26.
//

import AVFoundation
import PhotosUI
import SwiftUI
import Vision

@MainActor
final class CameraViewModel: ObservableObject {
    let session: AVCaptureSession
    let isLiveDetectionFlow: Bool

    @Published var isFlashOn = false
    @Published private(set) var isUsingFrontCamera = false
    @Published var showAlertError = false
    @Published var showSettingAlert = false
    @Published var selectedImage: UIImage?
    @Published var isLiveDetectionRunning = false
    @Published var isPoseDetectionRunning = false
    @Published var predictions: [Prediction] = []
    @Published var posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var selectedItems: Set<UUID> = []
    @Published var analysisError: String?
    @Published var isLoadingImage = false
    @Published var loadingMessage = "Se incarca imaginea..."
    @Published var showingPhotoReview = false
    @Published var focusIndicator = FocusIndicatorState(point: .zero, isVisible: false)
    @Published var selectedLiveAnalysisRate: LiveAnalysisRate = .ten
    @Published var pickerItem: PhotosPickerItem? {
        didSet {
            guard let pickerItem else { return }
            Task {
                await loadPhoto(from: pickerItem)
            }
        }
    }

    var alertError = AlertError()

    private let cameraManager: CameraManager
    private let permissionsManager: PermissionsManager
    private let mlFacade: CustomMLModel
    private let dangerAnnouncer = DangerAnnouncer.shared

    private var hasAppeared = false
    private var isAnalyzingFrame = false
    private var isDescribingScene = false

    init(
        isLiveDetectionFlow: Bool,
        cameraManager: CameraManager = CameraManager(),
        permissionsManager: PermissionsManager = .shared,
        mlFacade: CustomMLModel = .shared
    ) {
        self.cameraManager = cameraManager
        self.permissionsManager = permissionsManager
        self.mlFacade = mlFacade
        self.session = cameraManager.session
        self.isLiveDetectionFlow = isLiveDetectionFlow
        self.isLiveDetectionRunning = isLiveDetectionFlow
        self.mlFacade.updateLiveAnalysisRate(selectedLiveAnalysisRate)

        self.cameraManager.onFrame = { [weak self] sampleBuffer in
            Task { @MainActor [weak self] in
                await self?.handleIncomingFrame(sampleBuffer)
            }
        }
    }

    deinit {
        cameraManager.stopCapturing()
    }

    func onAppear() {
        guard !hasAppeared else { return }
        hasAppeared = true

        Task {
            async let cameraAccess = permissionsManager.requestCameraAccess()
            async let galleryAccess = permissionsManager.requestGalleryAccess()
            async let modelsReady = mlFacade.warmUp()

            let hasCameraAccess = await cameraAccess
            let hasGalleryAccess = await galleryAccess
            let _ = await modelsReady

            if hasCameraAccess {
                cameraManager.setUpCaptureSession()
            } else {
                showSettingAlert = true
            }

            if !hasGalleryAccess {
                showSettingAlert = true
            }
        }
    }

    func switchFlash() {
        isFlashOn.toggle()
        cameraManager.toggleTorch(torchIsOn: isFlashOn)
    }

    func setFocus(previewPoint: CGPoint, devicePoint: CGPoint) {
        cameraManager.setFocusOnTap(devicePoint: devicePoint)
        focusIndicator = FocusIndicatorState(point: previewPoint, isVisible: true)

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            focusIndicator.isVisible = false
        }
    }

    func switchCamera() {
        cameraManager.switchCamera()
        isUsingFrontCamera.toggle()
    }

    func toggleLiveDetection() {
        isLiveDetectionRunning.toggle()
        if isLiveDetectionRunning {
            selectedItems = Set(predictions.map(\.id))
        } else {
            predictions = []
            selectedItems = []
            dangerAnnouncer.reset()
        }
    }

    func togglePoseDetection() {
        isPoseDetectionRunning.toggle()
        if !isPoseDetectionRunning {
            posePoints = [:]
        }
    }

    func updateLiveAnalysisRate(_ rate: LiveAnalysisRate) {
        selectedLiveAnalysisRate = rate
        mlFacade.updateLiveAnalysisRate(rate)
    }

    func captureImage() {
        guard permissionsManager.galleryPermissionStatus() != .denied else {
            showSettingAlert = true
            return
        }

        loadingMessage = "Se proceseaza captura..."
        isLoadingImage = true
        Task {
            let image = await cameraManager.captureImage()
            isLoadingImage = false

            guard let image else {
                analysisError = "Imaginea nu a putut fi capturata."
                return
            }

            selectedImage = image
            showingPhotoReview = true
        }
    }

    func dismissPhotoReview() {
        showingPhotoReview = false
    }

    func describeScene() {
        guard !isDescribingScene else { return }
        let snapshot = predictions
        isDescribingScene = true
        dangerAnnouncer.describeScene(predictions: snapshot) { [weak self] in
            self?.isDescribingScene = false
        }
    }

    func toggleSelection(for predictionID: UUID, isSelected: Bool) {
        if isSelected {
            selectedItems.insert(predictionID)
        } else {
            selectedItems.remove(predictionID)
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        loadingMessage = "Se incarca fotografia din galerie..."
        isLoadingImage = true
        defer { isLoadingImage = false }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                analysisError = "Imaginea selectata nu a putut fi incarcata."
                return
            }

            selectedImage = image
            showingPhotoReview = true
        } catch {
            analysisError = error.localizedDescription
        }
    }

    private func handleIncomingFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard (isLiveDetectionRunning || isPoseDetectionRunning), !isAnalyzingFrame, !isDescribingScene else {
            return
        }

        isAnalyzingFrame = true
        defer { isAnalyzingFrame = false }

        do {
            guard let result = try await mlFacade.analyzeLiveFrame(
                sampleBuffer: sampleBuffer,
                detectObjects: isLiveDetectionRunning,
                detectPose: isPoseDetectionRunning
            ) else {
                return
            }

            predictions = result.predictions
            posePoints = result.posePoints
            selectedItems = Set(result.predictions.map(\.id))

            if isLiveDetectionRunning {
                dangerAnnouncer.process(predictions: result.predictions)
            }
        } catch {
            analysisError = error.localizedDescription
        }
    }
}
