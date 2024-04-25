//
//  ContentView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

struct CameraLiveView: View {
    @ObservedObject var model = CameraViewModel()
    @State private var capturedImage: CGImage?
    @State private var showingPhotoPreview = false
    @State private var isFocused = false
    @State private var focusLocation: CGPoint = .zero
    @State private var isScaled = false
    
    let width = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                FlashButton(model: model)
                
                ZStack {
                    FrameView( session: model.session ) { tapPoint in
                        isFocused = true
                        focusLocation = tapPoint
                        model.setFocus(point: tapPoint)
                        
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    
                    if isFocused {
                        FocusView(position: $focusLocation)
                            .scaleEffect(isScaled ? 0.8 : 1)
                            .onAppear {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                    self.isScaled = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        self.isFocused = false
                                        self.isScaled = false
                                    }
                                }
                            }
                    }
                }
                
                HStack {
                    GalleryThumbnail(
                        image: $model.capturedImage
                    )
                    
                    Spacer()
                    
                    ShutterButton(action: {
                        model.captureImage { capturedImage in
                            if let capturedImage = capturedImage {
                                self.capturedImage = capturedImage
                                self.showingPhotoPreview = true
                            }
                        }
                    })
                    
                    Spacer()
                    CameraSwitchButton (action: {
                        model.switchCamera()
                    })
                    
                }.padding(.horizontal, 25)
            }
            .alert(
                isPresented: $model.showAlertError
            ) {
                Alert(
                    title: Text(
                        model.alertError.title
                    ),
                    message: Text(
                        model.alertError.message
                    ),
                    dismissButton: .default(Text(
                        model.alertError.primaryButtonTitle
                    ),
                                            action: {
                                                model.alertError.primaryAction?()
                                            })
                )
            }
            .alert(
                isPresented: $model.showSettingAlert
            ) {
                Alert(
                    title: Text(
                        "Warning"
                    ),
                    message: Text(
                        "Application doesn't have all permissions to use camera and microphone, please change privacy settings."
                    ),
                    dismissButton: .default(Text(
                        "Go to settings"
                    ),
                                            action: {
                                                self.openSettings()
                                            })
                )
            }
            .onAppear {
                model.setupBindings()
                model.requestCameraPermission()
            }
            .sheet(isPresented: $showingPhotoPreview) {
                if let capturedImage = model.capturedImage {
                    PhotoReview(image: capturedImage, isPresented: self.$showingPhotoPreview)
                }
            }
        }
        .navigationTitle("Take a photo")
    }
    
    func openSettings() {
        let settingsUrl = URL(
            string: UIApplication.openSettingsURLString
        )
        if let url = settingsUrl {
            UIApplication.shared.open(
                url,
                options: [:]
            )
        }
    }
}

#Preview {
    CameraLiveView()
}
