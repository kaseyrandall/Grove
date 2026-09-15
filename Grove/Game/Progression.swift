import Foundation

/// Pure, testable game math. No UI, no storage — just the rules.
enum Progression {

    /// First sighting of a species is worth double: the collection thrill.
    static func sparks(for species: Species, isFirstSighting: Bool) -> Int {
        let base = species.rarity.sparks
        return isFirstSighting ? base * 2 : base
    }

    /// A snap is always rewarding: an unidentified Mystery Friend earns this
    /// small flat token right away, with no first-find bonus. The real
    /// rarity-based value (and the 2× discovery bonus) lands when the player
    /// names the friend. Kept at the lowest species value so identifying a
    /// friend can only ever keep or raise the reward — never lower it.
    static let snapSparks = Rarity.common.sparks

    // MARK: Levels
    //
    // A gentle curve: each level costs a bit more than the last. Level is
    // derived purely from total sparks, so it can never get out of sync.

    /// Total sparks required to *reach* the given level (level 1 == 0 sparks).
    static func sparksRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        // 100, 250, 450, 700, ... (quadratic-ish, feels good early)
        let n = level - 1
        return 50 * n * (n + 1)
    }

    static func level(forTotalSparks total: Int) -> Int {
        var level = 1
        while total >= sparksRequired(forLevel: level + 1) {
            level += 1
        }
        return level
    }

    /// Progress (0...1) toward the next level, for the profile progress bar.
    static func levelProgress(forTotalSparks total: Int) -> Double {
        let current = level(forTotalSparks: total)
        let floor = sparksRequired(forLevel: current)
        let ceiling = sparksRequired(forLevel: current + 1)
        guard ceiling > floor else { return 0 }
        return Double(total - floor) / Double(ceiling - floor)
    }
}
