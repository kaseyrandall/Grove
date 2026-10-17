import SwiftUI
import SwiftData

/// Preferences and app options. Kept intentionally small for now; grows as the
/// app does (accounts, notifications, etc.).
struct SettingsView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                SettingsContent()
                    .padding()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .groveTabBarHidden()
    }
}

/// The settings themselves, shared by the Settings page and the Profile
/// spread on the open iPhone Duo (where About has its own menu row, so its
/// link here is left out).
struct SettingsContent: View {
    var showsAbout = true

    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenSnapCoach = false
    @AppStorage("hasSeenMeetCoach") private var hasSeenMeetCoach = false
    @AppStorage("hasSeenGoalCoach") private var hasSeenGoalCoach = false
    @AppStorage("hasSeenGroveIntro") private var hasSeenGroveIntro = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("locationTaggingEnabled") private var locationTaggingEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @Environment(\.modelContext) private var context
    @Query private var catches: [Catch]
    @State private var showReplayConfirm = false
    @State private var showEraseConfirm = false

    var body: some View {
        VStack(spacing: 20) {
            ICloudStatusCard()
            preferencesCard
            introCard
            if showsAbout { aboutCard }
            dangerZone
        }
        .alert("Intro reset", isPresented: $showReplayConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The welcome tour will show the next time you open Grove.")
        }
        .confirmationDialog("Erase everything?", isPresented: $showEraseConfirm, titleVisibility: .visible) {
            Button("Erase my whole Grove", role: .destructive) { eraseAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This releases every friend and resets your Grove, here and in iCloud on all your devices. This can't be undone.")
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
            hasSeenSnapCoach = false
            hasSeenMeetCoach = false
            hasSeenGoalCoach = false
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

    private var aboutCard: some View {
        NavigationLink {
            AboutView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text("About Grove")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.25))
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

/// Where the Grove's iCloud backup stands: a reassuring line when all's well,
/// and a clear note (with what to do) when syncing has stopped.
private struct ICloudStatusCard: View {
    @ObservedObject private var monitor = CloudSyncMonitor.shared

    private var content: (icon: String, title: String, detail: String, warning: Bool) {
        switch monitor.status {
        case .checking:
            return ("icloud", "iCloud", "Checking your iCloud backup…", false)
        case .backedUp:
            return ("checkmark.icloud.fill", "Backed up to iCloud",
                    "Your Grove comes back on a new device or after reinstalling.", false)
        case .notSignedIn:
            return ("icloud.slash", "Not backed up",
                    "Sign in to iCloud in Settings to keep your Grove safe. Until then it lives only on this device.", true)
        case .storageFull:
            return ("exclamationmark.icloud.fill", "iCloud sync paused",
                    "Your iCloud storage is full, so new friends aren't backed up. Free up space or add storage in Settings, and Grove will catch up.", true)
        case .paused:
            return ("exclamationmark.icloud.fill", "iCloud sync paused",
                    "Grove couldn't reach iCloud just now. Your Grove is safe on this device and will catch up.", true)
        }
    }

    var body: some View {
        let c = content
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: c.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(c.warning ? Color.orange : Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(c.detail)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .softCard()
        .accessibilityElement(children: .combine)
    }
}
