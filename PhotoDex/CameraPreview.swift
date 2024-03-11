//
//  ContentView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = FrameHandler()
    var body: some View {
        FrameView(image: model.frame)
    }
}

#Preview {
    ContentView()
}
