import SwiftUI

/// The iPhone Duo's special modes in Grove, explained: a one-time intro the
/// first time Grove runs on a Duo, a single-feature sheet where each mode
/// lives (the half-fold camera's ⓘ, Grove Frame's first visit), and an
/// "iPhone Duo" row in Settings to come back to it.
enum DuoFeature: String, CaseIterable, Identifiable {
    case spreads, halfFoldCamera, lookHere, groveFrame, widget

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spreads:        return "Two-page spreads"
        case .halfFoldCamera: return "Half-fold camera"
        case .lookHere:       return "\"Look here!\" preview"
        case .groveFrame:     return "Grove Frame"
        case .widget:         return "Grove widget"
        }
    }

    /// One line: what it is.
    var summary: String {
        switch self {
        case .spreads:        return "Open it flat and Grove spreads across both pages."
        case .halfFoldCamera: return "Stand it up like a tiny laptop and snap hands-free."
        case .lookHere:       return "The outer screen helps catch a pet's eye."
        case .groveFrame:     return "Your favorite friends, framed on your desk."
        case .widget:         return "Your favorite friends on your Home Screen."
        }
    }

    /// How to use it, step by step.
    var steps: [String] {
        switch self {
        case .spreads:
            return ["Open your Duo all the way.",
                    "Your whole Grove fits on one screen, and pages like the Field Guide and your Profile show a list on the left and details on the right.",
                    "Turn it upright for one tall page instead."]
        case .halfFoldCamera:
            return ["Open the camera, then half-fold your Duo and stand it up like a tiny laptop.",
                    "The viewfinder fills the top half; the bottom half becomes a big control deck.",
                    "Tap anywhere on the deck to snap, or pick a 3 or 10 second timer so you can step back and wait quietly."]
        case .lookHere:
            return ["When your Duo is open with the camera on, the outer screen faces whoever you're photographing.",
                    "It shows a mirrored preview, a bouncing \"Look here!\" and the timer's countdown.",
                    "Great for pet portraits, or for a friend checking they're in the shot."]
        case .groveFrame:
            return ["Half-fold your Duo and set it on a desk or shelf.",
                    "Leave it alone for about 30 seconds and Grove becomes a photo frame of your favorite friends, with the time and today's challenge.",
                    "Tap anywhere to go back. On the charger it stays on; otherwise it dims like usual."]
        case .widget:
            return ["Touch and hold your Home Screen, tap Edit, then Add Widget, and search for Grove.",
                    "It shows your favorite friends, taking turns every half hour.",
                    "On the charger in StandBy, the small one makes a cozy bedside frame."]
        }
    }

    var pose: DuoPose {
        switch self {
        case .spreads:        return .flat
        case .halfFoldCamera: return .laptop
        case .lookHere:       return .tent
        case .groveFrame:     return .desk
        case .widget:         return .widget
        }
    }
}

/// How to hold the Duo for a feature, as a small drawing.
enum DuoPose { case flat, laptop, tent, desk, widget }

/// A little Grove-style drawing of a Duo pose (side view for the folds,
/// front view when flat).
struct DuoPoseIllustration: View {
    let pose: DuoPose
    var size: CGFloat = 76

