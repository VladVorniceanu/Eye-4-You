import PhotosUI
import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.97, blue: 0.99),
                        Color(red: 0.90, green: 0.95, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        actions

                        if !viewModel.modelsLoaded {
                            Label("Se pregatesc modelele necesare pentru analiza live.", systemImage: "sparkles")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isShowingPhotoReview },
                set: { if !$0 { viewModel.dismissPhotoReview() } }
            )
        ) {
            if let selectedImage = viewModel.selectedImage {
                NavigationStack {
                    PhotoReview(
                        image: selectedImage,
                        isPresented: Binding(
                            get: { viewModel.isShowingPhotoReview },
                            set: { if !$0 { viewModel.dismissPhotoReview() } }
                        )
                    )
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PhotoDex")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("Analizeaza rapid obiecte din camera sau din galerie, intr-un flux mai usor de inteles si de controlat.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: true)) {
                MenuButtonLabel(
                    systemImage: "livephoto",
                    title: "Detectare live",
                    subtitle: "Porneste camera si urmareste obiectele detectate in timp real.",
                    accentColor: .blue,
                    isLoading: !viewModel.modelsLoaded
                )
            }
            .disabled(!viewModel.modelsLoaded)

            NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: false)) {
                MenuButtonLabel(
                    systemImage: "camera",
                    title: "Captureaza o fotografie",
                    subtitle: "Fa o poza si apoi inspecteaza predictiile pe imaginea salvata.",
                    accentColor: .orange
                )
            }

            PhotosPicker(
                selection: $viewModel.imageSelection,
                matching: .any(of: [.images, .not(.screenshots)]),
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                MenuButtonLabel(
                    systemImage: "photo.on.rectangle",
                    title: "Alege din galerie",
                    subtitle: "Importa o imagine existenta si treci direct la analiza ei.",
                    accentColor: .green
                )
            }
        }
    }
}

private struct MenuButtonLabel: View, Equatable {
    let systemImage: String
    let title: String
    let subtitle: String
    let accentColor: Color
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 56, height: 56)

                if isLoading {
                    ProgressView()
                        .tint(accentColor)
                } else {
                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
    }
}
