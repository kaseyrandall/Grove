import Foundation

/// A single badge the player can earn. Each one measures some quantity from
/// `PlayerStats` against a `goal`; unlocked when the measure reaches the goal.
/// Binary achievements simply use a goal of 1.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let detail: String
    let goal: Double
    /// Current value toward the goal, given a stats snapshot.
    let measure: (PlayerStats) -> Double

    func isUnlocked(_ stats: PlayerStats) -> Bool {
        measure(stats) >= goal
    }

    /// 0...1 progress toward unlocking.
    func progress(_ stats: PlayerStats) -> Double {
        guard goal > 0 else { return 0 }
        return min(measure(stats) / goal, 1)
    }

    /// A friendly "3/10" style label (or "Unlocked!" when done).
    func progressLabel(_ stats: PlayerStats) -> String {
        if isUnlocked(stats) { return "Unlocked!" }
        if goal <= 1 { return "Locked" }
        return "\(Int(measure(stats)))/\(Int(goal))"
    }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "first_catch", title: "First Friend", emoji: "🐾",
                    detail: "Catch your very first critter.",
                    goal: 1) { Double($0.totalSnaps) },

        Achievement(id: "five_species", title: "Getting Started", emoji: "🌱",
                    detail: "Collect 5 different critters.",
                    goal: 5) { Double($0.uniqueSpecies) },

        Achievement(id: "collector", title: "Collector", emoji: "📚",
                    detail: "Collect 15 different critters.",
                    goal: 15) { Double($0.uniqueSpecies) },

        Achievement(id: "completionist", title: "Gotta Snap 'Em All", emoji: "🏆",
                    detail: "Complete the entire Dex.",
                    goal: Double(CreatureCatalog.all.count)) { Double($0.uniqueSpecies) },

        Achievement(id: "all_commons", title: "Backyard Boss", emoji: "🏡",
                    detail: "Catch every Common critter.",
                    goal: Double(CreatureCatalog.all.filter { $0.rarity == .common }.count)) {
                        Double($0.count(of: .common))
                    },

        Achievement(id: "rare_find", title: "Lucky Day", emoji: "💎",
                    detail: "Catch a Rare critter.",
                    goal: 1) { Double($0.count(of: .rare)) },

        Achievement(id: "epic_find", title: "Epic Find", emoji: "🌟",
                    detail: "Catch an Epic critter.",
                    goal: 1) { Double($0.count(of: .epic)) },

        Achievement(id: "legend", title: "Living Legend", emoji: "👑",
                    detail: "Catch a Legendary critter.",
                    goal: 1) { Double($0.count(of: .legendary)) },

        Achievement(id: "streak_3", title: "Warming Up", emoji: "🔥",
                    detail: "Catch something 3 days in a row.",
                    goal: 3) { Double($0.longestStreak) },

        Achievement(id: "streak_7", title: "On Fire", emoji: "🔥",
                    detail: "Keep a 7-day catching streak.",
                    goal: 7) { Double($0.longestStreak) },

        Achievement(id: "streak_30", title: "Unstoppable", emoji: "⚡️",
                    detail: "Keep a 30-day catching streak.",
                    goal: 30) { Double($0.longestStreak) },

        Achievement(id: "shutterbug", title: "Shutterbug", emoji: "📸",
                    detail: "Snap 50 critters.",
                    goal: 50) { Double($0.totalSnaps) },

        Achievement(id: "early_bird", title: "Early Bird", emoji: "🌅",
                    detail: "Catch a critter before 8am.",
                    goal: 1) { $0.hasEarlyCatch ? 1 : 0 },

        Achievement(id: "night_owl", title: "Night Owl", emoji: "🌙",
                    detail: "Catch a critter after 8pm.",
                    goal: 1) { $0.hasLateCatch ? 1 : 0 },

        Achievement(id: "explorer", title: "Explorer", emoji: "🗺️",
                    detail: "Catch critters in 5 different places.",
                    goal: 5) { Double($0.distinctLocations) },

        Achievement(id: "seasoned", title: "Seasoned", emoji: "⭐️",
                    detail: "Reach Level 10.",
                    goal: 10) { Double($0.level) },
    ]

    /// Achievements newly satisfied going from `before` to `after` — used to
    /// celebrate the moment they unlock, right after a catch.
    static func newlyUnlocked(before: PlayerStats, after: PlayerStats) -> [Achievement] {
        all.filter { !$0.isUnlocked(before) && $0.isUnlocked(after) }
    }

    static func unlockedCount(_ stats: PlayerStats) -> Int {
        all.filter { $0.isUnlocked(stats) }.count
    }
}
