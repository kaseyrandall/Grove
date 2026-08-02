import SwiftUI

/// How special a critter is. Drives the point payout and the celebration.
enum Rarity: Int, CaseIterable, Codable, Comparable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Base sparks awarded for spotting a critter of this rarity.
    var sparks: Int {
        switch self {
        case .common:    return 10
        case .uncommon:  return 25
        case .rare:      return 60
        case .epic:      return 120
        case .legendary: return 300
        }
    }

    var title: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }

    /// A cute little badge emoji for the rarity.
    var badge: String {
        switch self {
        case .common:    return "🌿"
        case .uncommon:  return "🍀"
        case .rare:      return "💎"
        case .epic:      return "🌟"
        case .legendary: return "👑"
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
