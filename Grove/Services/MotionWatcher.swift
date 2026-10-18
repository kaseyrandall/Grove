import AVFoundation
import CoreVideo

/// Stakeout's eyes: watches the camera's video frames for something moving
/// into the scene, entirely on the phone. Each frame is shrunk to a coarse
/// grid of brightness values and compared with a slowly updated picture of
/// the empty scene. A visitor is a patch of the grid that changes; the whole
/// frame changing at once (a cloud, the lights, the phone being nudged) is
/// treated as a new empty scene instead.
final class MotionWatcher: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called on the main queue when something moves in.
    var onMotion: (() -> Void)?

    let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.grove.stakeout.motion")

    // Tuning. Starting points; meant to be tuned on a real iPhone Duo.
    private let columns = 32, rows = 24
    /// Brightness change (0–255) for a cell to count as changed.
    private let cellThreshold: Float = 28
    /// Share of cells that must change: a visitor is at least this much…
    private let minChanged: Float = 0.03
    /// …and at most this much (more is the whole scene shifting).
    private let maxChanged: Float = 0.55
    /// Frames in a row that must agree, to ignore one-frame flickers.
    private let framesToConfirm = 2
    /// How quickly the empty-scene picture follows slow changes (light).
    private let backgroundBlend: Float = 0.05
    /// Quiet time after each visitor, so one squirrel isn't fifty photos.
    private let cooldown: TimeInterval = 8
    /// Frames are looked at about this often.
    private let interval: TimeInterval = 0.25

    private var background: [Float] = []
    private var agreeing = 0
    private var lastFrame = Date.distantPast
    private var lastTrigger = Date.distantPast

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    /// Forget the scene (call when watching starts).
    func reset() {
        queue.async {
            self.background = []
            self.agreeing = 0
            self.lastTrigger = .now
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date.now
        guard now.timeIntervalSince(lastFrame) >= interval,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = now
        guard let grid = Self.brightnessGrid(pixels, columns: columns, rows: rows) else { return }

        guard background.count == grid.count else { background = grid; return }

        var changed = 0
        for i in grid.indices where abs(grid[i] - background[i]) > cellThreshold { changed += 1 }
        let share = Float(changed) / Float(grid.count)

        if share > maxChanged {
            // The whole scene moved: start over from what we see now.
            background = grid
            agreeing = 0
            return
        }
        // Follow slow changes, but not the visitor itself.
        for i in grid.indices {
            background[i] += (grid[i] - background[i]) * backgroundBlend
        }
        agreeing = share >= minChanged ? agreeing + 1 : 0
        if agreeing >= framesToConfirm, now.timeIntervalSince(lastTrigger) >= cooldown {
            agreeing = 0
            lastTrigger = now
            DispatchQueue.main.async { self.onMotion?() }
        }
    }

    /// The average brightness of each cell of a coarse grid over the frame,
    /// read from the luma plane.
    private static func brightnessGrid(_ buffer: CVPixelBuffer, columns: Int, rows: Int) -> [Float]? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var grid = [Float](repeating: 0, count: columns * rows)
        let step = 4 // sample every 4th pixel each way: plenty for a 32×24 grid
        for row in 0..<rows {
            let y0 = row * height / rows, y1 = (row + 1) * height / rows
            for column in 0..<columns {
                let x0 = column * width / columns, x1 = (column + 1) * width / columns
                var sum = 0, count = 0
                var y = y0
                while y < y1 {
                    let line = bytes + y * stride
                    var x = x0
                    while x < x1 { sum += Int(line[x]); count += 1; x += step }
                    y += step
                }
                grid[row * columns + column] = count > 0 ? Float(sum) / Float(count) : 0
            }
        }
        return grid
    }
}
