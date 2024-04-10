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
    
    let width = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(
                spacing: 0
            ) {
                Button (action: {
                    model.switchFlash()                },
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
                
                FrameView(
                    session: model.session
                )
                
                HStack {
                    Gallery(
                        image: $model.capturedImage, size: CGFloat(width * 0.15)
                    )
                    Spacer()
                    ShutterButton(action: {
                        // TODO: capture photo
                        //                        self.model.capturePhoto { capturedImage in
                        //                            if let capturedImage = capturedImage {
                        //                                self.isPhotoTaken.toggle()
                        //                                self.model.stopCaptureSession()
                        //                                self.capturedImage = capturedImage
                        //                            }
                        //                        }
                    },
                                  size: Int(
                                    CGFloat(
                                        width * 0.2
                                    )
                                  ))
                    Spacer()
                    CameraSwitchButton (action: {
                        //TODO: call camera switch
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
                model.checkForDevicePermission()
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
                        width: 50,
                        height: 50,
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
