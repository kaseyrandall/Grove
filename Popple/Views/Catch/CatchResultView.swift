import SwiftUI

/// The joyful "you caught it!" celebration.
struct CatchResultView: View {
    let result: CatchResult
    @Environment(\.dismiss) private var dismiss

    @State private var popped = false

    var body: some View {
        ZStack {
            result.species.rarity.tint.opacity(0.35).ignoresSafeArea()
            Theme.background.opacity(0.4).ignoresSafeArea()

            if result.species.rarity >= .rare {
                Confetti()
            }

            VStack(spacing: 20) {
                Spacer()

                Text(result.isFirstSighting ? "New critter!" : "Caught again!")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.7))

                // The photo, framed like a sticker.
                Image(uiImage: result.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white, lineWidth: 6)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Text(result.species.emoji)
                            .font(.system(size: 44))
                            .padding(8)
                            .background(Circle().fill(.white))
                            .offset(x: 10, y: 10)
                    }
                    .shadow(color: Theme.ink.opacity(0.15), radius: 16, y: 8)
                    .scaleEffect(popped ? 1 : 0.6)
                    .rotationEffect(.degrees(popped ? 0 : -8))

                VStack(spacing: 8) {
                    Text(result.species.name)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    RarityBadge(rarity: result.species.rarity)
                }

                // Sparks earned
                HStack(spacing: 6) {
                    Text("✨")
                    Text("+\(result.sparks) sparks")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    if result.isFirstSighting {
                        Text("· 2× first find!")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .softCard()

                if !result.newAchievements.isEmpty {
                    achievementsUnlocked
                }

                Spacer()

                PoppleButton(title: "Sweet!", systemImage: "checkmark") {
                    dismiss()
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                popped = true
            }
        }
    }

    private var achievementsUnlocked: some View {
        VStack(spacing: 8) {
            Text("🎖 Achievement\(result.newAchievements.count > 1 ? "s" : "") unlocked!")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.accent)
            ForEach(result.newAchievements) { achievement in
                HStack(spacing: 8) {
                    Text(achievement.emoji).font(.title3)
                    Text(achievement.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .softCard(fill: .white.opacity(0.9))
    }
}

/// A cheap, cheerful emoji confetti burst for the rarer catches.
struct Confetti: View {
    private let pieces = ["✨", "🎉", "⭐️", "💫", "🌸"]
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<24, id: \.self) { i in
                    Text(pieces[i % pieces.count])
                        .font(.system(size: CGFloat.random(in: 18...30)))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .animation(
                            .easeIn(duration: Double.random(in: 1.8...3.2))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...1.5)),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
