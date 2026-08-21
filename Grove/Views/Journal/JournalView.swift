import SwiftUI
import SwiftData

/// The player's progress log: streak, level, sparks, achievements, and
/// collection stats — all derived from their `Catch` history via `PlayerStats`.
struct JournalView: View {
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
                    .padding(.bottom, Theme.tabBarClearance)
                }
            }
            .navigationTitle("Journal")
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
        case 0:  return "Catch a friend today to start one!"
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
            StatChip(value: "\(stats.totalSnaps)", label: "Friends", emoji: "🐾")
            StatChip(value: "\(stats.uniqueSpecies)", label: "Kinds", emoji: "🦋")
            StatChip(value: "\(stats.zonesVisited)/\(Habitat.allCases.count)", label: "Zones", emoji: "🌿")
        }
    }

    // MARK: Achievements summary

    /// How many badge dots to preview inline before collapsing to "+N".
    private let badgePreviewCap = 5

    private var achievementsCard: some View {
        let unlocked = AchievementCatalog.all.filter { $0.isUnlocked(stats) }
        return NavigationLink {
            AchievementsView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Text("🎖").font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievements")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(unlocked.count) of \(AchievementCatalog.all.count) unlocked")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.ink.opacity(0.3))
                }

                badgePreviewRow(unlocked: unlocked)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .softCard()
        }
        .buttonStyle(.plain)
    }

    /// A row of the badges you've unlocked — or a dimmed teaser of what's out
    /// there when you're just getting started.
    @ViewBuilder
    private func badgePreviewRow(unlocked: [Achievement]) -> some View {
        HStack(spacing: 8) {
            if unlocked.isEmpty {
                ForEach(AchievementCatalog.all.prefix(badgePreviewCap)) { achievement in
                    badgeDot(achievement.emoji, unlocked: false)
                }
            } else {
                ForEach(unlocked.prefix(badgePreviewCap)) { achievement in
                    badgeDot(achievement.emoji, unlocked: true)
                }
                if unlocked.count > badgePreviewCap {
                    Text("+\(unlocked.count - badgePreviewCap)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.ink.opacity(0.06)))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func badgeDot(_ emoji: String, unlocked: Bool) -> some View {
        ZStack {
            Circle()
                .fill(unlocked ? Theme.gold.opacity(0.5) : Theme.ink.opacity(0.06))
                .frame(width: 40, height: 40)
            Text(emoji)
                .font(.system(size: 20))
                .grayscale(unlocked ? 0 : 1)
                .opacity(unlocked ? 1 : 0.4)
        }
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(Rarity.allCases.reversed(), id: \.self) { rarity in
                    rarityTile(rarity)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private func rarityTile(_ rarity: Rarity) -> some View {
        let total = CreatureCatalog.all.filter { $0.rarity == rarity }.count
        let count = stats.count(of: rarity)
        let complete = count == total && total > 0
        return VStack(spacing: 5) {
            Text(rarity.badge).font(.system(size: 22))
            Text(rarity.title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(count)/\(total)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(complete ? Theme.accent : Theme.ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(rarity.tint.opacity(complete ? 0.35 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(complete ? rarity.tint : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    JournalView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
