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

    /// Friends that read instantly as *this* zone — the empty-zone hints draw
    /// only from these, so the bubbles always match the zone's title (no goat
    /// in the Garden, no peacock in the Treetops). Hand-picked from the
    /// catalog, easiest finds first.
    private var hintSpeciesIDs: [String] {
        switch self {
        case .home:   return ["housecat", "dog", "hamster"]
        case .garden: return ["squirrel", "bird", "robin", "pigeon", "crow", "mouse"]
        case .pond:   return ["duck", "fish", "turtle", "frog"]
        case .coast:  return ["crab", "seal", "octopus"]
        case .meadow: return ["bee", "butterfly", "ladybug", "rabbit", "grasshopper", "snail"]
        case .woods:  return ["fox", "hedgehog", "raccoon", "deer", "owl"]
        case .sky:    return ["hummingbird", "parrot", "eagle"]
        case .wilds:  return ["monkey", "zebra", "lion", "elephant", "giraffe", "lizard"]
        }
    }

    /// Where to look for this zone's friends, shown under an empty zone's hints.
    var lookHint: String {
        switch self {
        case .home:   return "Try your home, porch & windowsills"
        case .garden: return "Try hedges, lawns & bird feeders"
        case .pond:   return "Try ponds, streams & reedy banks"
        case .coast:  return "Try beaches & rock pools"
        case .meadow: return "Try flower beds & tall grass"
        case .woods:  return "Try woodland paths at dusk"
        case .sky:    return "Look up: branches & treetops"
        case .wilds:  return "Try zoos, safaris & far-off trips"
        }
    }

    /// A few friends who might visit this zone — what an empty zone suggests
    /// instead of sitting blank. Rotated by day so the hints feel fresh each
    /// visit.
    func likelyVisitors(count: Int = 3, on date: Date = .now, calendar: Calendar = .current) -> [Species] {
        let pool = hintSpeciesIDs.compactMap { id in CreatureCatalog.all.first { $0.id == id } }
        guard !pool.isEmpty else { return [] }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let start = day % pool.count
        let rotated = Array(pool[start...] + pool[..<start])
        // Emoji are shared by some kinds (several birds are 🐦), so skip
        // repeats — three identical bubbles would read as one hint.
        var seen = Set<String>()
        return Array(rotated.filter { seen.insert($0.emoji).inserted }.prefix(count))
    }
}
