import SwiftUI
import SwiftData

/// The player's home base: level, sparks, and collection stats — all derived
/// from their `Catch` history.
struct ProfileView: View {
    @Query private var catches: [Catch]

    private var totalSparks: Int { catches.reduce(0) { $0 + $1.sparksEarned } }
    private var level: Int { Progression.level(forTotalSparks: totalSparks) }
    private var levelProgress: Double { Progression.levelProgress(forTotalSparks: totalSparks) }
    private var uniqueCaught: Int { Set(catches.map(\.speciesID)).count }
    private var totalSnaps: Int { catches.count }

    private var rarityCounts: [(Rarity, Int)] {
        let caughtSpecies = Set(catches.map(\.speciesID))
            .compactMap { CreatureCatalog.species(for: $0) }
        return Rarity.allCases.reversed().map { rarity in
            (rarity, caughtSpecies.filter { $0.rarity == rarity }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        levelCard
                        statsRow
                        rarityCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Me")
        }
    }

    private var levelCard: some View {
        VStack(spacing: 12) {
            Text("🌟").font(.system(size: 52))
            Text("Level \(level)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("\(totalSparks) ✨ sparks total")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
            ProgressView(value: levelProgress)
                .tint(Theme.accent)
                .padding(.horizontal)
            Text("Keep snapping to reach Level \(level + 1)!")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChip(value: "\(uniqueCaught)", label: "Species", emoji: "🦋")
            StatChip(value: "\(totalSnaps)", label: "Snaps", emoji: "📸")
            StatChip(value: "\(CreatureCatalog.all.count - uniqueCaught)", label: "To Find", emoji: "🔍")
        }
    }

    private var rarityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Collection by rarity")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)

            ForEach(rarityCounts, id: \.0) { rarity, count in
                let total = CreatureCatalog.all.filter { $0.rarity == rarity }.count
                HStack {
                    Text("\(rarity.badge) \(rarity.title)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(count)/\(total)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(count == total && total > 0 ? Theme.accent : Theme.ink.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
