import SwiftUI

// MARK: - The trophies

/// Arena trophies: bragging rights, never power. Each is earned once, by
/// playing, and kept in the `TrophyLedger` (synced with the team).
enum Trophy: String, CaseIterable, Identifiable {
    case firstWin, onARoll, veteran
    case giantSlayer, legendTamer, rivalGuide
    case fullDeck, everyHabitat, seasoned, groveLegend

    var id: String { rawValue }

    enum Group: String, CaseIterable {
        case wins = "Wins", rivals = "Rivals", team = "Your team"
    }

    var group: Group {
        switch self {
        case .firstWin, .onARoll, .veteran:             return .wins
        case .giantSlayer, .legendTamer, .rivalGuide:   return .rivals
        case .fullDeck, .everyHabitat, .seasoned, .groveLegend: return .team
        }
    }

    var title: String {
        switch self {
        case .firstWin:     return "First win"
        case .onARoll:      return "On a roll"
        case .veteran:      return "Veteran"
        case .giantSlayer:  return "Giant-slayer"
        case .legendTamer:  return "Legend tamer"
        case .rivalGuide:   return "Rival field guide"
        case .fullDeck:     return "Full deck"
        case .everyHabitat: return "Every habitat"
        case .seasoned:     return "Seasoned"
        case .groveLegend:  return "Grove legend"
        }
    }

    var how: String {
        switch self {
        case .firstWin:     return "Win your first match."
        case .onARoll:      return "Win 5 matches in a row."
        case .veteran:      return "Fight 50 matches."
        case .giantSlayer:  return "Beat a rival two levels above you."
        case .legendTamer:  return "Beat a legendary wild rival."
        case .rivalGuide:   return "Face 25 different wild animals."
        case .fullDeck:     return "Win with all six playstyles."
        case .everyHabitat: return "Win with a friend from all eight habitats."
        case .seasoned:     return "Raise a friend to Lv 10."
        case .groveLegend:  return "Raise a friend to Lv 30."
        }
    }

    var symbol: String {
        switch self {
        case .firstWin:     return "trophy.fill"
        case .onARoll:      return "flame.fill"
        case .veteran:      return "shield.lefthalf.filled"
        case .giantSlayer:  return "mountain.2.fill"
        case .legendTamer:  return "sparkles"
        case .rivalGuide:   return "book.closed.fill"
        case .fullDeck:     return "square.stack.3d.up.fill"
        case .everyHabitat: return "globe.americas.fill"
        case .seasoned:     return "bolt.fill"
        case .groveLegend:  return "crown.fill"
        }
    }

    /// How much it takes; 1 for one-off feats.
    var goal: Int {
        switch self {
        case .onARoll:      return 5
        case .veteran:      return 50
        case .rivalGuide:   return 25
        case .fullDeck:     return Archetype.allCases.count
        case .everyHabitat: return BattleType.allCases.count
        case .seasoned:     return 10
        case .groveLegend:  return BattleRoster.maxLevel
        default:            return 1
        }
    }

    /// Levels read better as "Lv 4 / 10".
    var isLevel: Bool { self == .seasoned || self == .groveLegend }
}

// MARK: - The ledger

/// Everything the trophies need, counted as matches land. Lives beside the
/// team and history (`BattleRoster`), and syncs with them.
struct TrophyLedger: Codable, Equatable {
    var earned: [String: Date] = [:]
    /// A few words on how each was earned ("vs Wild Badger", "Ember").
    var notes: [String: String] = [:]
    /// Earned but not yet seen on the Trophies tab.
    var unseen: Set<String> = []

    var matches = 0
    var wins = 0
    var streak = 0
    var bestStreak = 0
    var giantSlain = false
    var legendBeaten = false
    var rivals: Set<String> = []
    var archetypes: Set<String> = []
    var habitats: Set<String> = []
    var bestLevel = 1
    /// Old matches (from History) have been counted.
    var backfilled = false

    func isEarned(_ t: Trophy) -> Bool { earned[t.rawValue] != nil }

    /// Progress toward the goal, capped at it.
    func value(_ t: Trophy) -> Int {
        let v: Int
        switch t {
        case .firstWin:     v = wins
        case .onARoll:      v = bestStreak
        case .veteran:      v = matches
        case .giantSlayer:  v = giantSlain ? 1 : 0
        case .legendTamer:  v = legendBeaten ? 1 : 0
        case .rivalGuide:   v = rivals.count
        case .fullDeck:     v = archetypes.count
        case .everyHabitat: v = habitats.count
        case .seasoned, .groveLegend: v = bestLevel
        }
        return min(v, t.goal)
    }

    var earnedCount: Int { Trophy.allCases.filter(isEarned).count }

    /// The most recently earned trophy.
    var newest: Trophy? {
        Trophy.allCases.filter(isEarned).max { earned[$0.rawValue]! < earned[$1.rawValue]! }
    }

