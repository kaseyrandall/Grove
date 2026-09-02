import SwiftUI

/// The lightweight, in-context tutorial: a few gentle bubbles that point at a
/// real target the first time the player reaches the moment it matters — one at
/// a time, tap to dismiss, each shown once. Targets tag themselves with
/// `.coachTarget(_:)`; `RootView` renders the active bubble over the anchor.
enum CoachStep: Int, CaseIterable {
    case snap        // the Catch button, while the Grove is empty
    case meetFriend  // the first friend's portrait, right after the first catch
    case dailyGoal   // the daily-challenge card

    var text: String {
        switch self {
        case .snap:       return "Tap here to snap\nyour first friend!"
        case .meetFriend: return "Here's your first friend -\ntap to see their details."
        case .dailyGoal:  return "A fresh challenge each day -\nyour reason to come back!"
        }
    }

    /// Bubble sits above its target (tail pointing down) vs. below (tail up).
    var prefersAbove: Bool {
        switch self {
        case .snap, .meetFriend: return true
        case .dailyGoal:         return false
        }
    }
}

// MARK: - Target tagging (anchor preference)

struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [CoachStep: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachStep: Anchor<CGRect>],
                       nextValue: () -> [CoachStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Register this view as the target a coach step points at.
    func coachTarget(_ step: CoachStep, active: Bool = true) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { anchor in
            active ? [step: anchor] : [:]
        }
    }
}

// MARK: - Bubble

struct CoachMarkBubble: View {
    let text: String
    /// True when the tail points down (bubble above the target).
    let arrowDown: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            if !arrowDown {
                CoachTriangle(pointingUp: true).fill(Theme.accent).frame(width: 20, height: 11)
            }
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 4)
            if arrowDown {
                CoachTriangle(pointingUp: false).fill(Theme.accent).frame(width: 20, height: 11)
            }
        }
        .offset(y: bounce ? 3 : -3)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounce = true }
        }
    }
}

/// A small triangle tail, pointing up or down.
struct CoachTriangle: Shape {
    var pointingUp: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointingUp {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Positioned overlay

/// Places the active bubble just above or below its target. Positioned by the
/// target's edge plus a fixed clearance (bubbles are one or two short lines, so
/// a fixed offset reads cleanly without a measurement pass).
struct CoachOverlay: View {
    let step: CoachStep
    let targetRect: CGRect
    let container: CGSize
    let onDismiss: () -> Void

    var body: some View {
        // Roughly half a two-line bubble + a little breathing room.
        let clearance: CGFloat = 46
        let margin: CGFloat = 120
        let x = min(max(targetRect.midX, margin), max(margin, container.width - margin))
        let y = step.prefersAbove
            ? targetRect.minY - clearance
            : targetRect.maxY + clearance

        CoachMarkBubble(text: step.text, arrowDown: step.prefersAbove, onTap: onDismiss)
            .frame(maxWidth: container.width - 32)
            .position(x: x, y: y)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
