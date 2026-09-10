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
        XCTAssertEqual(BattleType.bloom.multiplier(against: .tide),   1.5, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .shore),  1.5, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .hearth), 0.67, accuracy: 0.001)
        XCTAssertEqual(BattleType.bloom.multiplier(against: .feral),  0.67, accuracy: 0.001)
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
    // A readable play-by-play of one match — a diagnostic while we tune balance.
    func testPrintSampleReplay() {
        let a = BattleCard(name: "Fox",  type: .bloom, archetype: .skirmisher, level: 20)
        let b = BattleCard(name: "Bear", type: .bloom, archetype: .bruiser,    level: 20)
        print("\n--- Fox (Skirmisher \(a.stats.hp*3)HP spd\(a.stats.spd) atk\(a.stats.atk) def\(a.stats.def)) "
            + "vs Bear (Bruiser \(b.stats.hp*3)HP spd\(b.stats.spd) atk\(b.stats.atk) def\(b.stats.def)) ---")
        let r = simulate(a, .defaultPlan(for: .skirmisher), vs: b, .defaultPlan(for: .bruiser), seed: 7)
        for (i, line) in r.log.enumerated() { print(String(format: "%3d  %@", i + 1, line)) }
        switch r.outcome {
        case .win(let n): print(">>> \(n) wins in \(r.turns) rounds")
        case .draw:       print(">>> draw after \(r.turns) rounds")
        }
    }
}
