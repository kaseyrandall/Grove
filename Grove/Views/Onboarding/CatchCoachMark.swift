import SwiftUI

/// A gentle callout that points at the Catch button so a brand-new player knows
/// exactly where to take their first photo. Positioned by its parent just above
/// the floating Catch button; shown once, while the Grove is still empty.
struct CatchCoachMark: View {
    /// Called when the player taps the callout (we jump them to Catch).
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("📸").font(.title3)
                Text("Tap here to snap\nyour first friend!")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.accent))
            .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 4)

            DownTriangle()
                .fill(Theme.accent)
                .frame(width: 20, height: 11)
        }
        .offset(y: bounce ? 4 : -2)
        .onTapGesture { onTap() }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

/// A small downward-pointing triangle for the callout's tail.
struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
