import SwiftUI
import AVFoundation

/// A SwiftUI wrapper around an `AVCaptureVideoPreviewLayer`, with tap-to-focus.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Called on tap with the point in the preview's own coordinate space (for a
    /// focus reticle) and the converted device point (for the capture device).
    var onTap: ((_ layerPoint: CGPoint, _ devicePoint: CGPoint) -> Void)? = nil

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.onTap = onTap
        let tap = UITapGestureRecognizer(target: view, action: #selector(PreviewView.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onTap = onTap
    }

    /// A UIView whose backing layer is an AVCaptureVideoPreviewLayer.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        var onTap: ((CGPoint, CGPoint) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: self)
            let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
            onTap?(point, devicePoint)
        }
    }
}
