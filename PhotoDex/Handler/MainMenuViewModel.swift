import PhotosUI
import SwiftUI

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
    @Published private(set) var isShowingPhotoReview = false
    @Published private(set) var modelsLoaded = false

    private let photoPicker: PhotoPicker
    private let mlFacade: CustomMLModel
    private var didInitialize = false

    init(photoPicker: PhotoPicker = PhotoPicker(), mlFacade: CustomMLModel = .shared) {
        self.photoPicker = photoPicker
        self.mlFacade = mlFacade
    }

    func onAppear() {
        guard !didInitialize else { return }
        didInitialize = true

        Task {
            modelsLoaded = await mlFacade.warmUp()
        }
    }

    func dismissPhotoReview() {
        isShowingPhotoReview = false
    }

    private func handleSelection(_ item: PhotosPickerItem) async {
        do {
            selectedImage = try await photoPicker.loadImage(from: item)
            isShowingPhotoReview = selectedImage != nil
        } catch {
            AppLogger.ui.error("Failed to load gallery image - \(error.localizedDescription)")
        }
    }
}
