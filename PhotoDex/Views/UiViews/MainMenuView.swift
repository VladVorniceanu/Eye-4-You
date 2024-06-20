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
    @State private var isLoadingModels = true
    @State private var isLoadingImage = false
    
    
    private var hasAppeared = false;
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("PhotoDex")
                    .font(.largeTitle)
                    .padding()
                    .animation(.bouncy, value: isLoadingModels)
                
                NavigationStack {
                    
                    NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: true)) {
                        Text("Detectează obiecte LIVE")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }.selectionDisabled(isLoadingModels == true)
                    
                    NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: false)) {
                        Text("Capturează o poză")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }
                    
                    PhotosPicker(selection: $viewModel.imageSelection,
                                 matching: .any(of: [.images, .not(.screenshots)]),
                                 preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        Text("Alege din galerie")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }.onChange(of: viewModel.imageSelection) { newValue in
                        guard let newValue else { return }
                        Task {
                            await loadImage(from: newValue)
                        }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .background).async {
                isLoadingModels = !(CustomMLModel.yoloModel != nil && CustomMLModel.mobileNetModel != nil)
            }
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
            NavigationView{
                if let selectedImage = viewModel.selectedImage {
                    PhotoReview(image: selectedImage, isPresented: $viewModel.isImageSelected)
                }
            }
        }
    }
    func loadImage(from selection: PhotosPickerItem) async {
        DispatchQueue.main.async {
            self.isLoadingImage = true
        }
        do {
            if let data = try await selection.loadTransferable(type: Data.self) {
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

#Preview {
    MainMenuView()
}
