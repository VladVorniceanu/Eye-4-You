import SwiftUI
import Vision

struct MLAnalysisView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @StateObject private var viewModel: MLAnalysisViewModel

    init(image: UIImage, isPresented: Binding<Bool>) {
        self.image = image
        self._isPresented = isPresented
        _viewModel = StateObject(wrappedValue: MLAnalysisViewModel(image: image))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(20)
            }

            if viewModel.showDrawer {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.closeDrawer()
                    }
                    .transition(.opacity)
            }

            SideMenuPredictions(
                isPresented: $viewModel.showDrawer,
                predictions: viewModel.predictions,
                selectedItems: viewModel.selectedItems,
                onSelectionChanged: viewModel.toggleSelection
            )
        }
        .navigationTitle("Rezultate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.toggleDrawer) {
                    Image(systemName: viewModel.showDrawer ? "xmark" : "slider.horizontal.3")
                }
                .accessibilityLabel(viewModel.showDrawer ? "Inchide predictiile" : "Deschide predictiile")
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.showDrawer)
        .onAppear {
            viewModel.onAppear()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            AnalysisLoadingView()
        case .failed(let message):
            AnalysisStatusCard(
                title: "Analiza nu a putut fi finalizata",
                message: message,
                systemImage: "exclamationmark.triangle"
            )
        case .loaded:
            AnalysisSummaryCard(
                predictionCount: viewModel.predictions.count,
                selectedCount: viewModel.selectedItems.count,
                showPoseOverlay: viewModel.showPoseOverlay,
                onToggleDrawer: viewModel.toggleDrawer,
                onTogglePose: viewModel.togglePoseOverlay
            )

            AnalysisCanvas(
                image: image,
                predictions: viewModel.predictions,
                selectedItems: viewModel.selectedItems,
                showPoseOverlay: viewModel.showPoseOverlay,
                posePoints: viewModel.posePoints
            )

            if viewModel.predictions.isEmpty {
                AnalysisStatusCard(
                    title: "Nu au fost gasite rezultate",
                    message: "Incearca o imagine cu subiecte mai clare sau un cadru mai bine luminat.",
                    systemImage: "eye.slash"
                )
            }
        }
    }
}

private struct AnalysisLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Se analizeaza imaginea...")
                .font(.headline)
            Text("Procesul poate dura cateva secunde, in functie de continutul fotografiei.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct AnalysisSummaryCard: View {
    let predictionCount: Int
    let selectedCount: Int
    let showPoseOverlay: Bool
    let onToggleDrawer: () -> Void
    let onTogglePose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rezumat analiza")
                .font(.headline)

            HStack(spacing: 12) {
                SummaryMetric(title: "Detectate", value: "\(predictionCount)", tint: .blue)
                SummaryMetric(title: "Afisate", value: "\(selectedCount)", tint: .green)
                SummaryMetric(title: "Postura", value: showPoseOverlay ? "On" : "Off", tint: .orange)
            }

            HStack(spacing: 12) {
                Button(action: onToggleDrawer) {
                    Label("Vezi predictiile", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnalysisActionButtonStyle(tint: .accentColor))

                Button(action: onTogglePose) {
                    Label(showPoseOverlay ? "Ascunde postura" : "Afiseaza postura", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnalysisActionButtonStyle(tint: .orange))
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AnalysisCanvas: View {
    let image: UIImage
    let predictions: [Prediction]
    let selectedItems: Set<UUID>
    let showPoseOverlay: Bool
    let posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                ZStack {
                    if showPoseOverlay {
                        PoseOverlayView(points: posePoints)
                    }
                    OverlayView(predictions: predictions, selectedItems: selectedItems)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .shadow(color: Color.black.opacity(0.1), radius: 18, y: 10)
    }
}

private struct AnalysisStatusCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct AnalysisActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(tint.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
    }
}
