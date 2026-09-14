import Foundation

// MARK: - A persistable, editable mirror of the engine's Battle Plan
//
// The engine's Condition / PlanAction / Rule aren't Codable (they're pure value
// types in the isolated package mirror). These lightweight specs are the Codable,
// UI-friendly twin the editor edits and the roster persists, converted to the
// engine's `BattlePlan` at fight time.

extension BattleType: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BattleType(rawValue: raw) ?? .hearth
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

extension Archetype: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Archetype(rawValue: raw) ?? .allrounder
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// One "IF this" clause. Parameterised conditions carry whole-number values
/// (percent / count) so the editor can offer clean, tappable choices.
enum CondSpec: Codable, Hashable {
    case always
    case foeHPBelow(Int)      // percent
    case myHPBelow(Int)       // percent
    case myStaminaBelow(Int)
    case specialReady
    case foeControllable
    case feintOpportunity
    case foeIsArchetype(Archetype)

    var condition: Condition {
        switch self {
        case .always:                return .always
        case .foeHPBelow(let p):     return .foeHPBelow(Double(p) / 100)
        case .myHPBelow(let p):      return .myHPBelow(Double(p) / 100)
        case .myStaminaBelow(let s): return .myStaminaBelow(s)
        case .specialReady:          return .specialReady
        case .foeControllable:       return .foeControllable
        case .feintOpportunity:      return .feintOpportunity
        case .foeIsArchetype(let a): return .foeIsArchetype(a)
        }
    }

    init(_ c: Condition) {
        switch c {
        case .always:                self = .always
        case .foeHPBelow(let f):     self = .foeHPBelow(Int((f * 100).rounded()))
        case .myHPBelow(let f):      self = .myHPBelow(Int((f * 100).rounded()))
        case .myStaminaBelow(let s): self = .myStaminaBelow(s)
        case .foeIsArchetype(let a): self = .foeIsArchetype(a)
        case .specialReady:          self = .specialReady
        case .feintOpportunity:      self = .feintOpportunity
        case .foeControllable:       self = .foeControllable
        }
    }

    var label: String {
        switch self {
        case .always:                return "Always"
        case .foeHPBelow(let p):     return "Foe HP < \(p)%"
        case .myHPBelow(let p):      return "My HP < \(p)%"
        case .myStaminaBelow(let s): return "My stamina < \(s)"
        case .specialReady:          return "Special is ready"
        case .foeControllable:       return "Foe can be stunned"
        case .feintOpportunity:      return "Good time to feint"
        case .foeIsArchetype(let a): return "Foe is a \(a.rawValue.capitalized)"
        }
    }

    /// The menu of clauses the editor offers, common-to-niche, ending in Always.
    static let choices: [CondSpec] = [
        .foeHPBelow(50), .foeHPBelow(25),
        .myHPBelow(35),
        .myStaminaBelow(6),
        .specialReady,
        .foeControllable,
        .feintOpportunity,
        .foeIsArchetype(.bruiser), .foeIsArchetype(.wall), .foeIsArchetype(.skirmisher),
        .always,
    ]
}

/// One "DO that" clause.
enum ActSpec: String, Codable, CaseIterable, Hashable {
    case useSpecial, strike, utility, catchBreath

    var action: PlanAction {
        switch self {
        case .useSpecial:  return .useSpecial
        case .strike:      return .strike
        case .utility:     return .utility
        case .catchBreath: return .catchBreath
        }
    }
    init(_ a: PlanAction) {
        switch a {
        case .useSpecial:  self = .useSpecial
        case .strike:      self = .strike
        case .utility:     self = .utility
        case .catchBreath: self = .catchBreath
        }
    }
    var label: String {
        switch self {
        case .useSpecial:  return "Use special"
        case .strike:      return "Strike"
        case .utility:     return "Utility move"
        case .catchBreath: return "Catch breath"
        }
    }
}

struct StoredRule: Codable, Hashable, Identifiable {
    var id = UUID()
    var condition: CondSpec
    var action: ActSpec
    init(id: UUID = UUID(), condition: CondSpec, action: ActSpec) {
        self.id = id; self.condition = condition; self.action = action
    }
}

/// A whole plan: an ordered list of rules. First true rule fires each turn.
struct StoredPlan: Codable, Hashable {
    var rules: [StoredRule]

    var battlePlan: BattlePlan {
        BattlePlan(rules: rules.map { Rule($0.condition.condition, $0.action.action) })
    }

    init(rules: [StoredRule]) { self.rules = rules }

    /// Seed a spec from an engine plan (e.g. an archetype default) for editing.
    init(_ plan: BattlePlan) {
        self.rules = plan.rules.map { StoredRule(condition: CondSpec($0.when), action: ActSpec($0.then)) }
    }

    // A couple of generic presets beyond each archetype's own default.
    static var aggressive: StoredPlan {
        StoredPlan(rules: [
            StoredRule(condition: .foeHPBelow(50), action: .useSpecial),
            StoredRule(condition: .myStaminaBelow(6), action: .catchBreath),
            StoredRule(condition: .always, action: .strike),
        ])
    }
    static var defensive: StoredPlan {
        StoredPlan(rules: [
            StoredRule(condition: .myHPBelow(40), action: .utility),
            StoredRule(condition: .myStaminaBelow(8), action: .catchBreath),
            StoredRule(condition: .specialReady, action: .useSpecial),
            StoredRule(condition: .always, action: .strike),
        ])
    }
}
