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
    @State private var open: Set<Trophy.Group> = []

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

                // One card per group; tap to open the full list. A group
                // with a new trophy starts open.
                ForEach(Array(Trophy.Group.allCases.enumerated()), id: \.element) { n, group in
                    TrophyGroupCard(group: group, ledger: ledger,
                                    isOpen: Binding(get: { open.contains(group) },
                                                    set: { on in
                                                        if on { open.insert(group) } else { open.remove(group) }
                                                    }))
                        .arenaEntrance(n + 1)
                }
            }
            .padding()
        }
        .onAppear {
            open = Set(Trophy.Group.allCases.filter { g in
                Trophy.allCases.contains { $0.group == g && ledger.unseen.contains($0.rawValue) }
            })
        }
        .onDisappear(perform: onSeen)
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

extension Trophy.Group {
    /// Each group's edge color.
    var accent: Color {
        switch self {
        case .wins:   return TrophyStyle.gold
        case .rivals: return Color(hex: 0xFF8A4B)
        case .team:   return BattleTheme.leaf
        }
    }
}

/// A group as one card. Closed: its badges, the count and the closest
/// trophy to earn next. Open: every trophy in the group.
private struct TrophyGroupCard: View {
    let group: Trophy.Group
    let ledger: TrophyLedger
    @Binding var isOpen: Bool

    private var trophies: [Trophy] { Trophy.allCases.filter { $0.group == group } }
    private var earned: Int { trophies.filter(ledger.isEarned).count }
    /// The unearned trophy you're furthest along on.
    private var next: Trophy? {
        trophies.filter { !ledger.isEarned($0) && $0.goal > 1 && ledger.value($0) > 0 }
            .max { Double(ledger.value($0)) / Double($0.goal) < Double(ledger.value($1)) / Double($1.goal) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(group.rawValue.uppercased())
                        .arenaDisplay(24)
                        .foregroundStyle(BattleTheme.ink)
                    Spacer()
                    Text("\(earned)/\(trophies.count)")
                        .arenaDisplay(22)
                        .foregroundStyle(TrophyStyle.gold)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BattleTheme.muted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.rawValue), \(earned) of \(trophies.count) earned")
            .accessibilityHint(isOpen ? "Hides the list" : "Shows every trophy")

            if isOpen {
                VStack(spacing: 0) {
                    ForEach(Array(trophies.enumerated()), id: \.element) { n, t in
                        TrophyLine(trophy: t, ledger: ledger)
                            .arenaEntrance(n)
                    }
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: 10) {
                    ForEach(trophies) { t in
                        TrophyBadge(trophy: t, state: badgeState(t), size: 40)
                            .overlay(alignment: .topTrailing) {
                                if ledger.unseen.contains(t.rawValue) {
                                    Circle().fill(TrophyStyle.gold).frame(width: 9, height: 9).offset(x: 2, y: -2)
                                }
                            }
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
                if let t = next { nextLine(t).padding(.top, 12).transition(.opacity) }
            }
        }
        .padding(.leading, 16).padding(.trailing, 24).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Slant(trail: 12).fill(BattleTheme.panelFill))
        .overlay(alignment: .leading) { Rectangle().fill(group.accent).frame(width: 3) }
        .clipped()
    }

    private func badgeState(_ t: Trophy) -> TrophyBadge.State {
        ledger.isEarned(t) ? .earned : (ledger.value(t) > 0 && t.goal > 1 ? .progress : .locked)
    }

    private func nextLine(_ t: Trophy) -> some View {
        let v = ledger.value(t)
        return HStack(spacing: 10) {
            (Text("NEXT: ").foregroundStyle(BattleTheme.muted) + Text(t.title.uppercased()).foregroundStyle(BattleTheme.ink))
                .arenaFont(12, .bold, .rounded)
                .lineLimit(1)
                .fixedSize()
            LeanBar(fraction: Double(v) / Double(t.goal),
                    color: BattleTheme.sta, height: 5)
            Text(t.isLevel ? "Lv \(v)/\(t.goal)" : "\(v)/\(t.goal)")
                .arenaFont(12, .heavy, .rounded)
                .monospacedDigit()
                .foregroundStyle(BattleTheme.sta)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One trophy inside an open group.
private struct TrophyLine: View {
    let trophy: Trophy
    let ledger: TrophyLedger

    private var earned: Bool { ledger.isEarned(trophy) }
    private var value: Int { ledger.value(trophy) }
    private var state: TrophyBadge.State {
        earned ? .earned : (value > 0 && trophy.goal > 1 ? .progress : .locked)
    }

    var body: some View {
        HStack(spacing: 12) {
            TrophyBadge(trophy: trophy, state: state, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(trophy.title.uppercased())
                        .arenaDisplay(18)
                        .foregroundStyle(state == .locked ? BattleTheme.ink.opacity(0.7) : BattleTheme.ink)
                    if ledger.unseen.contains(trophy.rawValue) {
                        Text("NEW")
                            .arenaDisplay(11)
                            .foregroundStyle(Color(hex: 0x1A1206))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Lean(amount: 4).fill(TrophyStyle.goldFill))
                    }
                }
                Text(detail)
                    .arenaFont(12, .semibold, .rounded)
                    .foregroundStyle(BattleTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Text(status)
                .arenaFont(11, .heavy, .rounded)
                .tracking(0.6)
                .monospacedDigit()
                .foregroundStyle(earned ? TrophyStyle.gold : (state == .progress ? BattleTheme.sta : BattleTheme.muted))
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    /// How to earn it, or for earned ones, when and how it was earned.
    private var detail: String {
        guard earned else { return trophy.how }
        let date = ledger.earned[trophy.rawValue]?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
        let note = ledger.notes[trophy.rawValue].map { " · \($0)" } ?? ""
        return "Earned \(date)\(note)"
    }

    private var status: String {
        switch state {
        case .earned:   return "EARNED"
        case .progress: return trophy.isLevel ? "LV \(value)/\(trophy.goal)" : "\(value)/\(trophy.goal)"
        case .locked:   return "LOCKED"
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
