import SwiftUI
import SwiftData

/// A grid of every achievement, showing unlocked badges in full color and
/// locked ones dimmed with a live progress bar — the "so close!" hook.
struct AchievementsView: View {
    @Query private var catches: [Catch]

    private var stats: PlayerStats { PlayerStats(catches: catches) }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                summary
                    .padding(.horizontal)
                    .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AchievementCatalog.all) { achievement in
                        AchievementCard(achievement: achievement, stats: stats)
                    }
                }
                .padding()
                .padding(.bottom, Theme.tabBarClearance)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        let unlocked = AchievementCatalog.unlockedCount(stats)
        let total = AchievementCatalog.all.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Badges earned")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(unlocked)/\(total)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            ProgressView(value: Double(unlocked), total: Double(max(total, 1)))
                .tint(Theme.accent)
        }
        .padding()
        .softCard()
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let stats: PlayerStats

    private var unlocked: Bool { achievement.isUnlocked(stats) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? Theme.gold.opacity(0.5) : Theme.ink.opacity(0.06))
                    .frame(width: 70, height: 70)
                Text(achievement.emoji)
                    .font(.system(size: 34))
                    .grayscale(unlocked ? 0 : 1)
                    .opacity(unlocked ? 1 : 0.45)
            }

            Text(achievement.title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(achievement.detail)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if unlocked {
                Text("✓ Unlocked")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
            } else {
                VStack(spacing: 3) {
                    ProgressView(value: achievement.progress(stats))
                        .tint(Theme.accent)
                    Text(achievement.progressLabel(stats))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .softCard(fill: unlocked ? .white : Color.white.opacity(0.7))
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
    .modelContainer(for: Catch.self, inMemory: true)
    .tint(Theme.accent)
    .fontDesign(.rounded)
}
