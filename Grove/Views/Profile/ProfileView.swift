import SwiftUI
import SwiftData

/// The player's profile: a bit about them, a way into Settings, and (in DEBUG)
/// the developer test tools. Account/social features will grow from here.
struct ProfileView: View {
    @Query private var catches: [Catch]
    @Environment(\.modelContext) private var context

    private var stats: PlayerStats { PlayerStats(catches: catches) }

    /// Marketing version (e.g. "1.0"), read from the bundle so it never goes stale.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        achievementsCard
                        menuCard
                        #if DEBUG
                        developerCard
                        #endif
                        Text("Grove \(appVersion)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.35))
                            .padding(.top, 4)
                    }
                    .padding()
                    .padding(.bottom, Theme.tabBarClearance)
                }
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.mint.opacity(0.5)).frame(width: 96, height: 96)
                Text("🌿").font(.system(size: 44))
            }
            Text("Explorer")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Level \(stats.level) · \(stats.totalSnaps) friend\(stats.totalSnaps == 1 ? "" : "s") met")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .softCard()
    }

    // MARK: Achievements — your trophy shelf

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

    // MARK: Menu

    private var menuCard: some View {
        NavigationLink {
            SettingsView()
        } label: {
            row(icon: "gearshape.fill", title: "Settings & Preferences")
                .softCard()
        }
        .buttonStyle(.plain)
    }

    private func row(icon: String, title: String, tint: Color = Theme.accent) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.25))
        }
        .padding()
        .contentShape(Rectangle())
    }

    // MARK: Developer tools (compiled out of release builds)

    #if DEBUG
    private var seedBinding: Binding<Bool> {
        Binding(
            get: { SeedData.isPresent(in: catches) },
            set: { on in
                if on { SeedData.fill(context: context) }
                else { SeedData.clear(context: context) }
            }
        )
    }

    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEVELOPER")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.4))
                .padding(.leading, 6)

            Toggle(isOn: seedBinding) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)
                    Text("Sample Grove data")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .tint(Theme.accent)
            .padding()
            .softCard()
        }
    }
    #endif
}

#Preview {
    ProfileView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
