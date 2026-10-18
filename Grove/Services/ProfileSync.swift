import Foundation

/// Keeps the player's profile look and name (and whether they've been through
/// onboarding) in iCloud's small key-value store, so a reinstall or a new
/// phone comes back looking like theirs. The app keeps reading these from
/// `UserDefaults` (via `@AppStorage`); this mirrors them both ways.
///
/// Without the iCloud key-value capability this quietly does nothing beyond
/// the device, so it's safe to run everywhere.
final class ProfileSync {
    static let shared = ProfileSync()

    /// Settings that follow the player. Onboarding only ever syncs as "done",
    /// so replaying it on one device doesn't send another back to the start.
    private let mirroredKeys = ["profileEmoji", "profileColorHex", "profileName"]
    private let onboardingKey = "hasCompletedOnboarding"

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(cloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud)
        NotificationCenter.default.addObserver(
            self, selector: #selector(localChanged),
            name: UserDefaults.didChangeNotification, object: local)

        cloud.synchronize()
        pullFromCloud()
        pushToCloud()
    }

    @objc private func cloudChanged(_ note: Notification) {
        DispatchQueue.main.async { self.pullFromCloud() }
    }

    @objc private func localChanged() {
        pushToCloud()
    }

    /// iCloud wins for the look (it's the player's most recent choice
    /// anywhere); onboarding only moves forward.
    private func pullFromCloud() {
        for key in mirroredKeys {
            if let value = cloud.object(forKey: key),
               !(local.object(forKey: key).map { isEqual($0, value) } ?? false) {
                local.set(value, forKey: key)
            }
        }
        if cloud.bool(forKey: onboardingKey), !local.bool(forKey: onboardingKey) {
            local.set(true, forKey: onboardingKey)
        }
    }

    private func pushToCloud() {
        for key in mirroredKeys {
            guard let value = local.object(forKey: key) else { continue }
            if !(cloud.object(forKey: key).map { isEqual($0, value) } ?? false) {
                cloud.set(value, forKey: key)
            }
        }
        if local.bool(forKey: onboardingKey), !cloud.bool(forKey: onboardingKey) {
            cloud.set(true, forKey: onboardingKey)
        }
    }

    private func isEqual(_ a: Any, _ b: Any) -> Bool {
        (a as? NSObject)?.isEqual(b) ?? false
    }
}
