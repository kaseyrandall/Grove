import SwiftUI
import SwiftData

/// The whole world of friends, as one collection checklist. Friends you've met
/// show in full colour with their rarity; the rest are greyed out but still
/// recognisable, so you can see what's out there to find. There's no zone
/// grouping — where a friend lives is up to you, in your Grove.
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

    /// Every kind, A–Z, so any friend is easy to find.
    private var allSpecies: [Species] {
        CreatureCatalog.all.sorted { $0.name < $1.name }
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    summary
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(allSpecies) { s in
                            GuideTile(species: s, count: counts[s.id] ?? 0) { selected = s }
                        }
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
}

/// One friend in the guide: full colour once met, greyed but still recognisable
/// until then — a collection you can see and fill in, not a set of secrets.
private struct GuideTile: View {
    let species: Species
    let count: Int
    let onTap: () -> Void

    private var met: Bool { count > 0 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(species.emoji)
                    .font(.system(size: 34))
                    .grayscale(met ? 0 : 1)
                    .opacity(met ? 1 : 0.45)
                Text(species.name)
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

/// Tap a guide entry for a closer look. A met friend shows its lore and how many
/// you've welcomed; an unmet one shows what it is and a nudge to go find one.
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
                    Text(species.emoji)
                        .font(.system(size: 48))
                        .grayscale(met ? 0 : 1)
                        .opacity(met ? 1 : 0.45)
                }
                .padding(.top, 12)

                Text(species.name)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(met ? Theme.ink : Theme.ink.opacity(0.55))

                RarityBadge(rarity: species.rarity)

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
                    Text("You haven't met this friend yet.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Label("Snap one out in the wild to welcome it home.",
                          systemImage: "camera.fill")
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
