//
//  MainMenuViewModel.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import ARKit
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class MainMenuViewModel: ObservableObject {
    @Published var imageSelection: PhotosPickerItem? {
        didSet {
            guard let imageSelection else { return }
            Task {
                await handleSelection(imageSelection)
            }
        }
    }
    @Published private(set) var selectedImage: UIImage?
    /// Publicly settable so the sheet binding ($viewModel.isShowingPhotoReview) works without a custom Binding wrapper.
    @Published var isShowingPhotoReview = false
    @Published private(set) var modelsLoaded = false
    @Published private(set) var isLoadingSelectedImage = false

    var isNavigationModeAvailable: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
    }

    private let mlFacade: CustomMLModel
    private var didInitialize = false

    init(mlFacade: CustomMLModel = .shared) {
        self.mlFacade = mlFacade
    }

    func onAppear() {
        guard !didInitialize else { return }
        didInitialize = true

        Task {
            modelsLoaded = await mlFacade.warmUp()
        }
    }

    private func handleSelection(_ item: PhotosPickerItem) async {
        isLoadingSelectedImage = true
        defer { isLoadingSelectedImage = false }

        if
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        {
            selectedImage = image
            isShowingPhotoReview = true
        } else {
            AppLogger.ui.error("Failed to load gallery image")
        }
    }
}
