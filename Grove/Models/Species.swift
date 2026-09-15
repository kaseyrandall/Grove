import Foundation

/// A friend *type* in the field guide. Static catalog data, distinct from
/// `Catch` (a specific photo the player took). Names are the animal's real
/// name; players give their own nickname to their first sighting (stored on
/// the `Catch`).
struct Species: Identifiable, Hashable {
    let id: String          // stable slug, e.g. "fox"
    let name: String        // real name, e.g. "Red Fox"
    let emoji: String       // placeholder art until we commission real friend art 🦊
    let rarity: Rarity
    let zone: Habitat       // which part of the Grove it settles into
    let blurb: String       // a friendly field note
    let habitatNote: String // where you'd find it in the wild
    /// Extra search terms that should surface this friend in the picker (e.g.
    /// "kitten", "feline" for a cat), so a player who types a synonym still
    /// finds it. Purely a search aid — keep these simple.
    let matchKeywords: [String]

    /// The friendly placeholder every catch starts as, until the player picks
    /// which friend it is — so a snap is *always* rewarding, even before it's
    /// named.
    static let mystery = Species(
        id: "mystery-critter",
        name: "Mystery Friend",
        emoji: "❓",
        rarity: .rare,
        zone: .meadow,
        blurb: "Something was definitely there... but too quick to identify! A fun little unknown to welcome home.",
        habitatNote: "Anywhere surprising",
        matchKeywords: []
    )
}
