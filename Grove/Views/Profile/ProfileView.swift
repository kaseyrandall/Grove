import SwiftUI
import SwiftData

/// The player's profile: a bit about them, a way into Settings, and (in DEBUG)
/// the developer test tools. Account/social features will grow from here.
struct ProfileView: View {
    @Query private var catches: [Catch]
    @Environment(\.modelContext) private var context

    private var stats: PlayerStats { PlayerStats(catches: catches) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        menuCard
                        #if DEBUG
                        developerCard
                        #endif
                        Text("Grove v0.1")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.35))
                            .padding(.top, 4)
                    }
                    .padding()
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
            Text("Level \(stats.level) · \(stats.uniqueSpecies) friend\(stats.uniqueSpecies == 1 ? "" : "s") met")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .softCard()
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

            VStack(spacing: 0) {
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

                Divider().padding(.leading, 56)

                Button(role: .destructive) {
                    SeedData.eraseAll(context: context)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .frame(width: 26)
                        Text("Erase everything")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
            }
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
