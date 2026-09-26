import SwiftUI

/// A short, friendly first-run flow that plants the mental model:
/// **spot an animal → snap it → it comes home to your Grove.**
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    /// The open Duo in landscape: each slide's picture on the left page, its
    /// words and the buttons on the right.
    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX

    private let slides = OnboardingSlide.all

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isSpread {
                spreadBody
            } else {
                VStack(spacing: 0) {
                    // Skip
                    HStack {
                        Spacer()
                        skipButton
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    TabView(selection: $page) {
                        ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                            SlideView(slide: slide).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    dots
                        .padding(.bottom, 8)

                    nextButton
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                }
            }
        }
    }

    private var skipButton: some View {
        Button("Skip") { onFinish() }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.ink.opacity(0.5))
            .opacity(page == slides.count - 1 ? 0 : 1)
    }

    private var nextButton: some View {
        GroveButton(
            title: page == slides.count - 1 ? "Start exploring 🌿" : "Next"
        ) {
            if page < slides.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
            } else {
                onFinish()
            }
        }
    }

    /// The slides still swipe as one; each lays out across both pages, and the
    /// Skip / dots / Next controls sit on the right page over them.
    private var spreadBody: some View {
        GeometryReader { geo in
            let pages = DuoSpread.pageWidths(in: geo.frame(in: .global), foldX: foldX,
                                             leading: 24, trailing: 24)
            ZStack {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        SlideView(slide: slide, spreadPages: pages).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: pages.leading + DuoSpread.foldGutter * 2)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Spacer()
                            skipButton
                        }
                        Spacer()
                        dots
                        nextButton
                    }
                    .frame(width: pages.trailing)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.accent : Theme.ink.opacity(0.15))
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
            }
        }
    }
}

/// One onboarding page's content.
struct OnboardingSlide {
    let emojis: [String]     // a little scene, largest first
    let title: String
    let body: String
    let tint: Color

    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            emojis: ["🌳", "🦊", "🐿️", "🦆"],
            title: "Welcome to Grove",
            body: "Grow a place full of the life you've met, one photo at a time.",
            tint: Theme.mint
        ),
        OnboardingSlide(
            emojis: ["📸", "🦊"],
            title: "Snap & name",
            body: "See an animal out in the wild? Snap a photo, then pick who it is from the field guide — your new friend, named by you.",
            tint: Theme.sky
        ),
        OnboardingSlide(
            emojis: ["🏡", "🌊", "🌲"],
            title: "A home for every friend",
            body: "Every friend you meet settles into its cozy corner of your world. Keep exploring to fill each habitat with life.",
            tint: Theme.lavender
        ),
    ]
}

private struct SlideView: View {
    let slide: OnboardingSlide
    /// The two page widths on the open Duo's spread (nil on every other screen).
    var spreadPages: (leading: CGFloat, trailing: CGFloat)? = nil

    var body: some View {
        if let pages = spreadPages {
            // Picture on the left page; the words on the right, above the
            // controls that OnboardingView lays over them.
            HStack(spacing: DuoSpread.foldGutter * 2) {
                illustration(scale: 1.35)
                    .frame(width: pages.leading)
                VStack(alignment: .leading, spacing: 14) {
                    Spacer()
                    Text(slide.title)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(slide.body)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.72))
                        .lineSpacing(5)
                    Spacer()
                    Spacer().frame(height: 130) // room for the dots and Next
                }
                .frame(width: pages.trailing, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 28) {
                Spacer()

                illustration(scale: 1)

                VStack(spacing: 14) {
                    Text(slide.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)

                    Text(slide.body)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 32)
                }

                Spacer()
                Spacer()
            }
        }
    }

    /// The slide's little scene: a hero emoji in a soft circle, with the
    /// smaller ones tucked around it.
    private func illustration(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(slide.tint.opacity(0.55))
                .frame(width: 220 * scale, height: 220 * scale)

            Text(slide.emojis.first ?? "")
                .font(.system(size: 96 * scale))

            ForEach(Array(slide.emojis.dropFirst().enumerated()), id: \.offset) { i, emoji in
                Text(emoji)
                    .font(.system(size: 40 * scale))
                    .offset(satellite(i, of: slide.emojis.count - 1, radius: 96 * scale))
            }
        }
    }

    /// Places the little satellite emojis evenly around the hero.
    private func satellite(_ index: Int, of count: Int, radius: Double) -> CGSize {
        guard count > 0 else { return .zero }
        let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
