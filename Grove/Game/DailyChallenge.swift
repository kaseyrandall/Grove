import Foundation

/// A bite-sized goal for the day — the "give me a reason to open the app"
/// retention hook. Chosen deterministically from the calendar day so it's the
/// same all day and the same for everyone, then rotates each morning. Evaluated
/// purely against catches + `PlayerStats`, so there's no new state to persist.
struct DailyChallenge: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let goal: Int
    /// Progress toward the goal from *today's* catches (and overall stats).
    let measure: (_ todaysCatches: [Catch], _ stats: PlayerStats) -> Int

    func current(_ todays: [Catch], _ stats: PlayerStats) -> Int {
        min(measure(todays, stats), goal)
    }
    func isComplete(_ todays: [Catch], _ stats: PlayerStats) -> Bool {
        measure(todays, stats) >= goal
    }
    func progress(_ todays: [Catch], _ stats: PlayerStats) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(measure(todays, stats)) / Double(goal), 1)
    }

    /// Today's challenge, stable for the whole calendar day.
    static func today(now: Date = .now, calendar: Calendar = .current) -> DailyChallenge {
        let day = Int((calendar.startOfDay(for: now).timeIntervalSince1970 / 86_400).rounded())
        let seed = abs(day)
        return builders[seed % builders.count](seed)
    }

    private typealias Builder = (_ seed: Int) -> DailyChallenge

    private static let builders: [Builder] = [
        // Keep the streak alive — catch anything at all.
        { _ in
            DailyChallenge(id: "any", title: "Meet a friend today", emoji: "🐾", goal: 1) { todays, _ in
                todays.count
            }
        },
        // Discover a kind you've never met before.
        { _ in
            DailyChallenge(id: "new_kind", title: "Discover a kind you haven't met", emoji: "✨", goal: 1) { todays, _ in
                todays.filter(\.isFirstSighting).count
            }
        },
        // Fill a specific zone (which one rotates with the day).
        { seed in
            let zone = Habitat.ordered[seed % Habitat.ordered.count]
            return DailyChallenge(id: "zone_\(zone.rawValue)",
                                  title: "Find a friend for your \(zone.shortName)",
                                  emoji: zone.emoji, goal: 1) { todays, _ in
                todays.filter { $0.effectiveZone == zone }.count
            }
        },
        // A double — snap two in one day.
        { _ in
            DailyChallenge(id: "two", title: "Snap two friends today", emoji: "✌️", goal: 2) { todays, _ in
                todays.count
            }
        },
        // Something a little special.
        { _ in
            DailyChallenge(id: "uncommon_plus", title: "Spot something uncommon or rarer", emoji: "💎", goal: 1) { todays, _ in
                todays.filter { $0.species.rarity >= .uncommon }.count
            }
        },
    ]
}
