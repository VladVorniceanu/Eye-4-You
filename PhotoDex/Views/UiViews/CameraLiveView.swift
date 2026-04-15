import PhotosUI
import SwiftUI

struct CameraLiveView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CameraViewModel

    init(isLiveDetectionFlow: Bool) {
        _viewModel = StateObject(wrappedValue: CameraViewModel(isLiveDetectionFlow: isLiveDetectionFlow))
    }

    var body: some View {
        let selectedImage = viewModel.selectedImage

        ZStack {
            Color.black.ignoresSafeArea()

            FrameView(session: viewModel.session) { previewPoint, devicePoint in
                viewModel.setFocus(previewPoint: previewPoint, devicePoint: devicePoint)
            }
            .overlay {
                ZStack {
                    if viewModel.isLiveDetectionRunning {
                        OverlayView(predictions: viewModel.predictions, selectedItems: viewModel.selectedItems)
                    }

                    if viewModel.isPoseDetectionRunning {
                        PoseOverlayView(points: viewModel.posePoints)
                    }

                    if viewModel.focusIndicator.isVisible {
                        FocusView(position: .constant(viewModel.focusIndicator.point))
                            .transition(.scale)
                    }
                }
            }

            VStack(spacing: 0) {
                CameraTopBar(
                    title: viewModel.isLiveDetectionFlow ? "Analiza live" : "Captureaza o imagine",
                    subtitle: cameraSubtitle,
                    isFlashOn: viewModel.isFlashOn,
                    flashAction: viewModel.switchFlash,
                    backAction: { dismiss() }
                )

                Spacer()

                CameraBottomPanel(
                    selectedImage: selectedImage,
                    pickerItem: $viewModel.pickerItem,
                    isLiveDetectionFlow: viewModel.isLiveDetectionFlow,
                    isLiveDetectionRunning: viewModel.isLiveDetectionRunning,
                    isPoseDetectionRunning: viewModel.isPoseDetectionRunning,
                    objectCount: viewModel.predictions.count,
                    captureAction: viewModel.captureImage,
                    toggleLiveAction: viewModel.toggleLiveDetection,
                    togglePoseAction: viewModel.togglePoseDetection,
                    switchCameraAction: viewModel.switchCamera
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .alert(isPresented: $viewModel.showAlertError) {
            Alert(
                title: Text(viewModel.alertError.title),
                message: Text(viewModel.alertError.message),
                dismissButton: .default(Text(viewModel.alertError.primaryButtonTitle)) {
                    viewModel.alertError.primaryAction?()
                }
            )
        }
        .alert(isPresented: $viewModel.showSettingAlert) {
            Alert(
                title: Text("Atentie"),
                message: Text("Aplicatia nu are acces la camera sau la galerie. Activeaza permisiunile din Settings pentru a continua."),
                dismissButton: .default(Text("Deschide Settings")) {
                    openSettings()
                }
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
        .overlay {
            if viewModel.isLoadingImage {
                LoadingOverlay(text: "Se incarca imaginea...")
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.showingPhotoReview },
                set: { if !$0 { viewModel.dismissPhotoReview() } }
            )
        ) {
            if let image = viewModel.selectedImage {
                NavigationStack {
                    PhotoReview(
                        image: image,
                        isPresented: Binding(
                            get: { viewModel.showingPhotoReview },
                            set: { if !$0 { viewModel.dismissPhotoReview() } }
                        )
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var cameraSubtitle: String {
        if viewModel.isLiveDetectionFlow {
            return viewModel.isLiveDetectionRunning
                ? "\(viewModel.predictions.count) predictii vizibile"
                : "Detectarea obiectelor este oprita."
        }

        return "Atinge ecranul pentru focus sau foloseste galeria."
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url, options: [:])
    }
}

private struct CameraTopBar: View {
    let title: String
    let subtitle: String
    let isFlashOn: Bool
    let flashAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            FlashButton(isOn: isFlashOn, action: flashAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct CameraBottomPanel: View {
    let selectedImage: UIImage?
    @Binding var pickerItem: PhotosPickerItem?
    let isLiveDetectionFlow: Bool
    let isLiveDetectionRunning: Bool
    let isPoseDetectionRunning: Bool
    let objectCount: Int
    let captureAction: () -> Void
    let toggleLiveAction: () -> Void
    let togglePoseAction: () -> Void
    let switchCameraAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLiveDetectionFlow {
                Label(
                    objectCount == 0 ? "Nicio predictie detectata momentan" : "\(objectCount) predictii detectate",
                    systemImage: "viewfinder"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            }

            HStack(alignment: .bottom, spacing: 12) {
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .any(of: [.images, .not(.screenshots)]),
                    preferredItemEncoding: .current,
                    photoLibrary: .shared()
                ) {
                    GalleryThumbnail(image: .constant(selectedImage))
                }

                Spacer(minLength: 0)

                if isLiveDetectionFlow {
                    LiveModeControl(
                        title: "Obiecte",
                        systemImage: "sparkle.magnifyingglass",
                        isActive: isLiveDetectionRunning,
                        action: toggleLiveAction
                    )

                    LiveModeControl(
                        title: "Postura",
                        systemImage: "figure.walk",
                        isActive: isPoseDetectionRunning,
                        action: togglePoseAction
                    )
                } else {
                    ShutterButton(action: captureAction)
                }

                Spacer(minLength: 0)

                CameraSwitchButton(action: switchCameraAction)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct LiveModeControl: View, Equatable {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    static func == (lhs: LiveModeControl, rhs: LiveModeControl) -> Bool {
        lhs.title == rhs.title && lhs.systemImage == rhs.systemImage && lhs.isActive == rhs.isActive
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.85))
            .frame(width: 88, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isActive ? Color.accentColor : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LoadingOverlay: View, Equatable {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text(text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
