//
//  ContentView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

struct CameraLiveView: View {
    @StateObject private var model = CameraViewController()
    @State private var isPhotoTaken = false
    @State private var capturedImage: CGImage?
    @State private var showingPhotoPreview = false
    
    let width = UIScreen.main.bounds.width
    
    var body: some View {
        VStack {
            ZStack {
                FrameView(image: model.frame)
                
                VStack {
                    Spacer()
                    
                    HStack (spacing: 10) {
                        CircleButton(action: {
                            model.switchAVDevices(.builtInUltraWideCamera)
                        }, label: "0.5x", size: Int(CGFloat(width * 0.1)))
                        
                        CircleButton(action: {
                            model.switchAVDevices(.builtInWideAngleCamera)
                        }, label: "1x", size: Int(CGFloat(width * 0.1)))
                    }
                    .padding(10)
                    .background(.quaternary .opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 60, style: .circular))
                    .padding()
                    
                }.padding(.bottom, 10)
            }
            
            ShutterButton(action: {
                self.model.capturePhoto { capturedImage in
                    if let capturedImage = capturedImage {
                        self.isPhotoTaken.toggle()
                        self.model.stopCaptureSession()
                        self.capturedImage = capturedImage
                    }
                }
            }, size: Int(CGFloat(width * 0.2)))
            .sheet(isPresented: $isPhotoTaken, content: {
                PhotoPreviewView(image: self.$capturedImage, isPresented: self.$showingPhotoPreview)
            })
            
        }.ignoresSafeArea(edges: [.horizontal])
            .background(Color.black)
            
    }
}

#Preview {
    CameraLiveView()
}
