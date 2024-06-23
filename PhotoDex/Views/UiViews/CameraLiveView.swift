import SwiftUI
import Vision
import PhotosUI

struct CameraLiveView: View {
    @State var isLiveDetectionFlow: Bool
    @ObservedObject private var model = CameraViewModel()
    @StateObject private var viewModel = PhotoPicker()
    @StateObject private var imageState = ImageState()
    @State private var focusLocation: CGPoint = .zero
    @State private var showingPhotoReview = false
    @State private var isFocused = false
    @State private var isScaled = false
    @State private var isLoadingImage = false
    @State private var predictions: [CustomMLModel.Prediction] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var analysisError: Error?
    @State private var isPoseDetectionRunning = false
    @State private var posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                FlashButton(model: model)
                
                ZStack {
                    FrameView(isLiveDetectionFlow: $model.isLiveDetectionRunning, session: model.session, predictions: $predictions, analysisError: $analysisError, isPoseDetectionRunning: $isPoseDetectionRunning, posePoints: $posePoints) { tapPoint in
                        isFocused = true
                        focusLocation = tapPoint
                        model.setFocus(point: tapPoint)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    
                    if isFocused {
                        FocusView(position: $focusLocation)
                        .scaleEffect(isScaled ? 0.8 : 1)
                        .onAppear {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                self.isScaled = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    self.isFocused = false
                                    self.isScaled = false
                                }
                            }
                        }
                    }
                    if model.isLiveDetectionRunning {
                        OverlayView(predictions: $predictions, selectedItems: $selectedItems)
                    }

                    if isPoseDetectionRunning {
                        PoseOverlayView(points: $posePoints)
                    }
                }
                
                HStack {
                    PhotosPicker(selection: $viewModel.imageSelection,
                                 matching: .any(of: [.images, .not(.screenshots)]),
                                 preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        GalleryThumbnail(image: $imageState.uiImage)
                    }
                    .onChange(of: viewModel.imageSelection) { _ in
                        Task {
                            await loadImage()
                        }
                    }
                    
                    Spacer()
                        
                    if !isLiveDetectionFlow {
                        ShutterButton(action: {
                            isLoadingImage = true
                            DispatchQueue.global(qos: .background).async {
                                model.captureImage { uiImage in
                                    if let image = uiImage {
                                        DispatchQueue.main.async {
                                            imageState.setUIImage(image)
                                            isLoadingImage = false
                                            showingPhotoReview = true
                                            print("CameraLiveView: Image captured and UI updated")
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            isLoadingImage = false
                                            print("CameraLiveView: Failed to capture image")
                                        }
                                    }
                                }
                            }
                        })
                    } else {
                        LiveDetectSwitch(action: {
                            model.toggleLiveDetection()
                            print("Live detection toggled: \(model.isLiveDetectionRunning)")
                        })

                        PoseDetectSwitch(action: {
                            isPoseDetectionRunning.toggle()
                            print("Pose detection toggled: \(isPoseDetectionRunning)")
                        })
                    }
                    
                    Spacer()
                    
                    CameraSwitchButton(action: {
                        model.switchCamera()
                    })
                    
                }.padding(.horizontal)
            }
            .alert(isPresented: $model.showAlertError) {
                Alert(
                    title: Text(model.alertError.title),
                    message: Text(model.alertError.message),
                    dismissButton: .default(Text(model.alertError.primaryButtonTitle)) {
                        model.alertError.primaryAction?()
                    }
                )
            }
            .alert(isPresented: $model.showSettingAlert) {
                Alert(
                    title: Text("Atenție"),
                    message: Text("Aplicația nu are acces la cameră. Pentru a putea folosi funcționalitățile aplicației, acordați permisiunile necesare aplicației, din setările dispozitivului."),
                    dismissButton: .default(Text("Du-te la setări")) {
                        self.openSettings()
                    }
                )
            }
            .onAppear {
                DispatchQueue.global(qos: .background).async {
                    model.setupBindings()
                    model.checkAndRequestPermissions()
                }
            }
            .overlay {
                if isLoadingImage {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    ProgressView("Se încarcă imaginea...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 2), value: isLoadingImage)
                }
            }
            .sheet(isPresented: $showingPhotoReview) {
                if let uiImage = imageState.uiImage {
                    NavigationView {
                        PhotoReview(image: uiImage, isPresented: self.$showingPhotoReview)
                    }
                }
            }
        }
        .navigationTitle("Capturează o imagine")
    }
    
    func openSettings() {
        let settingsUrl = URL(string: UIApplication.openSettingsURLString)
        if let url = settingsUrl {
            UIApplication.shared.open(url, options: [:])
        }
    }
    
    func loadImage() async {
        isLoadingImage = true
        if let imageSelection = viewModel.imageSelection {
            do {
                if let data = try await imageSelection.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        imageState.setUIImage(image)
                        showingPhotoReview = true
                    }
                }
            } catch {
                print("Error loading image: \(error.localizedDescription)")
            }
        }
        isLoadingImage = false
    }
}