    private let outline = Theme.ink.opacity(0.8)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Theme.cream)
            drawing
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var drawing: some View {
        let s = size
        switch pose {
        case .flat:
            // Front view: one wide screen, two pages, the fold between.
            HStack(spacing: 0) {
                Rectangle().fill(Theme.mint.opacity(0.7))
                Rectangle().fill(Theme.sky.opacity(0.7))
            }
            .frame(width: s * 0.62, height: s * 0.44)
            .clipShape(RoundedRectangle(cornerRadius: s * 0.06, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: s * 0.06, style: .continuous).strokeBorder(outline, lineWidth: s * 0.04))
            .overlay(Rectangle().fill(outline.opacity(0.35)).frame(width: 1.5).padding(.vertical, s * 0.05))
        case .laptop, .desk:
            // Side view: the base flat on the table, the screen up at ~110°,
            // and what's on it beside.
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: s * 0.80, y: s * 0.74))
                    p.addLine(to: CGPoint(x: s * 0.30, y: s * 0.74))
                }
                .stroke(outline, style: StrokeStyle(lineWidth: s * 0.07, lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: s * 0.30, y: s * 0.74))
                    p.addLine(to: CGPoint(x: s * 0.18, y: s * 0.26))
                }
                .stroke(pose == .laptop ? Theme.accent : Theme.gold,
                        style: StrokeStyle(lineWidth: s * 0.07, lineCap: .round))
                Text(pose == .laptop ? "📷" : "🖼️")
                    .font(.system(size: s * 0.24))
                    .position(x: s * 0.62, y: s * 0.44)
            }
            .frame(width: s, height: s)
        case .tent:
            // Side view: stood like a tent, the outer screen facing out.
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: s * 0.18, y: s * 0.76))
                    p.addLine(to: CGPoint(x: s * 0.38, y: s * 0.28))
                }
                .stroke(outline, style: StrokeStyle(lineWidth: s * 0.07, lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: s * 0.38, y: s * 0.28))
                    p.addLine(to: CGPoint(x: s * 0.58, y: s * 0.76))
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: s * 0.07, lineCap: .round))
                Text("👀")
                    .font(.system(size: s * 0.22))
                    .position(x: s * 0.78, y: s * 0.50)
            }
            .frame(width: s, height: s)
        case .widget:
            // A small square widget tile with a friend.
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: s * 0.1, style: .continuous).fill(Theme.mint.opacity(0.8))
                Text("🦊").font(.system(size: s * 0.3)).padding(s * 0.06)
            }
            .frame(width: s * 0.5, height: s * 0.5)
            .overlay(RoundedRectangle(cornerRadius: s * 0.1, style: .continuous).strokeBorder(outline, lineWidth: s * 0.035))
        }
    }
}

/// One feature, explained: the drawing, what it is, and how to use it.
struct DuoFeatureSheet: View {
    let feature: DuoFeature
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groveSheetClose) private var closePanel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    DuoPoseIllustration(pose: feature.pose, size: 120)
                    VStack(spacing: 6) {
                        Text(feature.title)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text(feature.summary)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(feature.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(Theme.accent))
                                Text(step)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard()
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .groveSheetChrome(title: "iPhone Duo", confirm: SheetAction(title: "Got it") { close() })
        .presentationDetents([.medium, .large])
    }

    private func close() {
        if let closePanel { closePanel() } else { dismiss() }
    }
}

/// "Made for iPhone Duo": every special mode at a glance, shown once the
/// first time Grove runs on a Duo, and from Settings any time.
struct DuoIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groveSheetClose) private var closePanel
    @State private var detail: DuoFeature?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text("📖").font(.system(size: 52))
                            Text("Made for iPhone Duo")
                                .font(.system(.title, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                            Text("Fold, open or stand it up, and Grove changes with you.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Theme.ink.opacity(0.65))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 4)

                        ForEach(DuoFeature.allCases) { feature in
                            Button { detail = feature } label: {
                                HStack(spacing: 14) {
                                    DuoPoseIllustration(pose: feature.pose, size: 64)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(feature.title)
                                            .font(.system(.headline, design: .rounded, weight: .bold))
                                            .foregroundStyle(Theme.ink)
                                        Text(feature.summary)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(Theme.ink.opacity(0.6))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.ink.opacity(0.25))
                                }
                                .padding(12)
                                .contentShape(Rectangle())
                                .softCard()
                            }
                            .buttonStyle(.plain)
                        }

                        Button { close() } label: {
                            Text("Let's go!")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Theme.accent))
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .padding(.top, 6)
                    }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $detail) { DuoFeatureSheet(feature: $0) }
        }
    }

    private func close() {
        if let closePanel { closePanel() } else { dismiss() }
    }
}

/// A feature's how-to drawn right on the screen, for places where a sheet
/// would be awkward: on a half-folded Duo a sheet drapes across the fold and
/// its grab handle lands on the upright half. This sits on the flat half,
/// where your thumb already is, with a big "Got it".
struct DuoHelpPanel: View {
    let feature: DuoFeature
    /// White text, for the camera's dark deck.
    var onDark = false
    let onDone: () -> Void

    private var text: Color { onDark ? .white : Theme.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                DuoPoseIllustration(pose: feature.pose, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(text)
                    Text(feature.summary)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(text.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(feature.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.accent))
                        Text(step)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(text.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button(action: onDone) {
                Text("Got it")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(BouncyButtonStyle())
        }
        .frame(maxWidth: 520)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
