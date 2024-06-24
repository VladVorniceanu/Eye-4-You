import SwiftUI
import Vision

struct MLAnalysisView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var predictions: [CustomMLModel.Prediction] = []
    @State private var posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @State private var analysisErrors: Error?
    @State private var isAnalyzing: Bool = true
    @State private var showPoseOverlay: Bool = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showDrawer: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        ZStack {
            NavigationStack {
                GeometryReader { geometry in
                    VStack {
                        if isAnalyzing {
                            ProgressView("Se analizează...")
                                .padding()
                        } else if let error = analysisErrors {
                            Text("Error: \(error.localizedDescription)")
                                .foregroundStyle(.red)
                                .padding()
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width)
                                .clipped()
                                .overlay(predictionOverlay())
                            
                            if predictions.isEmpty {
                                Button("Verifică rezultatele") {
                                    alertMessage = "Nu au fost detectate rezultate."
                                    showAlert = true
                                }
                                .padding()
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                            } else {
                                Spacer()
                                HStack(alignment: .center, content: {
                                    Spacer()
                                    Button("Vezi predicțiile") {
                                        showDrawer.toggle()
                                        alertMessage = "Lista de predicții se găsește în meniul lateral din dreapta."
                                        showAlert = true
                                    }
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                                    
                                    Spacer()
                                    
                                    PoseDetectSwitch(action: {
                                        showPoseOverlay.toggle()
                                    })
                                    .padding()
                                    Spacer()
                                })
                            }
                        }
                    }
                    .onAppear {
                        performAnalysis()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.all, 0)
                }
                .navigationTitle("Rezultatele analizei")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            withAnimation {
                                showDrawer.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .animation(.easeInOut, value: showDrawer)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width < -50 {
                                withAnimation {
                                    showDrawer = true
                                }
                            }
                        }
                )
            }
            
            if showDrawer {
                SideMenuPredictions(isPresented: $showDrawer, predictions: $predictions, selectedItems: $selectedItems)
                    .transition(.move(edge: .trailing))
            }
        }
    }
    
    private func performAnalysis() {
        let mlModel = CustomMLModel.shared
        DispatchQueue.global(qos: .background).async {
            mlModel.makePredictionsUsingYOLOAndMobileNet(for: image) { predictions in
                DispatchQueue.main.async {
                    if let predictions = predictions {
                        self.predictions = predictions
                        self.isAnalyzing = false
                        if predictions.isEmpty {
                            alertMessage = "Nu au fost detectate rezultate."
                            showAlert = true
                        } else {
                            alertMessage = "Lista de predicții se găsește în meniul lateral din dreapta."
                            showAlert = true
                        }
                    } else {
                        self.analysisErrors = NSError(domain: "Prediction Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get predictions."])
                        self.isAnalyzing = false
                    }
                }
            }
        }
        PoseDetectionManager.shared.detectPose(in: image) { points in
            DispatchQueue.main.async {
                self.posePoints = points ?? [:]
            }
        }
    }
    
    private func predictionOverlay() -> some View {
        GeometryReader { geometry in
            ZStack {
                if showPoseOverlay {
                    PoseOverlayView(points: $posePoints)
//                        .rotationEffect(.degrees(90), anchor: .center)
//                        .scaleEffect(x: 1, y: 1, anchor: .center)
                }
                
                ForEach(predictions.indices, id: \.self) { index in
                    let prediction = self.predictions[index]
                    
                    if selectedItems.contains(prediction.id), let boundingBox = prediction.boundingBox {
                        let x = boundingBox.origin.x * geometry.size.width
                        let y = (1 - boundingBox.origin.y - boundingBox.size.height) * geometry.size.height
                        let width = boundingBox.size.width * geometry.size.width
                        let height = boundingBox.size.height * geometry.size.height
                        
                        Rectangle()
                            .stroke(Color(hue: Double(index) / Double(self.predictions.count), saturation: 1, brightness: 1), lineWidth: 2)
                            .frame(width: width, height: height)
                            .position(x: x + width / 2, y: y + height / 2)

                        if let humanAnalysis = prediction.humanAnalysis {
                            VStack {
                                Text("Age: \(humanAnalysis.age)")
                                Text("Gender: \(humanAnalysis.gender)")
                                Text("Emotion: \(humanAnalysis.emotion)")
                            }
                            .padding(5)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .position(x: x + width / 2, y: y + height - 20)
                        } else {
                            Text("\(prediction.label) \(String(format: "%.2f", prediction.confidence * 100))%")
                                .foregroundColor(.white)
                                .padding(2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .position(x: x + width / 2, y: y + height)
                        }
                    }
                }
            }
        }
    }
}
