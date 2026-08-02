import AVFoundation
import UIKit

/// A minimal AVFoundation capture wrapper for the Catch screen.
/// Handles permission, live preview, and a single photo capture.
///
/// Note: the camera only works on a real device. In the Simulator, use the
/// "Pick from Library" path on the Catch screen instead.
final class CameraModel: NSObject, ObservableObject {

    enum Status {
        case idle, authorized, denied, unavailable
    }

    let session = AVCaptureSession()
    @Published var status: Status = .idle

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.popple.camera.session")
    private var captureHandler: ((UIImage?) -> Void)?

    // MARK: Setup

    /// Requests permission (if needed) and configures the session.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndRun()
                } else {
                    DispatchQueue.main.async { self?.status = .denied }
                }
            }
        default:
            DispatchQueue.main.async { self.status = .denied }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                    let input = try? AVCaptureDeviceInput(device: device),
                    self.session.canAddInput(input)
                else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)

                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.status = .authorized }
        }
    }

    // MARK: Capture

    /// Captures a single photo. The completion is delivered on the main thread.
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.captureHandler = completion
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        let handler = captureHandler
        captureHandler = nil
        DispatchQueue.main.async { handler?(image) }
    }
}
