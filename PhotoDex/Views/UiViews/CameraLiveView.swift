//
//  ContentView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI
import PhotosUI

struct CameraLiveView: View {
    @ObservedObject var model = CameraViewModel()
    @StateObject var viewModel = PhotoPicker()
    @StateObject private var imageState = ImageState()
    @State private var focusLocation: CGPoint = .zero
    @State private var showingPhotoReview = false
    @State private var isFocused = false
    @State private var isScaled = false
    @State private var isLoadingImage = false

    let width = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                FlashButton(model: model)
                
                ZStack {
                    FrameView(session: model.session) { tapPoint in
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
                    
                    ShutterButton(action: {
                        isLoadingImage = true
                        DispatchQueue.global(qos: .background).async {
                            do {
                                model.captureImage { _ in
                                    if let image = model.capturedImage {
                                        DispatchQueue.main.async {
                                            imageState.setUIImage(image)
                                            isLoadingImage = false
                                            showingPhotoReview = true
                                        }
                                    }
                                }
                            }
                        }
                        
                    })
                    
                    Spacer()
                    CameraSwitchButton(action: {
                        model.switchCamera()
                    })
                    
                }.padding(.horizontal, 25)
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
                    Color.black.opacity(0.5).ignoresSafeArea()
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
                    }.presentationDetents([.fraction(UIScreen.main.bounds.height*0.8)])
                        .interactiveDismissDisabled(false)
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
