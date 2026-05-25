import PhotosUI
import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.10),
                        Color.orange.opacity(0.05),
                        Color.clear
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
        .overlay {
            if viewModel.isLoadingSelectedImage {
                MenuLoadingOverlay(text: "Se incarca fotografia din galerie...")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eye 4 You")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("Your eyes, reimagined.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text("Analizeaza rapid obiecte din camera sau din galerie, intr-un flux mai usor de inteles si de controlat.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
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

private struct MenuLoadingOverlay: View, Equatable {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.15)
                Text(text)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
