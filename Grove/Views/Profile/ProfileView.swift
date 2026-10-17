import SwiftUI
import SwiftData

/// The player's profile: a bit about them, a way into Settings, and (in DEBUG)
/// the developer test tools. Account/social features will grow from here.
struct ProfileView: View {
    @Query private var catches: [Catch]
    @Environment(\.modelContext) private var context

    /// The player's chosen avatar look (emoji + background). Tap the header to change it.
    @AppStorage("profileEmoji") private var profileEmoji = "🌿"
    @AppStorage("profileColorHex") private var profileColorHex = ProfileLookPicker.defaultColor
    @State private var showLookPicker = false

    /// The open Duo in landscape: the menu on the left page, the chosen
    /// section on the right.
    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX
    @State private var section: ProfileSection = .achievements

    private var stats: PlayerStats { PlayerStats(catches: catches) }

    /// Marketing version (e.g. "1.0"), read from the bundle so it never goes stale.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if isSpread {
                    spreadLayout
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerCard
                            achievementsCard
                            menuCard
                            privacyCard
                            #if DEBUG
                            arenaCard
                            developerCard
                            #endif
                            versionLabel
                        }
                        .padding()
                    }
                }
            }
            .clearsGroveTabBar()
            .navigationTitle("Profile")
            // The spread draws its own titles on each page.
            .toolbar(isSpread ? .hidden : .automatic, for: .navigationBar)
            #if DEBUG
            // Test hooks: `-GroveProfileSection settings|about` opens that
            // section; `-GroveOpenLook` opens Choose your look.
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-GroveOpenLook") { showLookPicker = true }
                if let i = args.firstIndex(of: "-GroveProfileSection"), i + 1 < args.count {
                    section = args[i + 1] == "settings" ? .settings : args[i + 1] == "about" ? .about : .achievements
                }
            }
            #endif
            .groveSheet(isPresented: $showLookPicker) {
                ProfileLookPicker(emoji: $profileEmoji, colorHex: $profileColorHex)
            }
        }
    }

    private var versionLabel: some View {
        Text("Grove \(appVersion)")
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(Theme.ink.opacity(0.35))
            .padding(.top, 4)
    }

    // MARK: Spread (the open Duo in landscape)

    /// Your profile and a menu on the left page; the chosen section opens on
    /// the right — the list-and-detail layout Apple uses for Mail on the Duo.
    /// Each page scrolls on its own.
    private var spreadLayout: some View {
        GeometryReader { geo in
            let pages = DuoSpread.pageWidths(in: geo.frame(in: .global), foldX: foldX,
                                             leading: 16, trailing: 16)
            HStack(alignment: .top, spacing: DuoSpread.foldGutter * 2) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        spreadTitle("Profile")
                        headerCard
                        sectionMenu
                        privacyCard
                        #if DEBUG
                        arenaCard
                        developerCard
                        #endif
                        versionLabel
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical)
                }
                .frame(width: pages.leading)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        spreadTitle(section.title)
                        switch section {
                        case .achievements: AchievementsContent()
                        case .settings:     SettingsContent(showsAbout: false)
                        case .about:        AboutContent()
                        }
                    }
                    .padding(.vertical)
                }
                .frame(width: pages.trailing)
            }
            .padding(.horizontal, 16)
            .frame(width: geo.size.width, alignment: .topLeading)
        }
    }

    private func spreadTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.ink)
    }

    /// The left page's menu: picking a row opens that section on the right.
    private var sectionMenu: some View {
        let unlocked = AchievementCatalog.all.filter { $0.isUnlocked(stats) }.count
        return VStack(spacing: 2) {
            sectionRow(.achievements, icon: "medal.fill",
                       subtitle: "\(unlocked) of \(AchievementCatalog.all.count) unlocked")
            sectionRow(.settings, icon: "gearshape.fill", subtitle: nil)
            sectionRow(.about, icon: "leaf.fill", subtitle: nil)
        }
        .padding(8)
        .softCard()
    }

    private func sectionRow(_ row: ProfileSection, icon: String, subtitle: String?) -> some View {
        let selected = section == row
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { section = row }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.menuTitle)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accent : Theme.ink.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            Button {
                showLookPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(Color(hex: UInt(profileColorHex))).frame(width: 96, height: 96)
                        Text(profileEmoji).font(.system(size: 44))
                    }
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.accent)
                        .background(Circle().fill(.white).frame(width: 24, height: 24))
                }
            }
            .buttonStyle(.plain)
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

    // MARK: Privacy — a gentle reassurance that the Grove is theirs alone

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Private by design")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Everything you collect stays yours, on this device and in your own iCloud.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                privacyChip("No account")
                privacyChip("No tracking")
                privacyChip("Works offline")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private func privacyChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink.opacity(0.7))
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(Theme.ink.opacity(0.06)))
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

    private var arenaCard: some View {
        NavigationLink {
            BattlegroundsView()
        } label: {
            row(icon: "bolt.shield.fill", title: "Battlegrounds")
                .softCard()
        }
        .buttonStyle(.plain)
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

/// The sections the Profile spread can show on its right page.
private enum ProfileSection {
    case achievements, settings, about

    /// The row's name in the menu.
    var menuTitle: String {
        switch self {
        case .achievements: return "Achievements"
        case .settings:     return "Settings & Preferences"
        case .about:        return "About Grove"
        }
    }

    /// The right page's title.
    var title: String {
        switch self {
        case .achievements: return "Achievements"
        case .settings:     return "Settings"
        case .about:        return "About"
        }
    }
}
