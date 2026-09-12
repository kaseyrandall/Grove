import Foundation

/// Render a finished match as a clean, human-readable transcript — round headers,
/// text HP bars that track after every beat, and a final banner. This is the
/// diagnostic view of the same structured `events` a UI renders graphically, so
/// what we read here is exactly what the Arena will show.
public func renderReplay(_ r: BattleResult) -> String {
    let f = r.fighters
    let nameW = max(f[0].name.count, f[1].name.count, 4)

    func pad(_ s: String, _ n: Int) -> String {
        s.count >= n ? String(s.prefix(n)) : s + String(repeating: " ", count: n - s.count)
    }
    func bar(_ side: Int, _ hp: [Int], width: Int = 14) -> String {
        let m = max(1, f[side].maxHP)
        let frac = max(0.0, min(1.0, Double(hp[side]) / Double(m)))
        let filled = Int((frac * Double(width)).rounded())
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }
    // Both fighters' HP, side by side, after a given beat.
    func hpLine(_ hp: [Int]) -> String {
        "\(pad(f[0].name, nameW)) \(bar(0, hp)) \(String(format: "%4d", max(0, hp[0])))"
        + "   ·   "
        + "\(pad(f[1].name, nameW)) \(bar(1, hp)) \(String(format: "%4d", max(0, hp[1])))"
    }
    func title(_ side: Int) -> String {
        let x = f[side]
        return "\(x.name) · \(x.archetype.rawValue.capitalized) · \(x.type.rawValue.capitalized) · Lv\(x.level) · \(x.maxHP) HP"
    }

    var out = ""
    out += "══════════════════════════════════════════════════════════════\n"
    out += "  GROVE BATTLEGROUNDS — REPLAY\n"
    out += "  \(title(0))\n"
    out += "  \(title(1))\n"
    out += "══════════════════════════════════════════════════════════════\n"

    var round = 0
    for e in r.events {
        if e.round != round {
            round = e.round
            out += "\nRound \(round)\n"
        }
        let marker: String
        switch e.kind {
        case .strike(_, _, let eff): marker = eff == .advantaged ? "▲" : (eff == .resisted ? "▽" : "•")
        case .miss:                  marker = "×"
        case .heal:                  marker = "✚"
        case .brace, .feint:         marker = "◆"
        case .stunApplied:           marker = "✦"
        case .shrugOff:              marker = "○"
        case .dazedSkip:             marker = "z"
        case .catchBreath, .winded:  marker = "~"
        case .extraMove:             marker = "»"
        }
        out += "  \(marker) \(e.text)\n"
        // Show the bars on beats that moved HP.
        switch e.kind {
        case .strike, .heal: out += "      \(hpLine(e.hpAfter))\n"
        default: break
        }
    }

    out += "\n──────────────────────────────────────────────────────────────\n"
    switch r.outcome {
    case .win(let n): out += "  ★ \(n) wins in \(r.turns) rounds\n"
    case .draw:       out += "  = draw after \(r.turns) rounds\n"
    }
    let last = r.events.last?.hpAfter ?? [f[0].maxHP, f[1].maxHP]
    out += "  \(hpLine(last))\n"
    out += "──────────────────────────────────────────────────────────────\n"
    return out
}
