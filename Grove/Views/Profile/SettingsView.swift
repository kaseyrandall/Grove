import SwiftUI
import SwiftData

/// Preferences and app options. Kept intentionally small for now; grows as the
/// app does (accounts, notifications, etc.).
struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenCoachMark = false
    @AppStorage("hasSeenGroveIntro") private var hasSeenGroveIntro = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("locationTaggingEnabled") private var locationTaggingEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @Environment(\.modelContext) private var context
    @Query private var catches: [Catch]
    @State private var showReplayConfirm = false
    @State private var showEraseConfirm = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    preferencesCard
                    introCard
                    dangerZone
                }
                .padding()
                .padding(.bottom, Theme.tabBarClearance)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .groveTabBarHidden()
        .alert("Intro reset", isPresented: $showReplayConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The welcome tour will show the next time you open Grove.")
        }
        .confirmationDialog("Erase everything?", isPresented: $showEraseConfirm, titleVisibility: .visible) {
            Button("Erase my whole Grove", role: .destructive) { eraseAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This releases every friend and resets your Grove. This can't be undone.")
        }
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $notificationsEnabled) {
                settingLabel("Reminders", systemImage: "bell.fill")
            }
            .tint(Theme.accent)
            .padding()
            .onChange(of: notificationsEnabled) { _, on in
                if on {
                    NotificationManager.refresh(catches: catches, enabled: true)
                } else {
                    NotificationManager.cancelAll()
                }
            }

            Divider().padding(.leading, 56)

            Toggle(isOn: $hapticsEnabled) {
                settingLabel("Haptics", systemImage: "hand.tap.fill")
            }
            .tint(Theme.accent)
            .padding()

            Divider().padding(.leading, 56)

            Toggle(isOn: $locationTaggingEnabled) {
                settingLabel("Tag catches with location", systemImage: "location.fill")
            }
            .tint(Theme.accent)
            .padding()
        }
        .softCard()
    }

    private var introCard: some View {
        Button {
            hasOnboarded = false
            hasSeenCoachMark = false
            hasSeenGroveIntro = false
            showReplayConfirm = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text("Replay the intro")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .softCard()
        }
        .buttonStyle(.plain)
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DANGER ZONE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0xE9698A))
                .padding(.leading, 6)

            Button(role: .destructive) {
                showEraseConfirm = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0xE9698A))
                        .frame(width: 26)
                    Text("Erase everything")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xE9698A))
                    Spacer()
                }
                .padding()
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color(hex: 0xE9698A).opacity(0.35), lineWidth: 1.5))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func eraseAll() {
        if let all = try? context.fetch(FetchDescriptor<Catch>()) {
            for c in all { context.delete(c) }
            try? context.save()
        }
    }

    private func settingLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
