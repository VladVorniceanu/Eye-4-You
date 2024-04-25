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
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to PhotoDex")
                    .font(.title)
                    .padding(.all)
                
                NavigationStack {
                    NavigationLink(destination: CameraLiveView()) {
                        Text("Start camera")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }
                    PhotosPicker(selection: $viewModel.imageSelection, 
                                 matching: .images,
                                 preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        Text("Choose from Gallery")
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