    /// Count one finished match.
    mutating func record(outcome: BattleRoster.MatchOutcome, fighterName: String,
                         archetype: Archetype, habitat: BattleType, level: Int,
                         oppName: String, oppLevel: Int, oppSpeciesID: String?,
                         newLevel: Int?, at date: Date) {
        matches += 1
        if let id = oppSpeciesID { rivals.insert(id) }
        if outcome == .win {
            wins += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            archetypes.insert(archetype.rawValue)
            habitats.insert(habitat.rawValue)
            if oppLevel >= level + 2, !giantSlain {
                giantSlain = true
                notes[Trophy.giantSlayer.rawValue] = "vs \(oppName)"
            }
            if !legendBeaten, let id = oppSpeciesID,
               CreatureCatalog.species(for: id)?.rarity == .legendary {
                legendBeaten = true
                notes[Trophy.legendTamer.rawValue] = "vs \(oppName)"
            }
        } else {
            streak = 0
        }
        if let newLevel, newLevel > bestLevel {
            bestLevel = newLevel
            if newLevel >= 10, notes[Trophy.seasoned.rawValue] == nil { notes[Trophy.seasoned.rawValue] = fighterName }
            if newLevel >= Trophy.groveLegend.goal { notes[Trophy.groveLegend.rawValue] = fighterName }
        }
        award(at: date)
    }

    /// Mark anything newly reached as earned.
    mutating func award(at date: Date) {
        for t in Trophy.allCases where !isEarned(t) && value(t) >= t.goal {
            earned[t.rawValue] = date
            unseen.insert(t.rawValue)
        }
    }
}

// MARK: - The Trophies tab

struct TrophiesTab: View {
    let ledger: TrophyLedger
    /// Called when the player leaves the tab: "New" tags clear.
    var onSeen: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TROPHIES")
                        .arenaDisplay(46)
                        .foregroundStyle(BattleTheme.ink)
                    Text("Bragging rights, never power. Earned by playing.")
                        .arenaFont(14, .semibold, .rounded)
                        .foregroundStyle(BattleTheme.muted)
                }
                .padding(.bottom, 2)

                TrophyShelf(ledger: ledger)

                ForEach(Trophy.Group.allCases, id: \.self) { group in
                    groupLabel(group.rawValue)
                    ForEach(Trophy.allCases.filter { $0.group == group }) { t in
                        TrophyRow(trophy: t, ledger: ledger)
                            .arenaEntrance((Trophy.allCases.firstIndex(of: t) ?? 0) + 1)
                    }
                }
            }
            .padding()
        }
        .onDisappear(perform: onSeen)
    }

    private func groupLabel(_ text: String) -> some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .arenaDisplay(15)
                .foregroundStyle(BattleTheme.muted)
            LinearGradient(colors: [BattleTheme.panelLine, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
        }
        .padding(.top, 12)
        .padding(.horizontal, 2)
    }
}

/// The count, a shelf with a slot for every trophy, and the latest one.
private struct TrophyShelf: View {
    let ledger: TrophyLedger

    var body: some View {
        let count = ledger.earnedCount
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(count)")
                    .arenaDisplay(54)
                    .foregroundStyle(count > 0 ? TrophyStyle.gold : BattleTheme.ink)
                    .monospacedDigit()
                Text("/ \(Trophy.allCases.count)")
                    .arenaDisplay(24)
                    .foregroundStyle(BattleTheme.muted)
                Spacer()
                Text("EARNED")
                    .arenaFont(10, .bold, .rounded)
                    .tracking(2)
                    .foregroundStyle(BattleTheme.muted)
            }

            // A slot for every trophy, earned ones lit.
            HStack(spacing: 0) {
                ForEach(Array(shelfOrder.enumerated()), id: \.offset) { i, t in
                    if i > 0 { Spacer(minLength: 2) }
                    TrophyBadge(trophy: t, state: t == nil ? .locked : .earned, size: 30, showsLock: false)
                }
            }

            Rectangle().fill(BattleTheme.panelLine).frame(height: 1)

