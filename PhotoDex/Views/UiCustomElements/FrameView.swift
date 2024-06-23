//  FrameView.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI
import AVFoundation

struct FrameView: UIViewRepresentable {
    @Binding var isLiveDetectionFlow: Bool
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
            let uiImage = UIImage(cgImage: cgImage).rotated(byDegrees: 90)!
            
            DispatchQueue.global().async {
                YoloCoreML.makePredictionsUsingYOLO(for: uiImage, model: CustomMLModel.yoloModel) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let predictions):
                            self.parent.predictions = predictions
                        case .failure(let error):
                            self.parent.analysisError = error
                            print("YOLO Live Analysis Error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
