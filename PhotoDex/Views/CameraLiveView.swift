//
//  ContentView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

struct CameraLiveView: View {
    @StateObject private var model = FrameHandler()
    
    var body: some View {
        VStack {
            ZStack {
                FrameView(image: model.frame)
                VStack {
                    Spacer()
                    
                    HStack (spacing: 10) {
                        CircleButton(action: {
                            model.switchToCamera(.builtInWideAngleCamera)
                        }, label: "1x")
                        
                        CircleButton(action: {
                            model.switchToCamera(.builtInUltraWideCamera)
                        }, label: "0.5x")
                    }
                    .padding(10)
                    .background(.quaternary .opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 60, style: .circular))
                    .padding()
                }.padding(.bottom, 10)
            }
            CircleButton(action: {}, label: "Capture")
                .padding(20)
                .padding(.bottom, 30)
                
        }.ignoresSafeArea()
    }
}

#Preview {
    CameraLiveView()
}