            Group {
                if let t = ledger.newest {
                    (Text("LATEST  ").foregroundStyle(BattleTheme.muted)
                     + Text(t.title).foregroundStyle(BattleTheme.ink)
                     + Text(ledger.notes[t.rawValue].map { "  ·  \($0)" } ?? "").foregroundStyle(BattleTheme.muted))
                } else {
                    Text("Win a match to earn your first.").foregroundStyle(BattleTheme.muted)
                }
            }
            .arenaFont(13, .bold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(alignment: .topTrailing) {
                    // A low gold light behind the count once there's something to show.
                    if count > 0 {
                        RadialGradient(colors: [TrophyStyle.gold.opacity(0.16), .clear],
                                       center: .topTrailing, startRadius: 0, endRadius: 200)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(count > 0 ? TrophyStyle.gold.opacity(0.35) : BattleTheme.panelLine, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) of \(Trophy.allCases.count) trophies earned")
    }

    /// Earned trophies first (oldest to newest), then empty slots.
    private var shelfOrder: [Trophy?] {
        let won = Trophy.allCases.filter(ledger.isEarned)
            .sorted { ledger.earned[$0.rawValue]! < ledger.earned[$1.rawValue]! }
        return won.map { Optional($0) } + Array(repeating: nil, count: Trophy.allCases.count - won.count)
    }
}

private struct TrophyRow: View {
    let trophy: Trophy
    let ledger: TrophyLedger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheen: CGFloat = -1

    private var earned: Bool { ledger.isEarned(trophy) }
    private var isNew: Bool { ledger.unseen.contains(trophy.rawValue) }
    private var value: Int { ledger.value(trophy) }
    private var state: TrophyBadge.State {
        earned ? .earned : (value > 0 && trophy.goal > 1 ? .progress : .locked)
    }

    var body: some View {
        HStack(spacing: 14) {
            TrophyBadge(trophy: trophy, state: state, size: 54)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(trophy.title.uppercased())
                        .arenaDisplay(20)
                        .foregroundStyle(state == .locked ? BattleTheme.ink.opacity(0.7) : BattleTheme.ink)
                    if isNew {
                        Text("NEW")
                            .arenaDisplay(11)
                            .foregroundStyle(Color(hex: 0x1A1206))
                            .padding(.horizontal, 6).padding(.vertical, 2.5)
                            .background(Lean(amount: 4).fill(TrophyStyle.goldFill))
                    }
                }
                Text(trophy.how)
                    .arenaFont(13.5, .medium)
                    .foregroundStyle(BattleTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                detail.padding(.top, 5)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(background)
        .overlay {
            // A single bright sweep across a trophy you've just earned.
            if isNew && !reduceMotion {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.16), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.4)
                        .rotationEffect(.degrees(18))
                        .offset(x: sheen * g.size.width * 1.4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).delay(0.3)) { sheen = 1 }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder private var detail: some View {
        switch state {
        case .earned:
            let date = ledger.earned[trophy.rawValue]?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
            let note = ledger.notes[trophy.rawValue].map { " · \($0)" } ?? ""
            Text("EARNED \(date)\(note)".uppercased())
                .arenaFont(11, .heavy)
                .tracking(0.8)
                .foregroundStyle(TrophyStyle.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .progress:
            HStack(spacing: 10) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule()
                            .fill(LinearGradient(colors: [BattleTheme.sta, BattleTheme.leaf],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, g.size.width * Double(value) / Double(trophy.goal)))
                    }
                }
                .frame(height: 6)
                Text(trophy.isLevel ? "Lv \(value) / \(trophy.goal)" : "\(value) / \(trophy.goal)")
                    .arenaFont(12, .heavy)
                    .monospacedDigit()
                    .foregroundStyle(BattleTheme.sta)
            }
        case .locked:
            EmptyView()
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(BattleTheme.panelFill)
            .overlay {
                if earned {
                    LinearGradient(colors: [TrophyStyle.gold.opacity(0.10), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(earned ? TrophyStyle.gold.opacity(0.45) : BattleTheme.panelLine, lineWidth: 1))
    }

    private var accessibilityValue: String {
        switch state {
        case .earned:   return "Earned"
        case .progress: return "\(value) of \(trophy.goal)"
        case .locked:   return "Not yet earned"
        }
    }
}

/// A trophy's hexagonal badge: gold when earned, outlined while you're on
/// your way, dim before you've started.
struct TrophyBadge: View {
    enum State { case earned, progress, locked }

    let trophy: Trophy?
    let state: State
    var size: CGFloat
    var showsLock = true

    var body: some View {
        ZStack {
            switch state {
            case .earned:
                Hexagon().fill(TrophyStyle.goldFill)
                    .shadow(color: TrophyStyle.gold.opacity(0.35), radius: size * 0.2)
                Hexagon().inset(by: size * 0.07)
                    .stroke(Color(hex: 0x1A1206).opacity(0.25), lineWidth: 1)
            case .progress:
                Hexagon().fill(BattleTheme.sta.opacity(0.08))
                Hexagon().stroke(BattleTheme.sta.opacity(0.55), lineWidth: 1.5)
            case .locked:
                Hexagon().fill(Color.white.opacity(0.04))
                Hexagon().stroke(BattleTheme.panelLine, style: StrokeStyle(lineWidth: 1.2, dash: trophy == nil ? [3, 3] : []))
            }
            if let trophy {
                Image(systemName: trophy.symbol)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(state == .earned ? Color(hex: 0x2A1C05)
                                     : state == .progress ? BattleTheme.sta
                                     : BattleTheme.muted.opacity(0.45))
            }
        }
        .frame(width: size, height: size * 1.08)
        .overlay(alignment: .bottomTrailing) {
            if state == .locked && showsLock && trophy != nil {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BattleTheme.muted)
                    .padding(4)
                    .background(Circle().fill(BattleTheme.panel))
                    .offset(x: 3, y: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A pointy-top hexagon.
struct Hexagon: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.25))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.75))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.75))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.25))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Hexagon {
        var h = self; h.insetAmount += amount; return h
    }
}

enum TrophyStyle {
    static let gold = Color(hex: 0xF3D17A)
    static var goldFill: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFBE7A6), Color(hex: 0xE9B949), Color(hex: 0xB9862A)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
