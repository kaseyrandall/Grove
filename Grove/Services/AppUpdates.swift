import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

/// Tells the player about new versions of Grove, two ways:
///
/// - **A new version is on the App Store.** Grove asks Apple's public lookup
///   service (no account, nothing about the player is sent) at most twice a
///   day — on launch and from a background refresh — and posts one
///   notification per new version.
/// - **Grove just updated itself** (automatic updates). The first time the new
///   build runs, it posts a "new features" notification if it's woken in the
///   background, and shows the What's New sheet the next time it's opened.
///   Only versions with entries in `ReleaseNotes` announce anything.
///
/// Background refresh is at the system's discretion, so the notifications are
/// best-effort; the in-app What's New sheet and Settings card always catch up.
@MainActor
final class AppUpdates: ObservableObject {
    static let shared = AppUpdates()
    /// Listed under `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    nonisolated static let refreshTaskID = "com.kaseyrandall.grove.refresh"

    nonisolated static let updateAvailableNotificationID = "grove.update.available"
    nonisolated static let newFeaturesNotificationID = "grove.update.installed"

    /// A newer version on the App Store, once one has been seen.
    @Published private(set) var storeRelease: StoreRelease?
    /// Release notes to show in the What's New sheet, if any are waiting.
    @Published var whatsNew: ReleaseNotes?

