//
//  ContentView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

struct CameraLiveView: View {
    @ObservedObject private var model = CameraViewModel()
    @State private var isPhotoTaken = false
    @State private var capturedImage: CGImage?
    @State private var showingPhotoPreview = false
    @State private var isFocused = false
    @State private var focusLocation: CGPoint = .zero
    @State private var isScaled = false
    
    let width = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(
                spacing: 0
            ) {
                Button (action: {
                    model.switchFlash()
                },
                        label: {
                    Image(
                        systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash.fill"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .medium
                        )
                    )
                }).tint(
                    model.isFlashOn ? .yellow : .white
                )
                
                ZStack {
                    FrameView( session: model.session ) { tapPoint in
                        isFocused = true
                        focusLocation = tapPoint
                        model.setFocus(point: tapPoint)
                        
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    
                    if isFocused {
                        FocusView(position: $focusLocation, size: CGFloat(width * 0.15))
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
                    Gallery(
                        image: $model.capturedImage, size: CGFloat(width * 0.15)
                    )
                    
                    Spacer()
                    ShutterButton(action: {
                        model.captureImage { capturedImage in
                            if let capturedImage = capturedImage {
                                self.isPhotoTaken.toggle()
                                self.model.cameraManager.stopCapturing()
                                self.capturedImage = capturedImage
                            }
                        }
                    }, size: Int(CGFloat(width * 0.2)))
                    .sheet(isPresented: $isPhotoTaken, content: {
                        PhotoPreviewView(image: self.$capturedImage, isPresented: self.$showingPhotoPreview)})
                    
                    Spacer()
                    CameraSwitchButton (action: {
                        model.switchCamera()
                    }, size: CGFloat(width * 0.15))
                    
                }.padding(.horizontal)
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
        }
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

struct Gallery: View {
    @Binding var image: UIImage?
    let size: CGFloat?
    
    var body: some View {
        Group {
            if let image {
                Image(
                    uiImage: image
                )
                .resizable()
                .aspectRatio(
                    contentMode: .fill
                )
                .frame(
                    width: size,
                    height: size
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
            } else {
                Rectangle()
                    .frame(
                        width: size,
                        height: size,
                        alignment: .center
                    )
                    .foregroundStyle(
                        .white
                    )
            }
        }
    }
}

struct CameraSwitchButton: View {
    var action: () -> Void
    let size: CGFloat?
    
    var body: some View {
        Button(action: action,
               label: {
            Circle()
                .foregroundStyle(
                    Color.gray.opacity(
                        0.2
                    )
                )
                .frame(
                    width: size,
                    height: size,
                    alignment: .center
                )
                .overlay {
                    Image(
                        systemName: "camera.rotate.fill"
                    )
                    .foregroundStyle(
                        .white
                    )
                }
        })
    }
}

struct FocusView: View {
    @Binding var position: CGPoint
    var size: CGFloat?
    var body: some View {
        Circle()
            .frame(width: size, height: size)
            .foregroundColor(.clear)
            .border(.yellow, width: 1.5)
            .position(x: position.x, y: position.y)
    }
}

#Preview {
    CameraLiveView()
}

//VStack {
//            ZStack {
//                FrameView(image: model.frame)
//
//                VStack {
//                    Spacer()
//
//                    HStack (spacing: 10) {
//                        CircleButton(action: {
//                            model.switchAVDevices(.builtInUltraWideCamera)
//                        }, label: "0.5x", size: Int(CGFloat(width * 0.1)))
//
//                        CircleButton(action: {
//                            model.switchAVDevices(.builtInWideAngleCamera)
//                        }, label: "1x", size: Int(CGFloat(width * 0.1)))
//                    }
//                    .padding(10)
//                    .background(.quaternary .opacity(0.6))
//                    .clipShape(RoundedRectangle(cornerRadius: 60, style: .circular))
//                    .padding()
//
//                }.padding(.bottom, 10)
//            }
//
//            ShutterButton(action: {
//                self.model.capturePhoto { capturedImage in
//                    if let capturedImage = capturedImage {
//                        self.isPhotoTaken.toggle()
//                        self.model.stopCaptureSession()
//                        self.capturedImage = capturedImage
//                    }
//                }
//            }, size: Int(CGFloat(width * 0.2)))
//            .sheet(isPresented: $isPhotoTaken, content: {
//                PhotoPreviewView(image: self.$capturedImage, isPresented: self.$showingPhotoPreview)
//            })
//
//        }.ignoresSafeArea(edges: [.horizontal])
//            .background(Color.black)
//
//    }
//}
