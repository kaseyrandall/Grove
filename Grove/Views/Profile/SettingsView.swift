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

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("locationTaggingEnabled") private var locationTaggingEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage(NotificationManager.memoriesEnabledKey) private var memoriesEnabled = true
    @AppStorage(AppUpdates.alertsEnabledKey) private var updateAlertsEnabled = true
    @ObservedObject private var updates = AppUpdates.shared
    @Environment(\.openURL) private var openURL

    @Environment(\.modelContext) private var context
    @Query private var catches: [Catch]
    @State private var showEraseConfirm = false

    var body: some View {
        VStack(spacing: 20) {
            if let release = updates.storeRelease { updateCard(release) }
            preferencesCard
            if let notes = ReleaseNotes.forVersion(AppUpdates.currentVersion) { whatsNewCard(notes) }
            if showsAbout { aboutCard }
            dangerZone
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
            ICloudSyncRow()

            Divider().padding(.leading, 56)

            Toggle(isOn: $notificationsEnabled) {
                settingLabel("Reminders", systemImage: "bell.fill")
            }
            .tint(Theme.accent)
            .padding()
            .onChange(of: notificationsEnabled) { _, on in
                NotificationManager.refresh(catches: catches, enabled: on)
            }

            Divider().padding(.leading, 56)

            Toggle(isOn: $memoriesEnabled) {
                settingLabel("Memories", systemImage: "heart.text.square.fill")
            }
            .tint(Theme.accent)
            .padding()
            .onChange(of: memoriesEnabled) { _, _ in
                NotificationManager.refresh(catches: catches, enabled: notificationsEnabled)
            }

            Divider().padding(.leading, 56)

            Toggle(isOn: $updateAlertsEnabled) {
                settingLabel("Update alerts", systemImage: "app.badge.fill")
            }
            .tint(Theme.accent)
            .padding()

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

    /// A newer Grove is on the App Store.
    private func updateCard(_ release: AppUpdates.StoreRelease) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text("Grove \(release.version) is here")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Update for the newest features and fixes.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Update") { openURL(release.trackViewUrl) }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.accent))
                .buttonStyle(BouncyButtonStyle())
        }
        .padding()
        .softCard()
    }

    private func whatsNewCard(_ notes: ReleaseNotes) -> some View {
        Button {
            updates.showWhatsNew()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text("What's new in \(notes.version)")
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
            BattleRoster.shared.reset()
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

/// The "iCloud backup" switch, with where the backup stands underneath:
/// "Backed up", or an orange note when it isn't (and what to do about it).
private struct ICloudSyncRow: View {
    @AppStorage(CloudSyncMonitor.syncEnabledKey) private var syncEnabled = true
    @ObservedObject private var monitor = CloudSyncMonitor.shared

    private var status: (text: String, warning: Bool) {
        if syncEnabled != CloudSyncMonitor.syncEnabledAtLaunch {
            return (syncEnabled ? "Turns on the next time you open Grove"
                                : "Turns off the next time you open Grove", false)
        }
        switch monitor.status {
        case .off:         return ("Off. Your Grove is only on this iPhone", false)
        case .checking:    return ("Checking…", false)
        case .backedUp:    return ("Backed up", false)
        case .notSignedIn: return ("Sign in to iCloud in Settings to back up", true)
        case .storageFull: return ("Paused: your iCloud storage is full", true)
        case .paused:      return ("Paused: couldn't reach iCloud. It'll catch up", true)
        }
    }

    var body: some View {
        let s = status
        Toggle(isOn: $syncEnabled) {
            HStack(spacing: 14) {
                Image(systemName: s.warning ? "exclamationmark.icloud.fill" : "icloud.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(s.warning ? Color.orange : Theme.accent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud backup")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(s.text)
                        .font(.system(.caption, design: .rounded, weight: s.warning ? .semibold : .regular))
                        .foregroundStyle(s.warning ? Color.orange : Theme.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.accent)
        .padding()
    }
}
