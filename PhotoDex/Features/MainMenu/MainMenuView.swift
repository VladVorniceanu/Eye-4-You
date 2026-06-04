//
//  MainMenuView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import PhotosUI
import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()

    private var isRO: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ro") == true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Header
                        menuHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 28)

                        // MARK: LiDAR Navigation — primary feature
                        Text(isRO ? "Navigare" : "Navigation")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                            .accessibilityAddTraits(.isHeader)

                        NavigationLink(destination: DepthNavigatorView()) {
                            NavigationHeroCard(isAvailable: viewModel.isNavigationModeAvailable)
                        }
                        .disabled(!viewModel.isNavigationModeAvailable)
                        .padding(.horizontal, 20)
                        .accessibilityLabel(
                            viewModel.isNavigationModeAvailable
                                ? (isRO ? "Pornește Modul Navigare LiDAR" : "Start LiDAR Navigation Mode")
                                : (isRO ? "Mod Navigare indisponibil" : "Navigation Mode unavailable")
                        )
                        .accessibilityHint(
                            viewModel.isNavigationModeAvailable
                                ? (isRO ? "Deschide navigarea ghidată prin LiDAR"
                                        : "Opens LiDAR-guided navigation")
                                : (isRO ? "Necesită iPhone Pro cu LiDAR"
                                        : "Requires iPhone Pro with LiDAR")
                        )

                        // MARK: Analysis Tools
                        Text(isRO ? "Instrumente de analiză" : "Analysis Tools")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 12)
                            .accessibilityAddTraits(.isHeader)

                        VStack(spacing: 12) {
                            NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: true)) {
                                AnalysisFeatureCard(
                                    systemImage: "livephoto",
                                    title: isRO ? "Detectare live" : "Live Detection",
                                    subtitle: isRO
                                        ? "Urmărește obiectele detectate în timp real."
                                        : "Track detected objects in real time.",
                                    accentColor: .blue,
                                    isLoading: !viewModel.modelsLoaded,
                                    isDisabled: !viewModel.modelsLoaded
                                )
                            }
                            .disabled(!viewModel.modelsLoaded)
                            .accessibilityLabel(
                                viewModel.modelsLoaded
                                    ? (isRO ? "Detectare live" : "Live Detection")
                                    : (isRO ? "Detectare live, modele în pregătire"
                                            : "Live Detection, models loading")
                            )
                            .accessibilityHint(isRO
                                ? "Pornește camera pentru detectare în timp real"
                                : "Starts the camera for real-time detection")

                            NavigationLink(destination: CameraLiveView(isLiveDetectionFlow: false)) {
                                AnalysisFeatureCard(
                                    systemImage: "camera",
                                    title: isRO ? "Captureaza fotografie" : "Capture Photo",
                                    subtitle: isRO
                                        ? "Fa o poza si inspecteaza predictiile."
                                        : "Take a photo and inspect predictions.",
                                    accentColor: .orange
                                )
                            }
                            .accessibilityHint(isRO
                                ? "Deschide camera pentru a face o fotografie"
                                : "Opens camera to take a photo")

                            PhotosPicker(
                                selection: $viewModel.imageSelection,
                                matching: .any(of: [.images, .not(.screenshots)]),
                                preferredItemEncoding: .current,
                                photoLibrary: .shared()
                            ) {
                                AnalysisFeatureCard(
                                    systemImage: "photo.on.rectangle",
                                    title: isRO ? "Alege din galerie" : "Choose from Gallery",
                                    subtitle: isRO
                                        ? "Importa o imagine existenta pentru analiza."
                                        : "Import an existing image for analysis.",
                                    accentColor: .green
                                )
                            }
                            .accessibilityLabel(isRO
                                ? "Alege fotografie din galerie"
                                : "Choose photo from gallery")
                            .accessibilityHint(isRO
                                ? "Deschide galeria foto"
                                : "Opens the photo library")
                        }
                        .padding(.horizontal, 20)

                        // MARK: Models warming up
                        if !viewModel.modelsLoaded {
                            Label(
                                isRO
                                    ? "Se pregătesc modelele pentru analiza live."
                                    : "Preparing models for live analysis.",
                                systemImage: "sparkles"
                            )
                            .font(.footnote.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .accessibilityLabel(isRO
                                ? "Modelele de detecție se pregătesc"
                                : "Detection models are loading")
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.isShowingPhotoReview) {
            if let selectedImage = viewModel.selectedImage {
                NavigationStack {
                    PhotoReview(image: selectedImage, isPresented: $viewModel.isShowingPhotoReview)
                }
            }
        }
        .overlay {
            if viewModel.isLoadingSelectedImage {
                MenuLoadingOverlay(text: isRO
                    ? "Se încarcă fotografia din galerie..."
                    : "Loading photo from gallery...")
            }
        }
    }

    // Header stays inline — it's 3 Text/Image elements sharing the same concern as body.
    private var menuHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Eye 4 You")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text(isRO ? "Ochii tăi, reimaginați." : "Your eyes, reimagined.")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
            }

            Spacer()

            NavigationLink(destination: SettingsView()) {
                Label(isRO ? "Setări" : "Settings", systemImage: "gearshape.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
        }
    }
}
