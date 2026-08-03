import Foundation

/// A critter *type* in the field guide. Static catalog data, distinct from
/// `Catch` (a specific photo the player took). Names are the animal's real
/// name; players give their own nickname to their first sighting (stored on
/// the `Catch`).
struct Species: Identifiable, Hashable {
    let id: String          // stable slug, e.g. "fox"
    let name: String        // real name, e.g. "Red Fox"
    let emoji: String       // placeholder art until we commission real critter art 🦊
    let rarity: Rarity
    let zone: Habitat       // which part of the Grove it settles into
    let blurb: String       // a friendly field note
    let habitatNote: String // where you'd find it in the wild
    /// Vision classification labels that should map to this critter.
    /// Matching is a lowercased "contains" test, so keep these simple.
    let matchKeywords: [String]

    /// The special fallback used when Vision can't confidently name what it saw,
    /// so a catch is *always* rewarding.
    static let mystery = Species(
        id: "mystery-critter",
        name: "Mystery Critter",
        emoji: "❓",
        rarity: .rare,
        zone: .meadow,
        blurb: "Something was definitely there... but too quick to identify! A fun little unknown to welcome home.",
        habitatNote: "Anywhere surprising",
        matchKeywords: []
    )
}
