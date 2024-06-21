//
//  SideMenuPredictions.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 21.06.2024.
//

import Foundation
import SwiftUI

struct SideMenuPredictions: View {
    @Binding var isPresented: Bool
    @Binding var predictions: [CustomMLModel.Prediction]
    @Binding var selectedItems: Set<UUID>
    @State private var offset = CGSize.zero
    @State private var initialDragPosition: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Predicții")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                        .padding(.leading, 20)
                    
                    List(predictions, id: \.self) { item in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedItems.contains(item.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedItems.insert(item.id)
                                    } else {
                                        selectedItems.remove(item.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(item.label.capitalized)
                                    Text("\(String(format: "%.2f", (item.confidence) * 100))%")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .frame(width: geometry.size.width * 0.8) // 80% din lățimea ecranului
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 10)
                .offset(x: offset.width)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                self.offset.width = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -50 {
                                withAnimation {
                                    self.offset.width = -geometry.size.width * 0.8
                                    isPresented = false
                                }
                            } else {
                                withAnimation {
                                    self.offset = .zero
                                }
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.5).ignoresSafeArea())
            .onAppear {
                withAnimation {
                    self.offset = .zero
                }
            }
            .onDisappear {
                withAnimation {
                    self.offset.width = -geometry.size.width * 0.8
                }
            }
        }
    }
}
