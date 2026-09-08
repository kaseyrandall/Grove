import SwiftUI

/// A zone of the player's Grove. Every collectible `Species` belongs to one,
/// and the Grove screen lays its residents out zone by zone. These double as
/// the field-guide's natural groups — one structure, two payoffs.
enum Habitat: String, CaseIterable, Codable, Identifiable {
    case home
    case garden
    case pond
    case coast
    case meadow
    case woods
    case sky
    case wilds

    var id: String { rawValue }

    /// Display order in the Grove (roughly homebody → wild).
    var order: Int {
        switch self {
        case .home:   return 0
        case .garden: return 1
        case .pond:   return 2
        case .coast:  return 3
        case .meadow: return 4
        case .woods:  return 5
        case .sky:    return 6
        case .wilds:  return 7
        }
    }

    /// Full zone name, e.g. "The Garden".
    var displayName: String {
        switch self {
        case .home:   return "Home"
        case .garden: return "The Garden"
        case .pond:   return "The Pond"
        case .coast:  return "The Coast"
        case .meadow: return "The Meadow"
        case .woods:  return "The Woods"
        case .sky:    return "The Treetops"
        case .wilds:  return "The Wilds"
        }
    }

    /// Short name for sentences, e.g. "Lives in your Garden".
    var shortName: String {
        switch self {
        case .home:   return "Home"
        case .garden: return "Garden"
        case .pond:   return "Pond"
        case .coast:  return "Coast"
        case .meadow: return "Meadow"
        case .woods:  return "Woods"
        case .sky:    return "Treetops"
        case .wilds:  return "Wilds"
        }
    }

    var emoji: String {
        switch self {
        case .home:   return "🏠"
        case .garden: return "🏡"
        case .pond:   return "🌊"
        case .coast:  return "🏖️"
        case .meadow: return "🌼"
        case .woods:  return "🌲"
        case .sky:    return "🌤️"
        case .wilds:  return "🌴"
        }
    }

    /// The soft backdrop for the zone's scene.
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .home:   colors = [Color(hex: 0xFFEFE6), Color(hex: 0xFFDCC9)]
        case .garden: colors = [Color(hex: 0xEEF6DB), Color(hex: 0xDCEDC2)]
        case .pond:   colors = [Color(hex: 0xDCF1FF), Color(hex: 0xBFE6F7)]
        case .coast:  colors = [Color(hex: 0xFFF0D4), Color(hex: 0xB8E4EC)]
        case .meadow: colors = [Color(hex: 0xF4F6D9), Color(hex: 0xE6EFC2)]
        case .woods:  colors = [Color(hex: 0xDCF0DC), Color(hex: 0xC2E4C2)]
        case .sky:    colors = [Color(hex: 0xDDEFFF), Color(hex: 0xC7E4FF)]
        case .wilds:  colors = [Color(hex: 0xFCE9C9), Color(hex: 0xF6D6A0)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// All habitats in Grove display order.
    static var ordered: [Habitat] {
        allCases.sorted { $0.order < $1.order }
    }
}
