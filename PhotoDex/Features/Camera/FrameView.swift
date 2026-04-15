import AVFoundation
import SwiftUI

struct FrameView: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var previewRect: CGRect
    var onTap: (_ previewPoint: CGPoint, _ devicePoint: CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.videoPreviewLayer.connection?.videoRotationAngle = 90

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTapGesture(_:))
        )
        view.addGestureRecognizer(tapGesture)
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        context.coordinator.updatePreviewRect(from: uiView)
    }
}

extension FrameView {
    final class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    final class Coordinator: NSObject {
        var parent: FrameView

        init(parent: FrameView) {
            self.parent = parent
        }

        func updatePreviewRect(from previewView: VideoPreviewView) {
            DispatchQueue.main.async {
                self.parent.previewRect = previewView.videoPreviewLayer
                    .layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
        }

        @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
            guard let previewView = sender.view as? VideoPreviewView else {
                return
            }

            let location = sender.location(in: previewView)
            let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
            parent.onTap(location, devicePoint)
        }
    }
}
