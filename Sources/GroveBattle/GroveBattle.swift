import Foundation

// MARK: - Deterministic RNG (SplitMix64)

/// A tiny, fast, fully deterministic RNG. The same seed always produces the same
/// battle — the property that lets an async match be simulated identically on
/// both devices and re-refereed server-side.
public struct SeededRNG {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    @inline(__always) private mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// A double in 0..<1.
    public mutating func unit() -> Double { Double(next() >> 11) * (1.0 / 9007199254740992.0) }
    public mutating func chance(_ p: Double) -> Bool { unit() < p }
    /// A multiplier in 1±spread.
    public mutating func variance(_ spread: Double) -> Double { 1.0 + (unit() * 2 - 1) * spread }
    public mutating func coin() -> Bool { next() & 1 == 0 }
}

// MARK: - Types (the eight-habitat wheel)

public enum BattleType: String, CaseIterable, Sendable {
    case hearth, bloom, tide, shore, meadow, timber, gale, feral

    /// Damage multiplier attacking `foe`. Each type beats the two clockwise from
    /// it (1.5×) and is weak to the two behind (0.67×); everything else is 1.0×.
    public func multiplier(against foe: BattleType) -> Double {
        let all = BattleType.allCases
        let n = all.count
        let i = all.firstIndex(of: self)!
        let j = all.firstIndex(of: foe)!
        let diff = (j - i + n) % n
        if diff == 1 || diff == 2 { return 1.04 }
        if diff == n - 1 || diff == n - 2 { return 0.97 }
        return 1.0
    }
}

// MARK: - Archetypes

/// A friend's playstyle. Sets the *shape* of its stats and how they grow — never
/// the total, which is equal across archetypes at a given level.
public enum Archetype: String, CaseIterable, Sendable {
    case skirmisher, striker, bruiser, wall, trickster, allrounder

    /// Stat weights [HP, ATK, DEF, SPD, STA]. Each vector sums to 300, which is
    /// also the total budget at Level 20 — so at L20 the weights *are* the stats.
    var weights: [Int] {
        switch self {
        case .skirmisher: return [55, 68, 45, 82, 50]
        case .striker:    return [45, 92, 35, 88, 40]
        case .bruiser:    return [82, 88, 55, 40, 35]
        case .wall:       return [100, 45, 90, 30, 35]
        case .trickster:  return [62, 55, 58, 60, 65]
        case .allrounder: return [68, 62, 60, 58, 52]
        }
    }
}

/// The shared stat budget at a level — identical for every archetype. L1 ≈ 120,
/// L20 = 300, soft-capped at L30.
public func totalBudget(atLevel level: Int) -> Int {
    let l = min(max(level, 1), 30)
    return Int((120.0 + Double(l - 1) * 9.47).rounded())
}

public struct Stats: Sendable, Equatable {
    public var hp, atk, def, spd, sta: Int
    public var sum: Int { hp + atk + def + spd + sta }
}

// MARK: - Moves & effects

public enum Effect: Sendable, Equatable {
    case rally(Double)    // heal a fraction of max HP
    case evade(Double)    // raise own evasion against the next incoming attack
    case stun             // foe loses their next turn
    case guardUp(Double)  // cut the next incoming hit by a fraction
    case drain(Int)       // sap foe stamina
}

public struct Move: Sendable, Equatable {
    public var name: String
    public var type: BattleType
    public var power: Int
    public var stamina: Int
    public var accuracy: Double
    public var effect: Effect?
    public var isSpecial: Bool
}

// MARK: - Replay (structured, so a UI can render — not just print — a match)

/// How the attacker's type fared against the defender's, for a badge in the UI.
public enum Effectiveness: Sendable, Equatable { case advantaged, neutral, resisted }

/// One thing that happened, in order, with the state it left behind. `hpAfter` /
/// `staminaAfter` are the full [side0, side1] snapshot *after* this beat, so a UI
/// can drive HP bars straight off the stream without re-simulating.
public struct ReplayEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case strike(move: String, damage: Int, effectiveness: Effectiveness)
        case miss(move: String)
        case heal(move: String, amount: Int)
        case brace(move: String)       // guard raised
        case feint(move: String)       // evasion raised
        case stunApplied               // the foe was dazed
        case shrugOff                  // the foe shrugged off a stun (immune)
        case dazedSkip                 // this side lost the turn to a daze
        case catchBreath
        case winded                    // tried to move but was out of stamina
        case extraMove                 // the fast side blurred in a bonus action
    }
    public var round: Int
    public var actor: Int              // 0 or 1 — the side taking the action
    public var kind: Kind
    public var text: String            // human-readable prose (also collected into `log`)
    public var hpAfter: [Int]          // [side0, side1] after this beat
    public var staminaAfter: [Int]

    public init(round: Int, actor: Int, kind: Kind, text: String, hpAfter: [Int], staminaAfter: [Int]) {
        self.round = round; self.actor = actor; self.kind = kind
        self.text = text; self.hpAfter = hpAfter; self.staminaAfter = staminaAfter
    }
}

