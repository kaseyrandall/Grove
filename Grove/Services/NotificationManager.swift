import Foundation
import UIKit
import UserNotifications

/// Gentle, retention-minded local notifications. The whole set is rescheduled
/// on every launch and after every catch, so active players are never nagged —
/// the "come back" nudges keep sliding into the future — while lapsing players
/// still get a friendly tap. No server, no account.
enum NotificationManager {
    private static let center = UNUserNotificationCenter.current()

    /// One reminder per day at most, for the coming week: `grove.day.0` is
    /// today, `grove.day.1` tomorrow, and so on.
    private static let lookahead = 7
    private static var allIDs: [String] { (0...lookahead).map { "grove.day.\($0)" } }

    /// The Settings switch for memories (friend anniversaries).
    static let memoriesEnabledKey = "memoryNotificationsEnabled"

    /// Rebuild all pending reminders from the current catch history. A no-op —
    /// and crucially, no permission prompt — until the player has caught at
    /// least one friend, so we only ask after a rewarding moment.
    /// `enabled` is the Reminders switch; memories have their own.
    static func refresh(catches: [Catch], enabled: Bool, calendar: Calendar = .current, now: Date = .now) {
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        let memories = UserDefaults.standard.object(forKey: memoriesEnabledKey) as? Bool ?? true
        guard enabled || memories, !catches.isEmpty else { return }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        schedule(catches: catches, reminders: enabled, memories: memories,
                                 calendar: calendar, now: now)
                    }
                }
            case .authorized, .provisional, .ephemeral:
                schedule(catches: catches, reminders: enabled, memories: memories,
                         calendar: calendar, now: now)
            default:
                break
            }
        }
    }

    /// A one-off "your fighter's match is done" ping, fired when an away match
    /// resolves. Best-effort: silently no-ops without notification permission.
    /// Follows the Reminders switch and quiet hours (a match that ends at
    /// night waits for the morning); tapping it opens Battlegrounds.
    static func scheduleMatchResult(id: String, friendName: String, at date: Date,
                                    calendar: Calendar = .current) {
        guard UserDefaults.standard.object(forKey: remindersEnabledKey) as? Bool ?? true else { return }
        let when = nextDaytime(after: date, calendar: calendar) ?? date
        let interval = when.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                let content = UNMutableNotificationContent()
                content.title = "\(friendName)'s match is done 🏆"
                content.body = "Come see how it went in Battlegrounds."
                content.sound = .default
                content.userInfo = TapAction.open(.arena).userInfo
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            default:
                break
            }
        }
    }

    /// What tapping a notification does (see `NotificationTapHandler`).
    enum TapAction {
        case openStore(URL)
        case whatsNew
        /// Go to the part of the app a new feature lives in.
        case open(ReleaseNotes.Destination)

        static let userInfoKey = "grove.tap"
        static let urlKey = "grove.url"
        static let destinationKey = "grove.destination"

        var userInfo: [String: String] {
            switch self {
            case .openStore(let url): return [Self.userInfoKey: "openStore", Self.urlKey: url.absoluteString]
            case .whatsNew:           return [Self.userInfoKey: "whatsNew"]
            case .open(let place):    return [Self.userInfoKey: "open", Self.destinationKey: place.rawValue]
            }
        }

        init?(userInfo: [AnyHashable: Any]) {
            switch userInfo[Self.userInfoKey] as? String {
            case "openStore":
                guard let string = userInfo[Self.urlKey] as? String, let url = URL(string: string) else { return nil }
                self = .openStore(url)
            case "whatsNew":
                self = .whatsNew
            case "open":
                guard let raw = userInfo[Self.destinationKey] as? String,
                      let place = ReleaseNotes.Destination(rawValue: raw) else { return nil }
                self = .open(place)
            default:
                return nil
            }
        }
    }

    /// Show a notification now (used for app-update news), or at 10am if
    /// it's the middle of the night. Never asks for permission itself — that
    /// only happens after a first catch — so it silently no-ops until the
    /// player has said yes.
    static func postNow(id: String, title: String, body: String, action: TapAction? = nil,
                        calendar: Calendar = .current, now: Date = .now) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                if let action { content.userInfo = action.userInfo }
                let trigger: UNNotificationTrigger
                if let morning = nextDaytime(after: now, calendar: calendar) {
                    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: morning)
                    trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                } else {
                    trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                }
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            default:
                break
            }
        }
    }

    #if DEBUG
    /// Developer tool: one of each notification, five seconds apart, so they
    /// can be seen on a device. Shown as banners even with Grove open.
    static func previewAll(catches: [Catch]) {
        let friend = catches.max { $0.species.rarity < $1.species.rarity }
        let challenge = DailyChallenge.today()
        let samples: [(String, String)] = [
            ("Keep your 5-day streak! 🔥", "Snap a friend before midnight so your Grove streak lives on."),
            ("Today's challenge \(challenge.emoji)", "\(challenge.title). Who will you meet?"),
            ("One more for Backyard Boss 🏡", "Catch 12 different Common friends. You're nearly there."),
            ("A Grove memory 💛", "A year ago today you met \(friend?.displayName ?? "Ember") \(friend?.species.emoji ?? "🦊")."),
            ("🐾 Lots of new friends to meet", "Opossums, chipmunks, toads, herons, moose and many more have joined the Field Guide."),
            ("Grove 1.4 is here 🌱", "A cozy new update is ready on the App Store. Tap to update."),
        ]
        for (i, sample) in samples.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = sample.0
            content.body = sample.1
            content.sound = .default
            content.userInfo = [previewKey: true]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(3 + i * 5), repeats: false)
            center.add(UNNotificationRequest(identifier: "grove.preview.\(i)", content: content, trigger: trigger))
        }
    }
    #endif
    static let previewKey = "grove.preview"

    static func cancelMatchResult(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// The Reminders switch in Settings.
    static let remindersEnabledKey = "notificationsEnabled"

    /// Re-plan every Arena "match is done" ping (when Reminders is switched):
    /// clear them all, then schedule the ones still to come if it's on.
    static func refreshMatchResults(_ matches: [(id: String, friendName: String, date: Date)]) {
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix("grove.bg.") }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for m in matches { scheduleMatchResult(id: m.id, friendName: m.friendName, at: m.date) }
        }
    }

    /// Clear everything (e.g. when the player turns reminders off).
    static func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    // MARK: Scheduling

    /// Quiet hours: nothing between 9pm and 8am.
    private static let quietFrom = 21, quietUntil = 8

    /// 10am when `date` falls in quiet hours (today's if it's early morning,
    /// tomorrow's if it's late evening); nil when it's fine to post now.
    private static func nextDaytime(after date: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: date)
        if hour < quietUntil { return time(hour: 10, on: date, calendar: calendar) }
        if hour >= quietFrom { return time(hour: 10, daysFromNow: 1, from: date, calendar: calendar) }
        return nil
    }

    /// One possible reminder. Lower `rank` wins when two land on the same day.
    private struct Candidate {
        let date: Date
        let rank: Int
        let title: String
        let body: String
    }

    /// Gather every reminder worth sending in the coming week, then keep the
    /// best one per day so Grove never sends more than one a day.
    private static func schedule(catches: [Catch], reminders: Bool, memories: Bool,
                                 calendar: Calendar, now: Date) {
        var candidates: [Candidate] = []
        if reminders {
            candidates += streakSaver(catches, calendar: calendar, now: now)
            candidates += almostThere(catches, calendar: calendar, now: now)
            candidates += challenges(catches, calendar: calendar, now: now)
            candidates += comebacks(calendar: calendar, now: now)
        }
        if memories {
            candidates += anniversaries(catches, calendar: calendar, now: now)
        }

        let today = calendar.startOfDay(for: now)
        var best: [Int: Candidate] = [:]
        for candidate in candidates where candidate.date > now {
            guard let offset = calendar.dateComponents([.day], from: today,
                                                       to: calendar.startOfDay(for: candidate.date)).day,
                  (0...lookahead).contains(offset) else { continue }
            if let kept = best[offset], kept.rank <= candidate.rank { continue }
            best[offset] = candidate
        }
        for (offset, candidate) in best.sorted(by: { $0.key < $1.key }) {
            add(id: "grove.day.\(offset)", at: candidate.date, calendar: calendar,
                title: candidate.title, body: candidate.body)
            #if DEBUG
            print("🔔 Grove reminder, day \(offset), \(candidate.date.formatted(date: .abbreviated, time: .shortened)): \(candidate.title) | \(candidate.body)")
            #endif
        }
    }

    /// Streak-saver: only when a live streak is actually at risk today, and
    /// only if there's still time left this evening to act on it.
    private static func streakSaver(_ catches: [Catch], calendar: Calendar, now: Date) -> [Candidate] {
        let dates = catches.map(\.caughtAt)
        let streak = StreakEngine.currentStreak(from: dates, calendar: calendar, now: now)
        guard streak > 0, !dates.contains(where: { calendar.isDateInToday($0) }),
              let date = time(hour: 20, on: now, calendar: calendar) else { return [] }
        return [Candidate(date: date, rank: 0,
                          title: "Keep your \(streak)-day streak! 🔥",
                          body: "Snap a friend before midnight so your Grove streak lives on.")]
    }

    /// Badges measured by your longest streak or your level, which one more
    /// catch can't finish ("one away" from a 7-day streak may mean 7 days).
    private static let notOneCatchAway: Set<String> = ["streak_3", "streak_7", "streak_30", "seasoned"]

    /// An achievement that one more catch would unlock, at 6pm.
    private static func almostThere(_ catches: [Catch], calendar: Calendar, now: Date) -> [Candidate] {
        let stats = PlayerStats(catches: catches)
        guard let next = AchievementCatalog.all.first(where: { achievement in
            !notOneCatchAway.contains(achievement.id)
                && achievement.goal >= 2 && !achievement.isUnlocked(stats)
                && Int(achievement.measure(stats)) == Int(achievement.goal) - 1
        }) else { return [] }
        let tonight = time(hour: 18, on: now, calendar: calendar)
        guard let date = (tonight.map { $0 > now } ?? false) ? tonight
                : time(hour: 18, daysFromNow: 1, from: now, calendar: calendar) else { return [] }
        return [Candidate(date: date, rank: 1,
                          title: "One more for \(next.title) \(next.emoji)",
                          body: "\(next.detail) You're nearly there.")]
    }

    /// Today's challenge at 9am, for the next couple of days. Rescheduled on
    /// every open, so it only reaches players who've been around lately.
    private static func challenges(_ catches: [Catch], calendar: Calendar, now: Date) -> [Candidate] {
        let todays = catches.filter { calendar.isDateInToday($0.caughtAt) }
        let stats = PlayerStats(catches: catches)
        return (0...2).compactMap { offset -> Candidate? in
            guard let date = time(hour: 9, daysFromNow: offset, from: now, calendar: calendar) else { return nil }
            let challenge = DailyChallenge.today(now: date, calendar: calendar)
            if offset == 0, challenge.isComplete(todays, stats) { return nil }
            return Candidate(date: date, rank: 3,
                             title: "Today's challenge \(challenge.emoji)",
                             body: "\(challenge.title). Who will you meet?")
        }
    }

    /// Gentle comeback nudges. Rescheduling on every open pushes these
    /// forward, so only genuinely-away players ever see them.
    private static func comebacks(calendar: Calendar, now: Date) -> [Candidate] {
        var result: [Candidate] = []
        if let soon = time(hour: 17, daysFromNow: 3, from: now, calendar: calendar) {
            result.append(Candidate(date: soon, rank: 4,
                                    title: "Your Grove misses you 🌳",
                                    body: "Who will come home today? Snap a friend to find out."))
        }
        if let later = time(hour: 11, daysFromNow: 6, from: now, calendar: calendar) {
            result.append(Candidate(date: later, rank: 4,
                                    title: "New friends are waiting 🦔",
                                    body: "It's been a few days. Go meet someone new out in the wild."))
        }
        return result
    }

    /// "A year ago today you met Ember 🦊", plus a one-month note for your
    /// very first friend. The rarest friend wins a shared anniversary.
    private static func anniversaries(_ catches: [Catch], calendar: Calendar, now: Date) -> [Candidate] {
        guard let horizon = calendar.date(byAdding: .day, value: lookahead + 1, to: now) else { return [] }
        var result: [Candidate] = []
        let byRarity = catches.sorted { $0.species.rarity > $1.species.rarity }
        for friend in byRarity {
            let met = calendar.startOfDay(for: friend.caughtAt)
            for years in 1...10 {
                guard let day = calendar.date(byAdding: .year, value: years, to: met) else { break }
                if day > horizon { break }
                guard let date = time(hour: 10, on: day, calendar: calendar) else { continue }
                result.append(Candidate(
                    date: date, rank: 2, title: "A Grove memory 💛",
                    body: "\(years == 1 ? "A year" : "\(years) years") ago today you met \(friend.displayName) \(friend.species.emoji)."))
            }
        }
        if let first = catches.min(by: { $0.caughtAt < $1.caughtAt }),
           let day = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: first.caughtAt)),
           let date = time(hour: 10, on: day, calendar: calendar) {
            result.append(Candidate(
                date: date, rank: 2, title: "One month of Grove 💛",
                body: "A month ago you met your very first friend, \(first.displayName) \(first.species.emoji)."))
        }
        return result
    }

    private static func time(hour: Int, on date: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)
    }

    private static func time(hour: Int, daysFromNow days: Int, from now: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: days, to: now) else { return nil }
        return time(hour: hour, on: day, calendar: calendar)
    }

    private static func add(id: String, at date: Date, calendar: Calendar, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

/// Where a notification tap asked to go, picked up by `RootView` (which
/// switches tab) and the tab's page (which opens the screen).
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var pending: ReleaseNotes.Destination?
}

/// Routes notification taps. Grove's reminders still stay out of the way while
/// the app is open (as they did before this delegate existed); update news
/// shows as a banner either way.
final class NotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationTapHandler()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        let showWhileOpen = NotificationManager.TapAction(userInfo: info) != nil
            || info[NotificationManager.previewKey] != nil
        completionHandler(showWhileOpen ? [.banner, .list, .sound] : [])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = NotificationManager.TapAction(userInfo: response.notification.request.content.userInfo)
        Task { @MainActor in
            switch action {
            case .openStore(let url): UIApplication.shared.open(url)
            case .whatsNew:           AppUpdates.shared.showWhatsNew()
            case .open(let place):    AppRouter.shared.pending = place
            case nil:                 break
            }
            completionHandler()
        }
    }
}
