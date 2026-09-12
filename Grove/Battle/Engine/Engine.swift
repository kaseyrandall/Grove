import Foundation

// MARK: - Result

public struct BattleResult: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable { case win(String), draw }
    public var outcome: Outcome
    public var turns: Int
    public var fighters: [Fighter]     // [side0, side1] — self-describing, for the UI
    public var events: [ReplayEvent]   // the ordered, structured play-by-play
    public var log: [String]           // convenience: events.map(\.text)
}

// MARK: - Combatant (mutable battle state)

private struct Combatant {
    var card: BattleCard
    var plan: BattlePlan
    let maxHP: Int
    let maxStamina: Int
    var hp: Int
    var stamina: Int
    var specialUsed = false
    var evasionCharges: Int = 0    // feint dodges the next couple of incoming hits
    var guardReduction: Double = 0 // consumed by the next incoming hit
    var stunned = false
    var stunImmuneTurns = 0

    init(_ card: BattleCard, _ plan: BattlePlan) {
        self.card = card
        self.plan = plan
        self.maxHP = card.stats.hp * 3        // room so a fight breathes (6–14 turns)
        self.maxStamina = card.stats.sta
        self.hp = maxHP
        self.stamina = maxStamina
    }

    var fighter: Fighter {
        Fighter(name: card.name, type: card.type, archetype: card.archetype,
                level: card.level, maxHP: maxHP, maxStamina: maxStamina)
    }
}

/// A beat produced inside an action, before `simulate` stamps it with the round
/// number and the HP/stamina snapshot.
private struct RawEvent { var kind: ReplayEvent.Kind; var text: String }

// MARK: - Engine

private let staminaRegen = 6
private let breatherRegen = 14
private let turnCap = 60

/// Simulate a full match deterministically. Same cards + plans + seed → identical
/// result and log, every time and on every device.
public func simulate(_ aCard: BattleCard, _ aPlan: BattlePlan,
                     vs bCard: BattleCard, _ bPlan: BattlePlan,
                     seed: UInt64) -> BattleResult {
    var rng = SeededRNG(seed: seed)
    var c = [Combatant(aCard, aPlan), Combatant(bCard, bPlan)]
    var events: [ReplayEvent] = []

    // Stamp a batch of raw beats by one actor with the round and the state they left.
    func record(_ raw: [RawEvent], actor: Int, round: Int) {
        for r in raw {
            events.append(ReplayEvent(round: round, actor: actor, kind: r.kind, text: r.text,
                                      hpAfter: [c[0].hp, c[1].hp],
                                      staminaAfter: [c[0].stamina, c[1].stamina]))
        }
    }

    func order() -> [Int] {
        if c[0].card.stats.spd != c[1].card.stats.spd {
            return c[0].card.stats.spd > c[1].card.stats.spd ? [0, 1] : [1, 0]
        }
        return rng.coin() ? [0, 1] : [1, 0]
    }

    var turn = 0
    outer: while turn < turnCap {
        turn += 1
        c[0].stamina = min(c[0].maxStamina, c[0].stamina + staminaRegen)
        c[1].stamina = min(c[1].maxStamina, c[1].stamina + staminaRegen)

        for side in order() {
            let foeSide = 1 - side
            if c[side].hp <= 0 || c[foeSide].hp <= 0 { continue }
            if c[side].stunned {
                c[side].stunned = false
                c[side].stunImmuneTurns = 2  // shake it off — immune to stun for a couple turns
                record([RawEvent(kind: .dazedSkip, text: "\(c[side].card.name) is dazed and skips a turn.")],
                       actor: side, round: turn)
                continue
            }
            var me = c[side], foe = c[foeSide]
            if me.stunImmuneTurns > 0 { me.stunImmuneTurns -= 1 }
            let action = choose(me: me, foe: foe)
            var raw: [RawEvent] = []
            apply(action, me: &me, foe: &foe, rng: &rng, raw: &raw)
            c[side] = me; c[foeSide] = foe
            record(raw, actor: side, round: turn)
            if c[foeSide].hp <= 0 { break outer }
        }
        // Speed's real edge: the much faster occasionally act again.
        let fast = c[0].card.stats.spd >= c[1].card.stats.spd ? 0 : 1
        let slow = 1 - fast
        let spdRatio = Double(c[fast].card.stats.spd) / Double(max(1, c[slow].card.stats.spd))
        let extraChance = min(0.85, max(0.0, (spdRatio - 1.2) * 0.95))
        if c[fast].hp > 0 && c[slow].hp > 0 && rng.chance(extraChance) {
            var me = c[fast], foe = c[slow]
            if me.stunImmuneTurns > 0 { me.stunImmuneTurns -= 1 }
            var raw: [RawEvent] = [RawEvent(kind: .extraMove, text: "\(me.card.name) is a blur — an extra move!")]
            apply(choose(me: me, foe: foe), me: &me, foe: &foe, rng: &rng, raw: &raw)
            c[fast] = me; c[slow] = foe
            record(raw, actor: fast, round: turn)
        }
        if c[0].hp <= 0 || c[1].hp <= 0 { break }
    }

    let outcome: BattleResult.Outcome
    let dead0 = c[0].hp <= 0, dead1 = c[1].hp <= 0
    if dead0 && dead1 { outcome = .draw }
    else if dead1 { outcome = .win(c[0].card.name) }
    else if dead0 { outcome = .win(c[1].card.name) }
    else {
        let p0 = Double(c[0].hp) / Double(c[0].maxHP)
        let p1 = Double(c[1].hp) / Double(c[1].maxHP)
        outcome = abs(p0 - p1) < 0.02 ? .draw : .win(p0 > p1 ? c[0].card.name : c[1].card.name)
    }
    return BattleResult(outcome: outcome, turns: turn,
                        fighters: [c[0].fighter, c[1].fighter],
                        events: events, log: events.map(\.text))
}

