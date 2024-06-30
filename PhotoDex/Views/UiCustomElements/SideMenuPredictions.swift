import SwiftUI

struct SideMenuPredictions: View {
    @Binding var isPresented: Bool
    @Binding var predictions: [CustomMLModel.Prediction]
    @Binding var selectedItems: Set<UUID>
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Predicții")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    
                    List {
                        ForEach(predictions, id: \.id) { item in
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
                                        Text("\(String(format: "%.2f", item.confidence * 100))%")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .frame(width: geometry.size.width * 0.75)
                .background(Color(UIColor.systemBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                self.offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 50 {
                                withAnimation {
                                    isPresented = false
                                    offset = geometry.size.width
                                }
                            } else {
                                withAnimation {
                                    self.offset = 0
                                }
                            }
                        }
                )
            }
            .onAppear {
                withAnimation {
                    self.offset = 0
                }
            }
            .onDisappear {
                withAnimation {
                    self.offset = geometry.size.width
                }
            }
        }
    }
}
