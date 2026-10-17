import Foundation

/// Moments in the app a survey can follow. Flows report them with
/// `SurveyCenter.shared.record(_:)`; add a case (and a call) to ask about a
/// new flow.
enum SurveyMoment: String, Codable, CaseIterable {
    /// The catch celebration closed and the player is back in their Grove.
    case catchFinished
    /// The player picked which animal a friend is (on the celebration or in Edit).
    case friendNamed
}

/// One five-point Likert question.
struct Survey: Identifiable, Equatable {
    enum Trigger: Equatable {
        /// After the player has been around a while: opened Grove on at least
        /// `days` different days and `sessions` times. Asked at the next
        /// moment a flow reports, so it follows something rewarding rather
        /// than interrupting a launch.
        case usage(days: Int, sessions: Int)
        /// Once a flow has happened `count` times, right after it.
        case after(SurveyMoment, count: Int)
    }

    let id: String
    let question: String
    /// The five answers, lowest first. The ends label the scale; the chosen
    /// one is spelled out once picked.
    let labels: [String]
    let trigger: Trigger

    /// One face per point on the scale, lowest first.
    static let faces = ["😣", "🙁", "😐", "🙂", "😍"]

    static let easeLabels = ["Very hard", "Hard", "Okay", "Easy", "Very easy"]
    static let enjoymentLabels = ["Not at all", "A little", "Somewhat", "A lot", "Loving it"]
}

enum SurveyCatalog {
    static let all: [Survey] = [
        Survey(id: "enjoyment-v1",
               question: "How much are you enjoying Grove so far?",
               labels: Survey.enjoymentLabels,
               trigger: .usage(days: 3, sessions: 5)),
        Survey(id: "catch-ease-v1",
               question: "How easy was it to bring that friend home?",
               labels: Survey.easeLabels,
               trigger: .after(.catchFinished, count: 3)),
        Survey(id: "naming-ease-v1",
               question: "How easy was it to find the right animal?",
               labels: Survey.easeLabels,
               trigger: .after(.friendNamed, count: 2)),
    ]
}

/// A player's answer. Kept on this device only (Grove has no backend and
/// collects nothing); `SurveyCenter.deliver(_:)` is where an upload would go.
struct SurveyResponse: Codable, Identifiable {
    let surveyID: String
    /// 1 (lowest) through 5.
    let score: Int
    let moment: SurveyMoment?
    let appVersion: String
    let answeredAt: Date
    var id: String { "\(surveyID)@\(answeredAt.timeIntervalSince1970)" }
}

/// Decides when to ask a survey, and remembers what's been asked and answered.
///
/// The rules keep it gentle: never before onboarding is done, at most one
/// survey every few days and one per visit, an answered survey is never
/// asked again, and "Not now" waits a couple of weeks before one more try.
@MainActor
final class SurveyCenter: ObservableObject {
    static let shared = SurveyCenter()

    /// The survey waiting for a calm moment to show (the root view presents it).
    @Published private(set) var pending: Survey?
    /// The moment that set off `pending`, saved with the answer.
    private var pendingMoment: SurveyMoment?

    static let cooldown: TimeInterval = 4 * 24 * 60 * 60
    static let snoozeInterval: TimeInterval = 14 * 24 * 60 * 60
    static let maxAsks = 2
    /// A return after this long counts as a new session.
    static let sessionGap: TimeInterval = 30 * 60

    private let defaults = UserDefaults.standard
    private enum Key {
        static let sessions = "surveys.sessionCount"
        static let activeDays = "surveys.activeDays"
        static let lastActive = "surveys.lastActive"
        static let momentCounts = "surveys.momentCounts"
        static let lastAsked = "surveys.lastAskedAt"
        static let asks = "surveys.asks"           // [surveyID: times asked]
        static let snoozedAt = "surveys.snoozedAt" // [surveyID: Date]
        static let answered = "surveys.answered"   // [surveyID]
        static let responses = "surveys.responses"
    }
    private var askedThisSession = false

    private init() {}

    // MARK: Usage

    /// Called whenever Grove comes to the foreground.
    func appBecameActive(now: Date = .now) {
        let last = defaults.object(forKey: Key.lastActive) as? Date
        defaults.set(now, forKey: Key.lastActive)
        guard last.map({ now.timeIntervalSince($0) > Self.sessionGap }) ?? true else { return }

        askedThisSession = false
        defaults.set(defaults.integer(forKey: Key.sessions) + 1, forKey: Key.sessions)
        let day = Self.dayStamp(now)
        var days = defaults.stringArray(forKey: Key.activeDays) ?? []
        if !days.contains(day) {
            days.append(day)
            defaults.set(Array(days.suffix(60)), forKey: Key.activeDays)
        }
    }