// MARK: - Decision (walk the gambit list, first true rule fires)

private func choose(me: Combatant, foe: Combatant) -> PlanAction {
    for rule in me.plan.rules where matches(rule.when, me: me, foe: foe) {
        return rule.then
    }
    return .strike
}

private func matches(_ cond: Condition, me: Combatant, foe: Combatant) -> Bool {
    switch cond {
    case .foeHPBelow(let f):      return Double(foe.hp) < Double(foe.maxHP) * f
    case .myHPBelow(let f):       return Double(me.hp) < Double(me.maxHP) * f
    case .myStaminaBelow(let s):  return me.stamina < s
    case .foeIsArchetype(let a):  return foe.card.archetype == a
    case .specialReady:           return !me.specialUsed && me.stamina >= me.card.special.stamina
    case .feintOpportunity:       return me.evasionCharges == 0 && foe.card.stats.atk >= 80
    case .foeControllable:        return !foe.stunned && foe.stunImmuneTurns == 0
    case .always:                 return true
    }
}

// MARK: - Execution

private func apply(_ action: PlanAction, me: inout Combatant, foe: inout Combatant,
                   rng: inout SeededRNG, raw: inout [RawEvent]) {
    switch action {
    case .catchBreath:
        me.stamina = min(me.maxStamina, me.stamina + breatherRegen)
        raw.append(RawEvent(kind: .catchBreath, text: "\(me.card.name) catches its breath."))
    case .useSpecial:
        if me.specialUsed || me.stamina < me.card.special.stamina {
            resolve(me.card.strike, me: &me, foe: &foe, rng: &rng, raw: &raw, breatherIfBroke: true)
        } else {
            me.specialUsed = true
            resolve(me.card.special, me: &me, foe: &foe, rng: &rng, raw: &raw, breatherIfBroke: false)
        }
    case .utility:
        resolve(me.card.utility, me: &me, foe: &foe, rng: &rng, raw: &raw, breatherIfBroke: true)
    case .strike:
        resolve(me.card.strike, me: &me, foe: &foe, rng: &rng, raw: &raw, breatherIfBroke: true)
    }
}

/// Carry out one move: spend stamina, apply self-buffs, roll to hit, deal damage
/// (type × ATK/DEF, softened by an exponent so nothing one-shots), apply foe effects.
private func resolve(_ move: Move, me: inout Combatant, foe: inout Combatant,
                     rng: inout SeededRNG, raw: inout [RawEvent], breatherIfBroke: Bool) {
    if me.stamina < move.stamina {
        if breatherIfBroke {
            me.stamina = min(me.maxStamina, me.stamina + breatherRegen)
            raw.append(RawEvent(kind: .winded, text: "\(me.card.name) is winded and catches its breath."))
        }
        return
    }
    me.stamina -= move.stamina

    if let e = move.effect {
        switch e {
        case .evade:          me.evasionCharges = 2
        case .guardUp(let v): me.guardReduction = v
        case .rally(let v):
            let heal = Int(Double(me.maxHP) * v)
            me.hp = min(me.maxHP, me.hp + heal)
            raw.append(RawEvent(kind: .heal(move: move.name, amount: heal),
                                text: "\(me.card.name) uses \(move.name) and recovers \(heal) HP."))
        default: break
        }
    }

    if move.power > 0 {
        let dodge = foe.evasionCharges > 0 ? 0.5 : 0.0
        if foe.evasionCharges > 0 { foe.evasionCharges -= 1 }
        if !rng.chance(move.accuracy * (1.0 - dodge)) {
            raw.append(RawEvent(kind: .miss(move: move.name), text: "\(me.card.name)'s \(move.name) misses!"))
            return
        }
        let mult = me.card.type.multiplier(against: foe.card.type)
        let ratio = pow(Double(me.card.stats.atk) / Double(max(1, foe.card.stats.def)), 0.92)
        var dmg = Int((Double(move.power) * ratio * mult * rng.variance(0.12)).rounded())
        if foe.guardReduction > 0 {
            dmg = Int(Double(dmg) * (1 - foe.guardReduction))
            foe.guardReduction = 0
        }
        dmg = max(1, dmg)
        foe.hp -= dmg
        let eff: Effectiveness = mult > 1.0 ? .advantaged : (mult < 1.0 ? .resisted : .neutral)
        var line = "\(me.card.name) uses \(move.name) for \(dmg)."
        if eff == .advantaged { line += " Type edge!" } else if eff == .resisted { line += " Resisted." }
        raw.append(RawEvent(kind: .strike(move: move.name, damage: dmg, effectiveness: eff), text: line))

        if let e = move.effect {
            switch e {
            case .stun:
                if foe.stunImmuneTurns > 0 {
                    raw.append(RawEvent(kind: .shrugOff, text: "\(foe.card.name) shrugs off the hex."))
                } else {
                    foe.stunned = true
                    raw.append(RawEvent(kind: .stunApplied, text: "\(foe.card.name) is dazed!"))
                }
            case .drain(let s): foe.stamina = max(0, foe.stamina - s)
            default: break
            }
        }
    } else if let e = move.effect {
        switch e {
        case .evade:   raw.append(RawEvent(kind: .feint(move: move.name), text: "\(me.card.name) uses \(move.name) — harder to hit now."))
        case .guardUp: raw.append(RawEvent(kind: .brace(move: move.name), text: "\(me.card.name) braces for the next blow."))
        default: break
        }
    }
}
