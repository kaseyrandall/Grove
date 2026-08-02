import SwiftUI

/// A big, bouncy, friendly primary button.
struct PoppleButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(Theme.accent)
            )
            .shadow(color: Theme.accent.opacity(0.4), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

/// Gives buttons a gentle spring-y press.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A small pill showing a rarity, e.g. "💎 Rare".
struct RarityBadge: View {
    let rarity: Rarity
    var body: some View {
        Text("\(rarity.badge) \(rarity.title)")
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(rarity.tint))
    }
}

/// A rounded stat chip used on the profile screen.
struct StatChip: View {
    let value: String
    let label: String
    var emoji: String

    var body: some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title2)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label).font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .softCard()
    }
}
