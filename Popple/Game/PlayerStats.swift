import Foundation

/// A read-only snapshot of everything the game derives from a player's catches.
/// Build it once per view update and hand it to the UI and the achievement
/// engine, so the numbers can never drift out of sync.
struct PlayerStats {
    let totalSparks: Int
    let level: Int
    let levelProgress: Double
    let totalSnaps: Int
    let caughtSpeciesIDs: Set<String>
    let currentStreak: Int
    let longestStreak: Int

    /// Number of unique species caught in each rarity tier.
    let rarityCounts: [Rarity: Int]
    /// Distinct Grove zones that have at least one resident.
    let zonesVisited: Int
    /// Approx. count of distinct places (coarse lat/lng buckets) the player caught in.
    let distinctLocations: Int
    /// True if any catch was logged before 8am / after 8pm (local time).
    let hasEarlyCatch: Bool
    let hasLateCatch: Bool
    /// The rarest species the player has caught, if any.
    let rarestCaught: Species?

    var uniqueSpecies: Int { caughtSpeciesIDs.count }

    /// Whole-collection completion, 0...1, across the catalog.
    var collectionProgress: Double {
        let total = CreatureCatalog.all.count
        guard total > 0 else { return 0 }
        let caughtInCatalog = caughtSpeciesIDs.intersection(Set(CreatureCatalog.all.map(\.id))).count
        return Double(caughtInCatalog) / Double(total)
    }

    func count(of rarity: Rarity) -> Int { rarityCounts[rarity] ?? 0 }

    // MARK: Build

    init(catches: [Catch], calendar: Calendar = .current, now: Date = .now) {
        let sparks = catches.reduce(0) { $0 + $1.sparksEarned }
        totalSparks = sparks
        level = Progression.level(forTotalSparks: sparks)
        levelProgress = Progression.levelProgress(forTotalSparks: sparks)
        totalSnaps = catches.count

        let ids = Set(catches.map(\.speciesID))
        caughtSpeciesIDs = ids

        let dates = catches.map(\.caughtAt)
        currentStreak = StreakEngine.currentStreak(from: dates, calendar: calendar, now: now)
        longestStreak = StreakEngine.longestStreak(from: dates, calendar: calendar)

        // Rarity tally over *unique* caught species.
        let caughtSpecies = ids.compactMap { CreatureCatalog.species(for: $0) }
        var tally: [Rarity: Int] = [:]
        for species in caughtSpecies { tally[species.rarity, default: 0] += 1 }
        rarityCounts = tally
        rarestCaught = caughtSpecies.max { $0.rarity < $1.rarity }
        zonesVisited = Set(caughtSpecies.map(\.zone)).count

        // Distinct locations: bucket coords to ~0.01° (~1km) so nearby catches merge.
        let buckets = Set(catches.compactMap { c -> String? in
            guard let lat = c.latitude, let lng = c.longitude else { return nil }
            return "\(Int(lat * 100))|\(Int(lng * 100))"
        })
        distinctLocations = buckets.count

        // Time-of-day flags.
        var early = false
        var late = false
        for date in dates {
            let hour = calendar.component(.hour, from: date)
            if hour < 8 { early = true }
            if hour >= 20 { late = true }
        }
        hasEarlyCatch = early
        hasLateCatch = late
    }
}
