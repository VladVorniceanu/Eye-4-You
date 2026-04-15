import SwiftUI
import Vision

@MainActor
final class MLAnalysisViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var predictions: [Prediction] = []
    @Published private(set) var posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var selectedItems: Set<UUID> = []
    @Published var showDrawer = false
    @Published var showPoseOverlay = false

    private let image: UIImage
    private let mlFacade: CustomMLModel
    private var hasLoaded = false

    init(image: UIImage, mlFacade: CustomMLModel = .shared) {
        self.image = image
        self.mlFacade = mlFacade
    }

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        state = .loading

        Task {
            do {
                let result = try await mlFacade.analyzePhoto(image)
                predictions = result.predictions
                posePoints = result.posePoints
                selectedItems = Set(result.predictions.map(\.id))
                showPoseOverlay = !result.posePoints.isEmpty
                state = .loaded
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func toggleDrawer() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showDrawer.toggle()
        }
    }

    func closeDrawer() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showDrawer = false
        }
    }

    func togglePoseOverlay() {
        showPoseOverlay.toggle()
    }

    func toggleSelection(for predictionID: UUID, isSelected: Bool) {
        if isSelected {
            selectedItems.insert(predictionID)
        } else {
            selectedItems.remove(predictionID)
        }
    }
}
