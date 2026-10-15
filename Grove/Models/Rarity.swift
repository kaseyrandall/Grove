import SwiftUI

/// How special a friend is. Drives the point payout and the celebration.
/// Shown by its plain tier name (Common … Legendary) everywhere.
enum Rarity: Int, CaseIterable, Codable, Comparable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Base sparks awarded for spotting a friend of this rarity.
    var sparks: Int {
        switch self {
        case .common:    return 10
        case .uncommon:  return 25
        case .rare:      return 60
        case .epic:      return 120
        case .legendary: return 300
        }
    }

    /// The tier's name, used on badges, the friend page and breakdowns.
    var title: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }

    /// A soft colored heart matching the tier's tint — no crowns or gems.
    var badge: String {
        switch self {
        case .common:    return "💚"
        case .uncommon:  return "💙"
        case .rare:      return "💜"
        case .epic:      return "💗"
        case .legendary: return "💛"
        }
    }

    var tint: Color {
        switch self {
        case .common:    return Theme.mint
        case .uncommon:  return Theme.sky
        case .rare:      return Theme.lavender
        case .epic:      return Theme.blush
        case .legendary: return Theme.gold
        }
    }
}