    struct StoreRelease: Codable, Equatable {
        let version: String
        let releaseNotes: String?
        let trackViewUrl: URL
        let minimumOsVersion: String?
    }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let lastLaunchedVersion = "updates.lastLaunchedVersion"
        static let pendingWhatsNew = "updates.pendingWhatsNewVersion"
        static let announcedInstalled = "updates.announcedInstalledVersion"
        static let notifiedStoreVersion = "updates.notifiedStoreVersion"
        static let lastStoreCheck = "updates.lastStoreCheck"
        static let storeRelease = "updates.storeRelease"
    }
    /// The Settings toggle ("Update alerts").
    nonisolated static let alertsEnabledKey = "updateAlertsEnabled"
    private var alertsEnabled: Bool { defaults.object(forKey: Self.alertsEnabledKey) as? Bool ?? true }

    nonisolated private static let storeCheckInterval: TimeInterval = 12 * 60 * 60

    nonisolated static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Remembers the last newer release seen, so the Settings card survives a
    /// relaunch between checks (and drops it once that version is installed).
    private init() {
        if let data = defaults.data(forKey: Key.storeRelease),
           let saved = try? JSONDecoder().decode(StoreRelease.self, from: data),
           saved.version.isNewerVersion(than: Self.currentVersion) {
            storeRelease = saved
        }
    }

    // MARK: Entry points

    /// On every trip to the foreground: notice an install that just happened,
    /// surface its What's New, and look for a newer App Store version.
    func appBecameActive() {
        noteRunningVersion(inBackground: false)
        if let pending = defaults.string(forKey: Key.pendingWhatsNew),
           pending == Self.currentVersion, let notes = ReleaseNotes.forVersion(pending) {
            whatsNew = notes
        }
        Task { await checkStore() }
    }

    /// The What's New sheet was closed; don't show it again for this version.
    func dismissWhatsNew() {
        whatsNew = nil
        defaults.removeObject(forKey: Key.pendingWhatsNew)
    }

    /// Re-open What's New from Settings.
    func showWhatsNew() {
        whatsNew = ReleaseNotes.forVersion(Self.currentVersion)
    }

    /// A background refresh: the same checks, announced by notification
    /// since nobody's looking at the app.
    func backgroundCheck() async {
        noteRunningVersion(inBackground: true)
        await checkStore()
    }

    // MARK: Installed updates

    /// Compare the running version with the one that ran last. A fresh install
    /// stays quiet; a player who had Grove before (even before this version
    /// tracking existed) gets the news.
    private func noteRunningVersion(inBackground: Bool) {
        let current = Self.currentVersion
        let last = defaults.string(forKey: Key.lastLaunchedVersion)
        defaults.set(current, forKey: Key.lastLaunchedVersion)

        let isUpgrade: Bool
        if let last {
            isUpgrade = current.isNewerVersion(than: last)
        } else {
            isUpgrade = defaults.bool(forKey: "hasCompletedOnboarding")
        }
        guard isUpgrade, let notes = ReleaseNotes.forVersion(current) else { return }

        defaults.set(current, forKey: Key.pendingWhatsNew)
        // One notification per version: skip this if the App Store one
        // already told them about it.
        if inBackground, alertsEnabled, defaults.string(forKey: Key.announcedInstalled) != current,
           defaults.string(forKey: Key.notifiedStoreVersion) != current {
            defaults.set(current, forKey: Key.announcedInstalled)
            // Lead with the headline feature, and open where it lives.
            let headline = notes.items.first
            NotificationManager.postNow(
                id: Self.newFeaturesNotificationID,
                title: headline.map { "\($0.emoji) \($0.title)" } ?? "Grove just got new features ✨",
                body: headline?.detail ?? "Tap to see what's new.",
                action: headline?.destination.map { .open($0) } ?? .whatsNew)
        }
    }

    // MARK: App Store

    private func checkStore() async {
        if let last = defaults.object(forKey: Key.lastStoreCheck) as? Date,
           Date.now.timeIntervalSince(last) < Self.storeCheckInterval {
            return
        }
        guard let release = await Self.fetchStoreRelease() else { return }
        defaults.set(Date.now, forKey: Key.lastStoreCheck)

        let os = UIDevice.current.systemVersion
        guard release.version.isNewerVersion(than: Self.currentVersion),
              !(release.minimumOsVersion?.isNewerVersion(than: os) ?? false) else {
            storeRelease = nil
            defaults.removeObject(forKey: Key.storeRelease)
            return
        }
        storeRelease = release
        defaults.set(try? JSONEncoder().encode(release), forKey: Key.storeRelease)

        guard alertsEnabled, defaults.string(forKey: Key.notifiedStoreVersion) != release.version else { return }
        defaults.set(release.version, forKey: Key.notifiedStoreVersion)
        NotificationManager.postNow(
            id: Self.updateAvailableNotificationID,
            title: "Grove \(release.version) is here 🌱",
            body: Self.headline(of: release.releaseNotes) ?? "A cozy new update is ready on the App Store. Tap to update.",
            action: .openStore(release.trackViewUrl))
    }

    /// The first line of the App Store's "What's New" text, kept short.
    private static func headline(of notes: String?) -> String? {
        guard let line = notes?.split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: " •-*")) })
            .first(where: { !$0.isEmpty }) else { return nil }
        return line.count > 110 ? String(line.prefix(107)) + "…" : line
    }

    private static func fetchStoreRelease() async -> StoreRelease? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: Bundle.main.bundleIdentifier ?? "com.kaseyrandall.grove"),
            // The listing is per storefront; ask the player's own.
            URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us"),
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        struct Lookup: Decodable { let results: [StoreRelease] }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(Lookup.self, from: data).results.first
        } catch {
            return nil
        }
    }

    // MARK: Background refresh

    /// Must run before launch finishes (from the app delegate).
    nonisolated static func registerBackgroundRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            AppUpdates.scheduleBackgroundRefresh() // keep the chain going
            let work = Task { @MainActor in
                await AppUpdates.shared.backgroundCheck()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Ask for a refresh some hours from now. Called whenever Grove goes to
    /// the background; the system picks the actual time.
    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppUpdates.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppUpdates.storeCheckInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    #if DEBUG
    /// Developer tools: forget what's been announced so both notifications
    /// and the What's New sheet can be seen again.
    func resetForTesting() {
        for key in [Key.lastLaunchedVersion, Key.pendingWhatsNew, Key.announcedInstalled,
                    Key.notifiedStoreVersion, Key.lastStoreCheck, Key.storeRelease] {
            defaults.removeObject(forKey: key)
        }
        storeRelease = nil
    }
    #endif
}