    var sessionCount: Int { defaults.integer(forKey: Key.sessions) }
    var activeDayCount: Int { (defaults.stringArray(forKey: Key.activeDays) ?? []).count }

    // MARK: Moments

    /// A flow reached a moment. Counts it and queues the first survey it makes
    /// due, if the player isn't due a break from questions.
    func record(_ moment: SurveyMoment, now: Date = .now) {
        var counts = defaults.dictionary(forKey: Key.momentCounts) as? [String: Int] ?? [:]
        counts[moment.rawValue, default: 0] += 1
        defaults.set(counts, forKey: Key.momentCounts)

        guard pending == nil, canAsk(now: now) else { return }
        if let survey = SurveyCatalog.all.first(where: { isDue($0, at: moment, counts: counts, now: now) }) {
            pending = survey
            pendingMoment = moment
        }
    }

    private func canAsk(now: Date) -> Bool {
        guard defaults.bool(forKey: "hasCompletedOnboarding"), !askedThisSession else { return false }
        if let last = defaults.object(forKey: Key.lastAsked) as? Date,
           now.timeIntervalSince(last) < Self.cooldown { return false }
        return true
    }

    private func isDue(_ survey: Survey, at moment: SurveyMoment, counts: [String: Int], now: Date) -> Bool {
        let answered = defaults.stringArray(forKey: Key.answered) ?? []
        let asks = (defaults.dictionary(forKey: Key.asks) as? [String: Int])?[survey.id] ?? 0
        guard !answered.contains(survey.id), asks < Self.maxAsks else { return false }
        if let snoozed = (defaults.dictionary(forKey: Key.snoozedAt) as? [String: Date])?[survey.id],
           now.timeIntervalSince(snoozed) < Self.snoozeInterval { return false }

        switch survey.trigger {
        case let .usage(days, sessions):
            return activeDayCount >= days && sessionCount >= sessions
        case let .after(trigger, count):
            return trigger == moment && counts[moment.rawValue, default: 0] >= count
        }
    }

    // MARK: Answers

    /// The sheet is on screen: start the cooldown and count the ask.
    func markShown(_ survey: Survey, now: Date = .now) {
        askedThisSession = true
        defaults.set(now, forKey: Key.lastAsked)
        var asks = defaults.dictionary(forKey: Key.asks) as? [String: Int] ?? [:]
        asks[survey.id, default: 0] += 1
        defaults.set(asks, forKey: Key.asks)
    }

    func answer(_ survey: Survey, score: Int, now: Date = .now) {
        var answered = defaults.stringArray(forKey: Key.answered) ?? []
        answered.append(survey.id)
        defaults.set(answered, forKey: Key.answered)

        deliver(SurveyResponse(surveyID: survey.id, score: score, moment: pendingMoment,
                               appVersion: AppUpdates.currentVersion, answeredAt: now))
        clearPending()
    }

    /// "Not now" (or swiping the sheet away).
    func snooze(_ survey: Survey, now: Date = .now) {
        var snoozed = defaults.dictionary(forKey: Key.snoozedAt) as? [String: Date] ?? [:]
        snoozed[survey.id] = now
        defaults.set(snoozed, forKey: Key.snoozedAt)
        clearPending()
    }

    private func clearPending() {
        pending = nil
        pendingMoment = nil
    }

    /// Where answers go. Today: saved on this device. To collect them, send
    /// `response` to an analytics or feedback service here (and update
    /// PrivacyInfo.xcprivacy and the App Privacy answers to match).
    private func deliver(_ response: SurveyResponse) {
        var all = responses
        all.append(response)
        defaults.set(try? JSONEncoder().encode(all), forKey: Key.responses)
    }

    var responses: [SurveyResponse] {
        guard let data = defaults.data(forKey: Key.responses) else { return [] }
        return (try? JSONDecoder().decode([SurveyResponse].self, from: data)) ?? []
    }

    private static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    #if DEBUG
    /// Developer tools: show a survey right now, rules aside.
    func forceShow(_ survey: Survey) {
        pending = survey
        pendingMoment = nil
    }

    /// Developer tools: forget every ask, answer and count.
    func resetForTesting() {
        for key in [Key.sessions, Key.activeDays, Key.lastActive, Key.momentCounts, Key.lastAsked,
                    Key.asks, Key.snoozedAt, Key.answered, Key.responses] {
            defaults.removeObject(forKey: key)
        }
        askedThisSession = false
        clearPending()
    }
    #endif
}
