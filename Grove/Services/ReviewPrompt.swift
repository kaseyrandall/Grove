import Foundation

/// Decides when to show Apple's own "Enjoying Grove?" rating prompt: only after
/// something rewarding (a catch just finished), once the player has been
/// around a while, and at most once per version (Apple also limits it to a
/// few times a year). Nothing is collected: the counts below live on this
/// device, and any rating goes to Apple.
@MainActor
final class ReviewPrompt: ObservableObject {
    static let shared = ReviewPrompt()

    /// True when the prompt should show at the next calm moment.
    @Published private(set) var isDue = false

    /// Opened Grove on at least this many different days…
    static let minActiveDays = 3
    /// …and finished at least this many catches.
    static let minCatches = 3
    /// Never ask again sooner than this.
    static let snoozeInterval: TimeInterval = 120 * 24 * 60 * 60

    private let defaults = UserDefaults.standard
    private enum Key {
        static let activeDays = "reviewPrompt.activeDays"
        static let catches = "reviewPrompt.catchesFinished"
        static let lastAsked = "reviewPrompt.lastAskedAt"
        static let askedVersion = "reviewPrompt.askedVersion"
    }

    /// Called whenever Grove comes to the foreground.
    func appBecameActive(now: Date = .now) {
        let day = now.formatted(.iso8601.year().month().day())
        var days = defaults.stringArray(forKey: Key.activeDays) ?? []
        if !days.contains(day) {
            days.append(day)
            defaults.set(Array(days.suffix(30)), forKey: Key.activeDays)
        }
    }

    /// Called when the catch celebration closes.
    func catchFinished(now: Date = .now) {
        defaults.set(defaults.integer(forKey: Key.catches) + 1, forKey: Key.catches)
        if shouldAsk(now: now) { isDue = true }
    }

    private func shouldAsk(now: Date) -> Bool {
        // Once per version is plenty (and Apple limits it anyway).
        if defaults.string(forKey: Key.askedVersion) == Self.appVersion { return false }
        if let last = defaults.object(forKey: Key.lastAsked) as? Date,
           now.timeIntervalSince(last) < Self.snoozeInterval { return false }
        return (defaults.stringArray(forKey: Key.activeDays) ?? []).count >= Self.minActiveDays
            && defaults.integer(forKey: Key.catches) >= Self.minCatches
    }

    /// The prompt has been requested.
    func markShown(now: Date = .now) {
        isDue = false
        defaults.set(now, forKey: Key.lastAsked)
        defaults.set(Self.appVersion, forKey: Key.askedVersion)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    #if DEBUG
    func forceShow() { isDue = true }
    func resetForTesting() {
        for key in [Key.activeDays, Key.catches, Key.lastAsked, Key.askedVersion] { defaults.removeObject(forKey: key) }
        isDue = false
    }
    #endif
}
