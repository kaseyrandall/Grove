import SwiftUI

/// A short, friendly first-run flow that plants the mental model:
/// **spot an animal → snap it → it comes home to your Grove.**
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let slides = OnboardingSlide.all

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") { onFinish() }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .opacity(page == slides.count - 1 ? 0 : 1)
                }

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        SlideView(slide: slide).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots
                    .padding(.bottom, 8)

                GroveButton(
                    title: page == slides.count - 1 ? "Start exploring 🌿" : "Next"
                ) {
                    if page < slides.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
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
            body: "Grow a place full of the life you've met - one photo at a time.",
            tint: Theme.mint
        ),
        OnboardingSlide(
            emojis: ["📸", "🦊"],
            title: "Spot & snap",
            body: "See an animal out in the wild? Take its photo and Grove figures out who it is - instantly, right on your phone.",
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

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(slide.tint.opacity(0.55))
                    .frame(width: 220, height: 220)

                // Hero emoji, with the smaller ones tucked around it.
                Text(slide.emojis.first ?? "")
                    .font(.system(size: 96))

                ForEach(Array(slide.emojis.dropFirst().enumerated()), id: \.offset) { i, emoji in
                    Text(emoji)
                        .font(.system(size: 40))
                        .offset(satellite(i, of: slide.emojis.count - 1))
                }
            }

            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(slide.body)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
    }

    /// Places the little satellite emojis evenly around the hero.
    private func satellite(_ index: Int, of count: Int) -> CGSize {
        guard count > 0 else { return .zero }
        let radius = 96.0
        let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
