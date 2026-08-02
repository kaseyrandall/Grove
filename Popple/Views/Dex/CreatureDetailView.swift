import SwiftUI

/// Detail page for one critter: its story, and your history with it.
struct CreatureDetailView: View {
    let species: Species
    let catches: [Catch]

    private var isCaught: Bool { !catches.isEmpty }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    hero
                    infoCard
                    if isCaught { sightingsCard }
                }
                .padding()
            }
        }
        .navigationTitle(isCaught ? species.name : "???")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(species.rarity.tint.opacity(isCaught ? 0.6 : 0.2))
                .frame(width: 180, height: 180)
            Text(isCaught ? species.emoji : "❓")
                .font(.system(size: 90))
                .opacity(isCaught ? 1 : 0.4)
        }
        .padding(.top, 12)
    }

    private var infoCard: some View {
        VStack(spacing: 14) {
            RarityBadge(rarity: species.rarity)

            Text(isCaught ? species.blurb : "You haven't spotted this critter yet. Keep exploring!")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Divider()

            HStack {
                Label(species.habitat, systemImage: "leaf.fill")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                Spacer()
                Label("\(species.rarity.sparks) ✨", systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private var sightingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your sightings (\(catches.count))")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catches) { c in
                        VStack(spacing: 6) {
                            if let data = c.photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.ink.opacity(0.06))
                                    .frame(width: 96, height: 96)
                                    .overlay(Text(species.emoji).font(.largeTitle))
                            }
                            Text(c.caughtAt, format: .dateTime.month().day())
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}
