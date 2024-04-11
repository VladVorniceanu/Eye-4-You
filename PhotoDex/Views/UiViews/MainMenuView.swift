//
//  MainMenuView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 02.04.2024.
//

import SwiftUI

struct MainMenuView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to PhotoDex")
                    .font(.title)
                    .padding(.all)
                
                NavigationStack {
                    NavigationLink(destination: CameraLiveView()) {
                        Text("Start camera")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }
                    NavigationLink(destination: {}) {
                        Text("Choose from Gallery")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/, style: .continuous))
                    }.padding()
                }
            }
        }
    }
}

#Preview {
    MainMenuView()
}
