import SwiftUI
import SwiftData

/// The whole world of friends, grouped by zone. The ones you've caught show in
/// full colour; the rest stay hidden as mystery "?" slots until you find and
/// unlock them, so each first meeting is a genuine discovery while still giving
/// everyone a sense of how much is left to collect.
struct FieldGuideView: View {
    @Query private var catches: [Catch]
    @State private var selected: Species?

    /// How many of each kind the player has caught.
    private var counts: [String: Int] {
        catches.reduce(into: [:]) { $0[$1.speciesID, default: 0] += 1 }
    }

    private var metCount: Int {
        Set(catches.map(\.speciesID))
            .intersection(Set(CreatureCatalog.all.map(\.id)))
            .count
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    summary
                    ForEach(Habitat.ordered) { zone in
                        section(zone)
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Field Guide")
        .navigationBarTitleDisplayMode(.inline)
        .groveTabBarHidden()
        .sheet(item: $selected) { species in
            SpeciesGuideSheet(species: species, count: counts[species.id] ?? 0)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var summary: some View {
        let total = CreatureCatalog.all.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Friends met")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(metCount)/\(total)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            ProgressView(value: Double(metCount), total: Double(max(total, 1)))
                .tint(Theme.accent)
        }
        .padding()
        .softCard()
    }

    private func section(_ zone: Habitat) -> some View {
        let species = CreatureCatalog.species(in: zone)
        let met = species.filter { (counts[$0.id] ?? 0) > 0 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("\(zone.emoji) \(zone.shortName)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(met)/\(species.count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.45))
            }
            .padding(.leading, 6)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(species) { s in
                    GuideTile(species: s, count: counts[s.id] ?? 0) { selected = s }
                }
            }
        }
    }
}

/// One friend in the guide: full colour once met, a hidden silhouette until
/// then. Unmet friends keep their identity secret — a "?" stands in for the
/// emoji and name — so meeting one for the first time stays a discovery.
private struct GuideTile: View {
    let species: Species
    let count: Int
    let onTap: () -> Void

    private var met: Bool { count > 0 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(met ? species.emoji : "❓")
                    .font(.system(size: 34))
                    .grayscale(met ? 0 : 1)
                    .opacity(met ? 1 : 0.4)
                Text(met ? species.name : "???")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(met ? Theme.ink : Theme.ink.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(met ? Color.white : Color.white.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(met ? species.rarity.tint : Theme.ink.opacity(0.08),
                            lineWidth: met ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("×\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(species.rarity.tint.opacity(0.5)))
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Tap a guide entry for a closer look. A caught friend shows its lore; an
/// unmet one shows a gentle nudge toward where to find it.
private struct SpeciesGuideSheet: View {
    let species: Species
    let count: Int

    private var met: Bool { count > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(met ? species.rarity.tint.opacity(0.5) : Theme.ink.opacity(0.06))
                        .frame(width: 96, height: 96)
                    Text(met ? species.emoji : "❓")
                        .font(.system(size: 48))
                        .grayscale(met ? 0 : 1)
                        .opacity(met ? 1 : 0.45)
                }
                .padding(.top, 12)

                Text(met ? species.name : "???")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                if met {
                    RarityBadge(rarity: species.rarity)
                }

                if met {
                    Text(species.blurb)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Label(species.habitatNote, systemImage: "leaf.fill")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    Text("You've met \(count) 🌿")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("You haven't met this friend yet — find and unlock it to reveal who it is.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Label("Keep exploring the \(species.zone.shortName) to discover it.",
                          systemImage: "map.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
