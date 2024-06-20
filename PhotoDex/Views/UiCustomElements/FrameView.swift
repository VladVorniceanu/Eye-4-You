//
//  FrameView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI
import AVFoundation

struct FrameView: UIViewRepresentable {
    @State var isLiveDetectionFlow: Bool
    let session: AVCaptureSession
    @Binding var predictions: [CustomMLModel.Prediction]
    @Binding var analysisError: Error?
    var onTap: (CGPoint) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.videoPreviewLayer.connection?.videoRotationAngle = 90
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTapGesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        context.coordinator.setupVideoOutput()
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: FrameView
        private let mlModel = CustomMLModel.shared
        
        init(parent: FrameView) {
            self.parent = parent
        }
        
        func setupVideoOutput() {
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            parent.session.addOutput(videoOutput)
        }
        
        @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
            let location = sender.location(in: sender.view)
            parent.onTap(location)
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            if !parent.isLiveDetectionFlow {
                return
            }
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let uiImage = UIImage(cgImage: cgImage)
            
            DispatchQueue.global(qos: .background).async {
                do {
                    try self.mlModel.makePredictions(for: uiImage) { predictions in
                        DispatchQueue.main.async {
                            if let predictions = predictions {
                                self.parent.predictions = predictions
                            } else {
                                self.parent.analysisError = NSError(domain: "Prediction Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get predictions."])
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.analysisError = error
                    }
                }
            }
        }
    }
}

