import SwiftUI

/// Preferences and app options. Kept intentionally small for now; grows as the
/// app does (accounts, notifications, etc.).
struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenCoachMark = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("locationTaggingEnabled") private var locationTaggingEnabled = true

    @State private var showReplayConfirm = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    preferencesCard
                    introCard
                }
                .padding()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Intro reset", isPresented: $showReplayConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The welcome tour will show the next time you open Grove.")
        }
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
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
