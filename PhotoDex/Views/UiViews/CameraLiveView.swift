//
//  CameraLiveView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI
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

    let width = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                FlashButton(model: model)
                
                ZStack {
                    FrameView(isLiveDetectionFlow: self.isLiveDetectionFlow, session: model.session, predictions: $predictions, analysisError: $analysisError) { tapPoint in
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
                    OverlayView(predictions: $predictions, selectedItems: $selectedItems)
                }
                
                HStack {
                    PhotosPicker(selection: $viewModel.imageSelection,
                                 matching: .any(of: [.images, .not(.screenshots)]),
                                 preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        GalleryThumbnail(image: $imageState.uiImage)
                    }.onChange(of: viewModel.imageSelection) { newValue in
                        guard let newValue else { return }
                        Task {
                            await loadImage(from: newValue)
                        }
                    }
                    
                    Spacer()
                        
                    if !isLiveDetectionFlow {
                        ShutterButton(action: {
                            isLoadingImage = true
                            DispatchQueue.global(qos: .background).async {
                                do {
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
                            }
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
                    model.requestCameraPermission()
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
    
    func loadImage(from selection: PhotosPickerItem) async {
        isLoadingImage = true
        do {
            if let data = try await selection.loadTransferable(type: Data.self) {
                if let image = UIImage(data: data) {
                    imageState.setUIImage(image)
                    showingPhotoReview = true
                }
            }
        } catch {
            print("Error loading image: \(error.localizedDescription)")
        }
        isLoadingImage = false
    }
}

class ImageState: ObservableObject {
    @Published var uiImage: UIImage?
    @Published var cgImage: CGImage?

    init(uiImage: UIImage? = nil, cgImage: CGImage? = nil) {
        self.uiImage = uiImage
        self.cgImage = cgImage
    }

    func setUIImage(_ image: UIImage) {
        self.uiImage = image
        self.cgImage = image.cgImage
    }

    func setCGImage(_ image: CGImage) {
        self.cgImage = image
        self.uiImage = UIImage(cgImage: image)
    }
}

struct OverlayView: View {
    @Binding var predictions: [CustomMLModel.Prediction]
    @Binding var selectedItems: Set<UUID>

    var body: some View {
        GeometryReader { geometry in
            ForEach(predictions.indices, id: \.self) { index in
                let prediction = predictions[index]

                if let boundingBox = prediction.boundingBox {
                    let x = boundingBox.origin.x * geometry.size.width
                    let y = (1 - boundingBox.origin.y - boundingBox.size.height) * geometry.size.height
                    let width = boundingBox.size.width * geometry.size.width
                    let height = boundingBox.size.height * geometry.size.height

                    Rectangle()
                        .stroke(Color(hue: Double(index) / Double(predictions.count), saturation: 1, brightness: 1), lineWidth: 2)
                        .frame(width: width, height: height)
                        .position(x: x + width / 2, y: y + height / 2)

                    Text("\(prediction.label) \(String(format: "%.2f", prediction.confidence * 100))%")
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .position(x: x + width / 2, y: y + height)
                }
            }
        }
    }
}
