import SwiftUI

/// A zone of the player's Grove. Every collectible `Species` belongs to one,
/// and the Grove screen lays its residents out zone by zone. These double as
/// the field-guide's natural groups — one structure, two payoffs.
enum Habitat: String, CaseIterable, Codable, Identifiable {
    case garden
    case pond
    case meadow
    case woods
    case sky

    var id: String { rawValue }

    /// Display order in the Grove (roughly homebody → wild).
    var order: Int {
        switch self {
        case .garden: return 0
        case .pond:   return 1
        case .meadow: return 2
        case .woods:  return 3
        case .sky:    return 4
        }
    }

    /// Full zone name, e.g. "The Garden".
    var displayName: String {
        switch self {
        case .garden: return "The Garden"
        case .pond:   return "The Pond"
        case .meadow: return "The Meadow"
        case .woods:  return "The Woods"
        case .sky:    return "The Treetops"
        }
    }

    /// Short name for sentences, e.g. "Lives in your Garden".
    var shortName: String {
        switch self {
        case .garden: return "Garden"
        case .pond:   return "Pond"
        case .meadow: return "Meadow"
        case .woods:  return "Woods"
        case .sky:    return "Treetops"
        }
    }

    var emoji: String {
        switch self {
        case .garden: return "🏡"
        case .pond:   return "🌊"
        case .meadow: return "🌼"
        case .woods:  return "🌲"
        case .sky:    return "🌤️"
        }
    }

    /// The soft backdrop for the zone's scene.
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .garden: colors = [Color(hex: 0xEEF6DB), Color(hex: 0xDCEDC2)]
        case .pond:   colors = [Color(hex: 0xDCF1FF), Color(hex: 0xBFE6F7)]
        case .meadow: colors = [Color(hex: 0xF4F6D9), Color(hex: 0xE6EFC2)]
        case .woods:  colors = [Color(hex: 0xDCF0DC), Color(hex: 0xC2E4C2)]
        case .sky:    colors = [Color(hex: 0xDDEFFF), Color(hex: 0xC7E4FF)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// All habitats in Grove display order.
    static var ordered: [Habitat] {
        allCases.sorted { $0.order < $1.order }
    }
}
