import SwiftUI

/// Picks up exactly where the system launch screen leaves off (the hedgehog
/// on deep green, same size and place), then the hedgehog gently grows and
/// everything fades to reveal the Grove, instead of a hard cut.
struct SplashView: View {
    /// Called once the splash has faded out.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var leaving = false

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchMark")
                .resizable()
                .frame(width: 260, height: 260)
                .scaleEffect(leaving && !reduceMotion ? 1.12 : 1)
        }
        .opacity(leaving ? 0 : 1)
        .accessibilityHidden(true)
        .task {
            // A beat to see the hedgehog, then reveal the Grove.
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 0.45)) { leaving = true }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 450))
            onFinished()
        }
    }
}
