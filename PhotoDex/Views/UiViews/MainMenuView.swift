//
//  MainMenuView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 02.04.2024.
//

import SwiftUI
import PhotosUI

struct MainMenuView: View {
    @StateObject private var viewModel = PhotoPicker()
    @StateObject private var customMLModel = CustomMLModel.shared
    @State private var modelsLoaded = false
    @State private var isLoadingImage = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("PhotoDex")
                    .font(.largeTitle)
                    .padding()
                
                NavigationStack {
                    NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: true)) {
                        Text("Detectează obiecte LIVE")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                    }.opacity(modelsLoaded ? 1.0 : 0.5)
                        .disabled(!modelsLoaded)
                    
                    NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: false)) {
                        Text("Capturează o poză")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                    }
                    
                    PhotosPicker(selection: $viewModel.imageSelection,
                                 matching: .any(of: [.images, .not(.screenshots)]),
                                 preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        Text("Alege din galerie")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                    }
                    .onChange(of: viewModel.imageSelection) { _ in
                        Task {
                            await loadImage()
                        }
                    }
                }
            }
        }
        .onAppear {
            initializeModels()
        }
        .overlay {
            if isLoadingImage {
                Color.black.opacity(0.9).ignoresSafeArea()
                ProgressView("Se încarcă imaginea...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 2), value: isLoadingImage)
            }
        }
        .sheet(isPresented: $viewModel.isImageSelected) {
            NavigationView {
                if let selectedImage = viewModel.selectedImage {
                    PhotoReview(image: selectedImage, isPresented: $viewModel.isImageSelected)
                }
            }
        }
    }
    
    func initializeModels() {
        CustomMLModel.initializeModels { success in
            DispatchQueue.main.async {
                modelsLoaded = success
            }
        }
        DispatchQueue.global(qos: .background).async {
            _ = HumanAnalysisManager.shared
        }
    }
    
    func loadImage() async {
        DispatchQueue.main.async {
            self.isLoadingImage = true
        }
        if let imageSelection = viewModel.imageSelection {
            do {
                if let data = try await imageSelection.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            viewModel.selectedImage = image
                            viewModel.isImageSelected = true
                            self.isLoadingImage = false
                        }
                    }
                }
            } catch {
                print("Error loading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                }
            }
        }
    }
}

struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
    }
}
