import SwiftUI

// MARK: - Shared Battlegrounds look & type colors
//
// Lives here (internal, not private) so both the roster/card screens and the
// Arena replay can share one palette and one set of type colors.

enum BattleTheme {
    static let ink       = Color(hex: 0xEAF3EC)
    static let muted     = Color(hex: 0x8FAE9C)
    static let panel     = Color(hex: 0x132019)
    static let panelLo   = Color(hex: 0x0E1712)
    static let panelLine = Color(hex: 0x294536)
    static let gold      = Color(hex: 0xF3D17A)
    static let leaf      = Color(hex: 0x6FC07A)
    static let leafDeep  = Color(hex: 0x3F9A58)

    static var background: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x0E1A14), Color(hex: 0x0A130F)],
                       startPoint: .top, endPoint: .bottom)
    }
    static var panelFill: LinearGradient {
        LinearGradient(colors: [panel, panelLo], startPoint: .top, endPoint: .bottom)
    }
}

extension BattleType {
    /// The type's signature color (the eight-habitat wheel).
    var color: Color {
        switch self {
        case .hearth: return Color(hex: 0xE8743B)
        case .bloom:  return Color(hex: 0xEC7FB0)
        case .tide:   return Color(hex: 0x3F82CF)
        case .shore:  return Color(hex: 0x63C2C9)
        case .meadow: return Color(hex: 0x6FB84A)
        case .timber: return Color(hex: 0xA9834F)
        case .gale:   return Color(hex: 0x8FB6D6)
        case .feral:  return Color(hex: 0xA96FD0)
        }
    }
}

extension Color {
    /// Darken toward black by `amount` (0…1) — for a token's shaded underside.
    func darkened(_ amount: Double = 0.4) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let f = 1 - amount
        return Color(.sRGB, red: r * f, green: g * f, blue: b * f, opacity: a)
    }
}

// MARK: - Catch → BattleCard

extension BattleType {
    /// Each Grove zone maps to one battle type (8 zones ↔ 8 types).
    init(habitat: Habitat) {
        switch habitat {
        case .home:   self = .hearth
        case .garden: self = .bloom
        case .pond:   self = .tide
        case .coast:  self = .shore
        case .meadow: self = .meadow
        case .woods:  self = .timber
        case .sky:    self = .gale
        case .wilds:  self = .feral
        }
    }
}

extension Archetype {
    /// A friend's playstyle is fixed by its *kind*, deterministically — the same
    /// species always fights the same way, and rarity never enters into it.
    /// (Swift's own `Hasher` is per-run randomized, so we use a stable FNV-1a.)
    static func derived(fromSpeciesID id: String) -> Archetype {
        var h: UInt64 = 0xcbf29ce484222325
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        let all = Archetype.allCases
        return all[Int(h % UInt64(all.count))]
    }
}

// MARK: - Contender (a fighter chosen for a match)

/// A battle-ready fighter derived from either a real `Catch` or a generated
/// wild rival. Holds identity + optional portrait; produces a `BattleCard` at a
/// chosen level on demand (level comes from battle XP later — not from the catch).
struct Contender: Identifiable {
    let id = UUID()
    var name: String
    var type: BattleType
    var archetype: Archetype
    var photoData: Data?

    func card(level: Int) -> BattleCard {
        BattleCard(name: name, type: type, archetype: archetype, level: level)
    }

    static func from(_ c: Catch) -> Contender {
        Contender(name: c.displayName,
                  type: BattleType(habitat: c.effectiveZone),
                  archetype: .derived(fromSpeciesID: c.speciesID),
                  photoData: c.photoData)
    }

    /// A generated stand-in when the player has no second friend to face yet.
    static func wildRival(seed: UInt64) -> Contender {
        var rng = SeededRNG(seed: seed)
        func pick<T>(_ xs: [T]) -> T { xs[min(xs.count - 1, Int(rng.unit() * Double(xs.count)))] }
        let names = ["Rowan", "Sable", "Bram", "Pip", "Thorn", "Wren", "Juno", "Ash", "Moss", "Fen"]
        return Contender(name: pick(names),
                         type: pick(BattleType.allCases),
                         archetype: pick(Archetype.allCases),
                         photoData: nil)
    }
}
