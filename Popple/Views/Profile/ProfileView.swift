import SwiftUI
import SwiftData

/// The player's home base: streak, level, sparks, achievements, and collection
/// stats — all derived from their `Catch` history via `PlayerStats`.
struct ProfileView: View {
    @Query private var catches: [Catch]

    private var stats: PlayerStats { PlayerStats(catches: catches) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        streakCard
                        levelCard
                        statsRow
                        achievementsCard
                        rarityCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Me")
        }
    }

    // MARK: Streak

    private var streakCard: some View {
        HStack(spacing: 16) {
            Text("🔥").font(.system(size: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.currentStreak)-day streak")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(streakMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(stats.longestStreak)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("best")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private var streakMessage: String {
        switch stats.currentStreak {
        case 0:  return "Catch a critter today to start one!"
        case 1:  return "Nice start — come back tomorrow!"
        default: return "You're on a roll. Keep it going!"
        }
    }

    // MARK: Level

    private var levelCard: some View {
        VStack(spacing: 12) {
            Text("🌟").font(.system(size: 48))
            Text("Level \(stats.level)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("\(stats.totalSparks) ✨ sparks total")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
            ProgressView(value: stats.levelProgress)
                .tint(Theme.accent)
                .padding(.horizontal)
            Text("Keep snapping to reach Level \(stats.level + 1)!")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .softCard()
    }

    // MARK: Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChip(value: "\(stats.uniqueSpecies)", label: "Species", emoji: "🦋")
            StatChip(value: "\(stats.totalSnaps)", label: "Snaps", emoji: "📸")
            StatChip(value: "\(CreatureCatalog.all.count - stats.uniqueSpecies)", label: "To Find", emoji: "🔍")
        }
    }

    // MARK: Achievements summary

    private var achievementsCard: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            HStack(spacing: 16) {
                Text("🎖").font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("\(AchievementCatalog.unlockedCount(stats)) of \(AchievementCatalog.all.count) unlocked")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.ink.opacity(0.3))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .softCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Rarity

    private var rarityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Collection by rarity")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let rarest = stats.rarestCaught {
                    Text("Rarest: \(rarest.emoji) \(rarest.name)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
            }

            ForEach(Rarity.allCases.reversed(), id: \.self) { rarity in
                let total = CreatureCatalog.all.filter { $0.rarity == rarity }.count
                let count = stats.count(of: rarity)
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
