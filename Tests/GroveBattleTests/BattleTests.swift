import XCTest
@testable import GroveBattle

final class BattleTests: XCTestCase {

    // Every archetype shares the same stat budget at a given level — species is
    // shape, never power.
    func testArchetypeTotalsEqualAtLevel() {
        for lvl in [1, 10, 20, 30] {
            let total = totalBudget(atLevel: lvl)
            for a in Archetype.allCases {
                let card = BattleCard(name: "x", type: .bloom, archetype: a, level: lvl)
                XCTAssertLessThanOrEqual(abs(card.stats.sum - total), 3,
                    "\(a) L\(lvl): sum \(card.stats.sum) vs budget \(total)")
            }
        }
    }

    // The eight-type wheel: beats the next two clockwise, weak to the two behind.
    func testTypeWheel() {
        XCTAssertEqual(BattleType.bloom.multiplier(against: .tide),   1.04, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .shore),  1.04, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .hearth), 0.97, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .feral),  0.97, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .meadow), 1.0, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .bloom),  1.0, accuracy: 0.001)
    }

    // Same inputs + seed → identical match, every time. The property that makes
    // async replays verifiable.
    func testDeterminism() {
        let a = BattleCard(name: "A", type: .bloom, archetype: .skirmisher, level: 20)
        let b = BattleCard(name: "B", type: .bloom, archetype: .bruiser, level: 20)
        let r1 = simulate(a, .defaultPlan(for: .skirmisher), vs: b, .defaultPlan(for: .bruiser), seed: 42)
        let r2 = simulate(a, .defaultPlan(for: .skirmisher), vs: b, .defaultPlan(for: .bruiser), seed: 42)
        XCTAssertEqual(r1, r2)
        XCTAssertFalse(r1.log.isEmpty)
    }

    // A much higher level should reliably beat a much lower one.
    func testLevelMatters() {
        var highWins = 0
        for s in 0..<100 {
            let hi = BattleCard(name: "Hi", type: .bloom, archetype: .skirmisher, level: 25)
            let lo = BattleCard(name: "Lo", type: .bloom, archetype: .skirmisher, level: 8)
            let r = simulate(hi, .defaultPlan(for: .skirmisher), vs: lo, .defaultPlan(for: .skirmisher), seed: UInt64(s * 7 + 1))
            if case .win("Hi") = r.outcome { highWins += 1 }
        }
        XCTAssertGreaterThan(highWins, 90, "high level won only \(highWins)/100")
    }

    // Every match must terminate with a decision or a draw — no infinite loops.
    func testEngineTerminates() {
        for x in Archetype.allCases {
            for y in Archetype.allCases {
                let a = BattleCard(name: "X", type: .bloom, archetype: x, level: 20)
                let b = BattleCard(name: "Y", type: .bloom, archetype: y, level: 20)
                let r = simulate(a, .defaultPlan(for: x), vs: b, .defaultPlan(for: y), seed: 99)
                XCTAssertGreaterThan(r.turns, 0)
                XCTAssertLessThanOrEqual(r.turns, 60)
            }
        }
    }

    // The triangle, as a regression guard: over many seeds (neutral types isolate
    // archetype shape) each favoured side must win > 50%. Also prints the rates.
    func testCoreMatchupWinRates() {
        func winRate(_ x: Archetype, _ y: Archetype, seeds: Int = 500) -> (Double, Int) {
            var xWins = 0, decided = 0
            for s in 0..<seeds {
                let a = BattleCard(name: "X", type: .bloom, archetype: x, level: 20)
                let b = BattleCard(name: "Y", type: .bloom, archetype: y, level: 20)
                let r = simulate(a, .defaultPlan(for: x), vs: b, .defaultPlan(for: y), seed: UInt64(s * 2 + 1))
                if case .win(let n) = r.outcome { decided += 1; if n == "X" { xWins += 1 } }
            }
            return (decided == 0 ? 0.5 : Double(xWins) / Double(decided), decided)
        }
        let sb = winRate(.skirmisher, .bruiser)
        let bw = winRate(.bruiser, .wall)
        let ws = winRate(.wall, .skirmisher)
        print(String(format: "\n=== CORE MATCHUP WIN RATES (favoured side should trend > 50%%) ===\n"
            + "  Skirmisher › Bruiser : %5.1f%%  (%d decided)\n"
            + "  Bruiser    › Wall    : %5.1f%%  (%d decided)\n"
            + "  Wall       › Skirmisher: %5.1f%%  (%d decided)\n",
            sb.0 * 100, sb.1, bw.0 * 100, bw.1, ws.0 * 100, ws.1))
        XCTAssertGreaterThan(sb.0, 0.5, "Speed should beat Power")
        XCTAssertGreaterThan(bw.0, 0.5, "Power should beat Bulk")
        XCTAssertGreaterThan(ws.0, 0.5, "Bulk should beat Speed")
    }
    // A readable play-by-play of one match — a diagnostic while we tune balance,
    // and a preview of exactly what the Arena UI renders from the same events.
    func testPrintSampleReplay() {
        let a = BattleCard(name: "Fox",  type: .bloom, archetype: .skirmisher, level: 20)
        let b = BattleCard(name: "Bear", type: .timber, archetype: .bruiser,   level: 20)
        let r = simulate(a, .defaultPlan(for: .skirmisher), vs: b, .defaultPlan(for: .bruiser), seed: 7)
        print("\n" + renderReplay(r))
    }

    // The structured stream a UI consumes must stay faithful to the flat log and
    // to the outcome: same order, tracked HP, and a loser actually at 0 HP.
    func testReplayEventsAreConsistent() {
        let a = BattleCard(name: "Fox",  type: .bloom, archetype: .skirmisher, level: 20)
        let b = BattleCard(name: "Bear", type: .timber, archetype: .bruiser,   level: 20)
        let r = simulate(a, .defaultPlan(for: .skirmisher), vs: b, .defaultPlan(for: .bruiser), seed: 7)

        XCTAssertFalse(r.events.isEmpty)
        XCTAssertEqual(r.log, r.events.map(\.text), "log must mirror the event stream")
        XCTAssertEqual(r.fighters.count, 2)
        for e in r.events {
            XCTAssertEqual(e.hpAfter.count, 2)
            XCTAssertEqual(e.staminaAfter.count, 2)
            XCTAssertTrue(e.actor == 0 || e.actor == 1)
            XCTAssertLessThanOrEqual(e.round, r.turns)
        }
        // On a decisive win, the final snapshot must show the loser dropped to 0.
        if case .win(let winner) = r.outcome, let last = r.events.last {
            let loserSide = winner == r.fighters[0].name ? 1 : 0
            XCTAssertLessThanOrEqual(last.hpAfter[loserSide], 0, "the loser should be at 0 HP in the last event")
        }
    }
    // Row archetype's win-rate vs each column (neutral types). Prints the whole meta.
    func testFullMatrix() {
        func rate(_ x: Archetype, _ y: Archetype, seeds: Int = 300) -> Double {
            if x == y { return 0.5 }
            var xw = 0, dec = 0
            for s in 0..<seeds {
                let a = BattleCard(name: "X", type: .bloom, archetype: x, level: 20)
                let b = BattleCard(name: "Y", type: .bloom, archetype: y, level: 20)
                let r = simulate(a, .defaultPlan(for: x), vs: b, .defaultPlan(for: y), seed: UInt64(s * 2 + 1))
                if case .win(let n) = r.outcome { dec += 1; if n == "X" { xw += 1 } }
            }
            return dec == 0 ? 0.5 : Double(xw) / Double(dec)
        }
        let all = Archetype.allCases
        func pad(_ str: String, _ w: Int) -> String {
            let t = String(str.prefix(w))
            return String(repeating: " ", count: max(0, w - t.count)) + t
        }
        var header = pad("", 11)
        for y in all { header += pad(String(y.rawValue.prefix(4)), 6) }
        print("\n" + header)
        for x in all {
            var row = pad(x.rawValue, 11)
            for y in all { row += pad(String(Int((rate(x, y) * 100).rounded())), 6) }
            print(row)
        }
    }

    // Type advantage should clearly favour the attacker, all else equal.
    func testTypeAdvantageMatters() {
        var advWins = 0, decided = 0
        for s in 0..<400 {
            let a = BattleCard(name: "Adv", type: .bloom, archetype: .allrounder, level: 20) // bloom beats tide
            let b = BattleCard(name: "Dis", type: .tide,  archetype: .allrounder, level: 20)
            let r = simulate(a, .defaultPlan(for: .allrounder), vs: b, .defaultPlan(for: .allrounder), seed: UInt64(s * 3 + 1))
            if case .win(let n) = r.outcome { decided += 1; if n == "Adv" { advWins += 1 } }
        }
        let rate = Double(advWins) / Double(decided)
        print(String(format: "\nType advantage (Bloom vs Tide, mirror archetype): %.1f%%", rate * 100))
        XCTAssertGreaterThan(rate, 0.6, "type advantage should clearly favour the attacker")
    }
}