/// A self-describing snapshot of a combatant, so a replay carries everything the
/// UI needs (names, bar maxima, identity) without touching the catalog.
public struct Fighter: Sendable, Equatable {
    public var name: String
    public var type: BattleType
    public var archetype: Archetype
    public var level: Int
    public var maxHP: Int
    public var maxStamina: Int
    public init(name: String, type: BattleType, archetype: Archetype, level: Int, maxHP: Int, maxStamina: Int) {
        self.name = name; self.type = type; self.archetype = archetype
        self.level = level; self.maxHP = maxHP; self.maxStamina = maxStamina
    }
}

// MARK: - Battle card (derived, not rolled)

public struct BattleCard: Sendable {
    public var name: String
    public var type: BattleType
    public var archetype: Archetype
    public var level: Int
    public var stats: Stats
    public var strike: Move
    public var utility: Move
    public var special: Move

    public init(name: String, type: BattleType, archetype: Archetype, level: Int) {
        self.name = name; self.type = type; self.archetype = archetype; self.level = level
        let total = totalBudget(atLevel: level)
        let w = archetype.weights
        let sum = w.reduce(0, +)
        func s(_ i: Int) -> Int { Int((Double(w[i]) * Double(total) / Double(sum)).rounded()) }
        self.stats = Stats(hp: s(0), atk: s(1), def: s(2), spd: s(3), sta: s(4))
        let m = BattleCard.moves(for: archetype, type: type)
        self.strike = m.0; self.utility = m.1; self.special = m.2
    }

    static func moves(for a: Archetype, type t: BattleType) -> (Move, Move, Move) {
        let strike = Move(name: "Strike", type: t, power: 18, stamina: 4, accuracy: 0.95, effect: nil, isSpecial: false)
        let utility: Move
        switch a {
        case .skirmisher, .striker:
            utility = Move(name: "Feint", type: t, power: 0, stamina: 3, accuracy: 1.0, effect: .evade(0.45), isSpecial: false)
        case .wall, .bruiser:
            utility = Move(name: "Brace", type: t, power: 0, stamina: 3, accuracy: 1.0, effect: .guardUp(0.5), isSpecial: false)
        case .trickster:
            utility = Move(name: "Hex", type: t, power: 8, stamina: 12, accuracy: 0.9, effect: .stun, isSpecial: false)
        case .allrounder:
            utility = Move(name: "Guard", type: t, power: 0, stamina: 3, accuracy: 1.0, effect: .guardUp(0.4), isSpecial: false)
        }
        let special: Move
        switch a {
        case .trickster:
            special = Move(name: "Mesmerize", type: t, power: 28, stamina: 12, accuracy: 0.9, effect: .stun, isSpecial: true)
        case .wall:
            special = Move(name: "Bulwark", type: t, power: 30, stamina: 11, accuracy: 0.95, effect: .guardUp(0.6), isSpecial: true)
        case .allrounder:
            special = Move(name: "Flourish", type: t, power: 32, stamina: 12, accuracy: 0.92, effect: nil, isSpecial: true)
        default:
            special = Move(name: "Onslaught", type: t, power: 34, stamina: 12, accuracy: 0.9, effect: .rally(0.15), isSpecial: true)
        }
        return (strike, utility, special)
    }
}

// MARK: - Battle Plan (gambits)

public enum Condition: Sendable {
    case foeHPBelow(Double)
    case myHPBelow(Double)
    case myStaminaBelow(Int)
    case foeIsArchetype(Archetype)
    case specialReady
    case feintOpportunity   // I'm exposed and the foe hits hard — time to feint
    case foeControllable    // the foe can be stunned right now (not already stunned/immune)
    case always
}

public enum PlanAction: Sendable {
    case useSpecial, strike, utility, catchBreath
}

public struct Rule: Sendable {
    public var when: Condition
    public var then: PlanAction
    public init(_ when: Condition, _ then: PlanAction) { self.when = when; self.then = then }
}

public struct BattlePlan: Sendable {
    public var rules: [Rule]
    public init(rules: [Rule]) { self.rules = rules }

    /// A sensible auto-plan per archetype, so a casual player never touches a rule.
    public static func defaultPlan(for a: Archetype) -> BattlePlan {
        switch a {
        case .skirmisher, .striker:
            return BattlePlan(rules: [
                Rule(.foeHPBelow(0.28), .useSpecial),
                Rule(.myStaminaBelow(7), .catchBreath),
                Rule(.feintOpportunity, .utility),
                Rule(.always, .strike),
            ])
        case .wall:
            return BattlePlan(rules: [
                Rule(.myStaminaBelow(5), .catchBreath),
                Rule(.foeHPBelow(0.45), .useSpecial),
                Rule(.always, .strike),
            ])
        case .bruiser:
            return BattlePlan(rules: [
                Rule(.foeHPBelow(0.55), .useSpecial),
                Rule(.myStaminaBelow(6), .catchBreath),
                Rule(.always, .strike),
            ])
        case .trickster:
            return BattlePlan(rules: [
                Rule(.specialReady, .useSpecial),
                Rule(.myStaminaBelow(8), .catchBreath),
                Rule(.foeControllable, .utility),
                Rule(.always, .strike),
            ])
        case .allrounder:
            return BattlePlan(rules: [
                Rule(.foeHPBelow(0.30), .useSpecial),
                Rule(.myHPBelow(0.35), .utility),
                Rule(.myStaminaBelow(5), .catchBreath),
                Rule(.always, .strike),
            ])
        }
    }
}
