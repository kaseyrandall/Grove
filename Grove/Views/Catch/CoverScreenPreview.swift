import SwiftUI
import AVFoundation

/// What the iPhone Duo's outer screen shows the subject while Grove's camera
/// is in use (a camera capture accessory, iOS 27.1): the live view, so a
/// person helping can check the framing from in front of the phone, a
/// friendly "look here!" bob to catch a pet's eye, and the self-timer's
/// countdown in big numbers. The system decides when to show it.
struct CoverScreenPreview: View {
    let session: AVCaptureSession
    let countdown: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: session)
                .ignoresSafeArea()
                // Mirrored, like a selfie, so it reads naturally from the front.
                .scaleEffect(x: -1, y: 1)

            VStack {
                Text("👀 Look here!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.accent))
                    .offset(y: reduceMotion ? 0 : (bob ? -6 : 6))
                    .padding(.top, 40)
                Spacer()
            }

            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 160, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 14)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bob = true }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Shows `CoverScreenPreview` on the iPhone Duo's outer screen during
    /// capture (iOS 27.1 and later; nothing elsewhere).
    @ViewBuilder
    func coverScreenPreview(session: AVCaptureSession, countdown: Int?) -> some View {
        if #available(iOS 27.1, *) {
            sceneAccessory {
                CameraCaptureAccessory {
                    CoverScreenPreview(session: session, countdown: countdown)
                }
            }
        } else {
            self
        }
    }
}
