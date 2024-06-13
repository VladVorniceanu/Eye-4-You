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


    private var hasAppeared = false;
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("PhotoDex")
                    .font(.largeTitle)
                    .padding()
                    .animation(.easeIn, value: 20)
                
                NavigationStack {
                    NavigationLink(destination: CameraLiveView()) {
                        Text("Accesează camera")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }
                    PhotosPicker(selection: $viewModel.imageSelection, 
                                 matching: .images,
                                 preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        Text("Alege din galerie")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }.onChange(of: viewModel.imageSelection) { newValue in
                        if newValue != nil {
                            viewModel.isImageSelected = true
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
        .sheet(isPresented: $viewModel.isImageSelected) {
            if let selectedImage = viewModel.selectedImage {
                PhotoReview(image: selectedImage, isPresented: $viewModel.isImageSelected)
            }
        }
    }
}

#Preview {
    MainMenuView()
}
