import Foundation

/// A collectible critter *type* in the Popple-dex. This is static catalog data
/// (compiled in), distinct from `Catch`, which is a specific photo the player took.
struct Species: Identifiable, Hashable {
    let id: String          // stable slug, e.g. "cardinal"
    let name: String        // "Cardinal"
    let emoji: String       // placeholder art until we commission real critter art 🐦
    let rarity: Rarity
    let blurb: String       // a friendly one-liner shown in the Dex
    let habitat: String     // where you might find it
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
        blurb: "Something was definitely there... but too quick to identify! A fun little unknown for your collection.",
        habitat: "Anywhere surprising",
        matchKeywords: []
    )
}
