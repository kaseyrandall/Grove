import Foundation
import UserNotifications

/// Gentle, retention-minded local notifications. The whole set is rescheduled
/// on every launch and after every catch, so active players are never nagged —
/// the "come back" nudges keep sliding into the future — while lapsing players
/// still get a friendly tap. No server, no account.
enum NotificationManager {
    private static let center = UNUserNotificationCenter.current()

    private static let streakID = "grove.streak"
    private static let comebackSoonID = "grove.comeback.soon"
    private static let comebackLaterID = "grove.comeback.later"
    private static var allIDs: [String] { [streakID, comebackSoonID, comebackLaterID] }

    /// Rebuild all pending reminders from the current catch history. A no-op —
    /// and crucially, no permission prompt — until the player has caught at
    /// least one friend, so we only ask after a rewarding moment.
    static func refresh(catches: [Catch], enabled: Bool, calendar: Calendar = .current, now: Date = .now) {
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        guard enabled, !catches.isEmpty else { return }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { schedule(catches: catches, calendar: calendar, now: now) }
                }
            case .authorized, .provisional, .ephemeral:
                schedule(catches: catches, calendar: calendar, now: now)
            default:
                break
            }
        }
    }

    /// Clear everything (e.g. when the player turns reminders off).
    static func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    // MARK: Scheduling

    private static func schedule(catches: [Catch], calendar: Calendar, now: Date) {
        let dates = catches.map(\.caughtAt)
        let caughtToday = dates.contains { calendar.isDateInToday($0) }
        let streak = StreakEngine.currentStreak(from: dates, calendar: calendar, now: now)

        // Streak-saver: only when a live streak is actually at risk today, and
        // only if there's still time left this evening to act on it.
        if streak > 0, !caughtToday,
           let fireDate = time(hour: 20, on: now, calendar: calendar), fireDate > now {
            add(id: streakID, at: fireDate, calendar: calendar,
                title: "Keep your \(streak)-day streak! 🔥",
                body: "Snap a friend before midnight so your Grove streak lives on.")
        }

        // Gentle comeback nudges a couple days out. Rescheduling on every catch
        // pushes these forward, so only genuinely-away players ever see them.
        if let soon = time(hour: 17, daysFromNow: 2, from: now, calendar: calendar) {
            add(id: comebackSoonID, at: soon, calendar: calendar,
                title: "Your Grove misses you 🌳",
                body: "Who will come home today? Snap a friend to find out.")
        }
        if let later = time(hour: 11, daysFromNow: 5, from: now, calendar: calendar) {
            add(id: comebackLaterID, at: later, calendar: calendar,
                title: "New friends are waiting 🦔",
                body: "It's been a few days - go meet someone new out in the wild.")
        }
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
