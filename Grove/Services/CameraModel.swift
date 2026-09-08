import AVFoundation
import UIKit

/// A minimal AVFoundation capture wrapper for the Catch screen.
/// Handles permission, live preview, a single photo capture, and the small set
/// of viewfinder controls the immersive camera offers: flip, flash, tap-to-focus.
///
/// Note: the camera only works on a real device. In the Simulator, use the
/// "Pick from Library" path on the Catch screen instead.
final class CameraModel: NSObject, ObservableObject {

    enum Status {
        case idle, authorized, denied, unavailable
    }

    let session = AVCaptureSession()
    @Published var status: Status = .idle
    /// Which camera is live. Drives the flip control's state.
    @Published private(set) var position: AVCaptureDevice.Position = .back
    /// Flash for the next photo. Ignored by cameras without a flash.
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    /// Current pinch-zoom factor (1× = no zoom). Capped for a cozy, usable range.
    @Published private(set) var zoomFactor: CGFloat = 1.0
    private let maxZoom: CGFloat = 5.0

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.grove.camera.session")
    private var captureHandler: ((UIImage?) -> Void)?
    private var currentInput: AVCaptureDeviceInput?

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

                guard let input = self.makeInput(position: self.position) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)
                self.currentInput = input

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

    private func makeInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return nil }
        return input
    }

    // MARK: Viewfinder controls

    /// Swaps between the front and back cameras.
    func flip() {
        sessionQueue.async { [weak self] in
            guard let self, let current = self.currentInput else { return }
            let newPosition: AVCaptureDevice.Position = (self.position == .back) ? .front : .back

            self.session.beginConfiguration()
            self.session.removeInput(current)
            if let input = self.makeInput(position: newPosition) {
                self.session.addInput(input)
                self.currentInput = input
                DispatchQueue.main.async {
                    self.position = newPosition
                    self.zoomFactor = 1.0 // the new camera starts un-zoomed
                }
            } else {
                // Couldn't switch — put the original camera back.
                if self.session.canAddInput(current) { self.session.addInput(current) }
            }
            self.session.commitConfiguration()
        }
    }

    /// Focuses (and meters exposure) at a point in the preview layer's
    /// device-space coordinates, from a tap.
    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = device.isFocusModeSupported(.autoFocus) ? .autoFocus : device.focusMode
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = device.isExposureModeSupported(.autoExpose) ? .autoExpose : device.exposureMode
                }
                device.unlockForConfiguration()
            } catch {
                // Focus is a nicety; never surface a failure to the player.
            }
        }
    }

    /// Pinch-to-zoom. Clamped to [1×, 5×] (and whatever the device allows) so
    /// people can reach shy wildlife without getting close — pairs with the
    /// "keep your distance" reminder.
    func zoom(to factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            let maxAllowed = min(device.maxAvailableVideoZoomFactor, self.maxZoom)
            let clamped = min(max(factor, 1.0), maxAllowed)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = clamped }
            } catch {
                // Zoom is a nicety; ignore failures.
            }
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
            if self.output.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
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
