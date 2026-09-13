import SwiftUI
import SwiftData

// MARK: - Battlegrounds home: Find a Match + your team

/// The Arena's home once a player is in. The primary action is **Find a Match**
/// (you don't battle a specific friend from here); below it, the team shows who's
/// ready and who's still napping.
struct BattlegroundsView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]
    @State private var showPromote = false

    private var roster: BattleRoster { .shared }
    private var team: [(friend: Catch, progress: BattleRoster.Progress)] {
        roster.teamCatches(from: catches)
    }
    private var promotable: [Catch] { catches.filter { !roster.teamContains($0) } }
    private func readyFighters() -> [Catch] { team.map(\.friend).filter { !roster.isResting($0) } }

    var body: some View {
        ZStack {
            BattleTheme.background.ignoresSafeArea()
            ScrollView {
                // A 1s tick so rest countdowns move and "Find a Match" re-enables
                // the moment a friend wakes up.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        findMatchButton
                        teamLabel
                        ForEach(0..<roster.maxSlots, id: \.self) { i in slot(i) }
                        footnote
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Battlegrounds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .onAppear { roster.prune(against: catches) }
        .sheet(isPresented: $showPromote) { PromotePickerSheet(candidates: promotable) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The Arena")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Text("Find a match, send in a ready friend, and raise them fight by fight.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
    }

    @ViewBuilder private var findMatchButton: some View {
        let ready = readyFighters()
        if ready.isEmpty {
            VStack(spacing: 4) {
                Text("Find a Match")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
                Text(team.isEmpty ? "Send a friend to the Arena first" : "Everyone's resting — check back soon")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
            )
        } else {
            NavigationLink {
                MatchmakingView(fighters: ready)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                    Text("Find a Match")
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x07130B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(LinearGradient(colors: [BattleTheme.leaf, BattleTheme.leafDeep], startPoint: .top, endPoint: .bottom)))
                .shadow(color: BattleTheme.leaf.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var teamLabel: some View {
        Text("YOUR TEAM")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1)
            .foregroundStyle(BattleTheme.muted)
            .padding(.top, 4)
    }

    @ViewBuilder private func slot(_ i: Int) -> some View {
        if i < team.count {
            TeamStatusCard(friend: team[i].friend, progress: team[i].progress,
                           resting: roster.isResting(team[i].friend),
                           remaining: roster.restRemaining(team[i].friend))
        } else {
            EmptySlotCard { showPromote = true }
        }
    }

    private var footnote: some View {
        Text("Each match, one ready friend fights — then naps to recover. A benched friend keeps every level they earned.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(BattleTheme.muted.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
    }
}

// MARK: - Team status card (ready / resting)

private struct TeamStatusCard: View {
    let friend: Catch
    let progress: BattleRoster.Progress
    let resting: Bool
    let remaining: TimeInterval
    private var type: BattleType { BattleType(habitat: friend.effectiveZone) }
    private var archetype: Archetype { .derived(fromSpeciesID: friend.speciesID) }

    var body: some View {
        HStack(spacing: 14) {
            PortraitCircle(photoData: friend.photoData, type: type,
                           monogram: String(friend.displayName.prefix(1)), size: 56)
                .opacity(resting ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(friend.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink).lineLimit(1)
                    TypeChip(type: type)
                }
                Text("\(archetype.rawValue.capitalized) · Lv \(progress.level)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
                xpBar
            }
            Spacer(minLength: 6)
            statusPill
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle().fill(resting ? BattleTheme.gold : BattleTheme.leaf).frame(width: 7, height: 7)
            Text(resting ? "Resting \(mmss(remaining))" : "Ready")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(resting ? BattleTheme.gold : BattleTheme.leaf)
        }
    }

    private var xpBar: some View {
        let need = BattleRoster.xpNeeded(for: progress.level)
        let frac = progress.level >= 30 ? 1 : Double(progress.xp) / Double(max(1, need))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(BattleTheme.gold.opacity(0.85))
                    .frame(width: max(3, geo.size.width * min(1, frac)))
            }
        }
        .frame(height: 5)
        .padding(.top, 2)
    }
}

// MARK: - Empty slot

private struct EmptySlotCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(hex: 0x1C2C23))
                        .overlay(Circle().strokeBorder(BattleTheme.panelLine, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])))
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(BattleTheme.muted)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Open slot").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(BattleTheme.ink)
                    Text("Send a friend to the Arena").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(BattleTheme.muted)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.02))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(BattleTheme.panelLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Matchmaking: choose a ready fighter vs a hidden rival

struct MatchmakingView: View {
    let fighters: [Catch]

    @State private var selected: Catch
    @State private var seed: UInt64
    @State private var opponent: Contender
    @State private var go = false
    @State private var result: BattleResult?
    @State private var levelMsg: String?

    private var roster: BattleRoster { .shared }
    private var level: Int { roster.progress(for: selected)?.level ?? 1 }
    private var fighterContender: Contender { .from(selected) }

    init(fighters: [Catch]) {
        self.fighters = fighters
        _selected = State(initialValue: fighters[0])
        let s = UInt64.random(in: 0 ..< UInt64.max)
        _seed = State(initialValue: s)
        _opponent = State(initialValue: .wildRival(seed: s))   // drawn, but kept hidden
    }

    var body: some View {
        ZStack {
            BattleTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if fighters.count > 1 { fighterPicker }

                    labeled("YOUR FIGHTER") {
                        BattleCardView(card: fighterContender.card(level: level), photoData: selected.photoData)
                    }
                    if let levelMsg {
                        Text(levelMsg)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: 0x07130B))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(BattleTheme.gold))
                    }

                    Text("VS").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(BattleTheme.gold)

                    labeled("YOUR OPPONENT") { HiddenOpponentCard() }

                    fightButton
                }
                .padding()
            }
        }
        .navigationTitle("Find a Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .navigationDestination(isPresented: $go) {
            if let result {
                ArenaReplayView(result: result, portraits: [selected.photoData, opponent.photoData])
            }
        }
    }

    private var fighterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHOOSE WHO FIGHTS")
                .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1)
                .foregroundStyle(BattleTheme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(fighters, id: \.persistentModelID) { f in
                        let isSel = f.persistentModelID == selected.persistentModelID
                        Button { withAnimation(.easeInOut(duration: 0.15)) { selected = f } } label: {
                            VStack(spacing: 5) {
                                PortraitCircle(photoData: f.photoData,
                                               type: BattleType(habitat: f.effectiveZone),
                                               monogram: String(f.displayName.prefix(1)), size: 56)
                                    .overlay(Circle().stroke(BattleTheme.gold, lineWidth: isSel ? 3 : 0))
                                Text(f.displayName)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSel ? BattleTheme.ink : BattleTheme.muted)
                                    .lineLimit(1)
                            }
                            .frame(width: 68)
                            .opacity(isSel ? 1 : 0.7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1).foregroundStyle(BattleTheme.muted)
            content()
        }
    }

    private var fightButton: some View {
        Button {
            let r = simulate(fighterContender.card(level: level), .defaultPlan(for: fighterContender.archetype),
                             vs: opponent.card(level: level), .defaultPlan(for: opponent.archetype),
                             seed: seed)
            let won: Bool = { if case .win(let n) = r.outcome { return n == selected.displayName } else { return false } }()
            let gained = roster.award(to: selected, won: won)
            // Rest is based on how worn out the fighter finished.
            let maxHP = Double(max(1, r.fighters[0].maxHP))
            let endHP = Double(max(0, r.events.last?.hpAfter.first ?? r.fighters[0].maxHP))
            roster.beginRest(selected, hpFraction: endHP / maxHP)
            levelMsg = gained > 0 ? "Leveled up! Now Lv \(level)" : nil
            result = r
            go = true
        } label: {
            Text("Fight!")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x07130B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(LinearGradient(colors: [BattleTheme.leaf, BattleTheme.leafDeep], startPoint: .top, endPoint: .bottom)))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

// MARK: - Hidden opponent (revealed only when the battle begins)

private struct HiddenOpponentCard: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: 0x1C2C23))
                    .overlay(Circle().stroke(BattleTheme.panelLine, lineWidth: 1))
                Text("?")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
                    .opacity(pulse ? 0.5 : 1)
            }
            .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text("A wild challenger")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.ink)
                Text("Revealed the moment the match begins.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(BattleTheme.panelLine, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
        )
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Promote picker

private struct PromotePickerSheet: View {
    let candidates: [Catch]
    @Environment(\.dismiss) private var dismiss
    private var roster: BattleRoster { .shared }

    var body: some View {
        NavigationStack {
            ZStack {
                BattleTheme.background.ignoresSafeArea()
                if candidates.isEmpty {
                    VStack(spacing: 8) {
                        Text("🌿").font(.system(size: 36))
                        Text("Every friend is already on your team,\nor you haven't met any yet.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(BattleTheme.muted)
                    }.padding(40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(candidates) { c in
                                Button {
                                    if roster.promote(c) { dismiss() }
                                } label: {
                                    PromoteRow(friend: c, benched: roster.hasEverPromoted(c))
                                }
                                .buttonStyle(.plain)
                                .disabled(!roster.hasFreeSlot)
                                .opacity(roster.hasFreeSlot ? 1 : 0.5)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Send to the Arena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct PromoteRow: View {
    let friend: Catch
    let benched: Bool
    private var type: BattleType { BattleType(habitat: friend.effectiveZone) }
    private var archetype: Archetype { .derived(fromSpeciesID: friend.speciesID) }

    var body: some View {
        HStack(spacing: 12) {
            PortraitCircle(photoData: friend.photoData, type: type,
                           monogram: String(friend.displayName.prefix(1)), size: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.ink).lineLimit(1)
                HStack(spacing: 6) {
                    TypeChip(type: type)
                    Text(archetype.rawValue.capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                    if benched, let p = BattleRoster.shared.progress(for: friend) {
                        Text("· Lv \(p.level) benched")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(BattleTheme.gold.opacity(0.85))
                    }
                }
            }
            Spacer()
            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(BattleTheme.leaf)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }
}

// MARK: - Battle card (portrait + stats + moves)

struct BattleCardView: View {
    let card: BattleCard
    let photoData: Data?
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                PortraitCircle(photoData: photoData, type: card.type,
                               monogram: String(card.name.prefix(1)), size: compact ? 56 : 76)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(card.name)
                            .font(.system(size: compact ? 17 : 20, weight: .bold, design: .rounded))
                            .foregroundStyle(BattleTheme.ink).lineLimit(1)
                        TypeChip(type: card.type)
                    }
                    Text("\(card.archetype.rawValue.capitalized) · Lv \(card.level)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                }
                Spacer()
            }
            statGrid
            if !compact { movesRow }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    private var statGrid: some View {
        let ref = Double(totalBudget(atLevel: card.level)) * 0.34
        let rows: [(String, Int, Color)] = [
            ("HP",  card.stats.hp,  BattleTheme.leaf),
            ("ATK", card.stats.atk, Color(hex: 0xE8654F)),
            ("DEF", card.stats.def, Color(hex: 0x5F9AD6)),
            ("SPD", card.stats.spd, Color(hex: 0xF0C24B)),
            ("STA", card.stats.sta, Color(hex: 0x5FC7D6)),
        ]
        return VStack(spacing: 6) {
            ForEach(rows, id: \.0) { row in
                HStack(spacing: 10) {
                    Text(row.0)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                        .frame(width: 30, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.07))
                            Capsule().fill(row.2)
                                .frame(width: max(4, geo.size.width * min(1, Double(row.1) / ref)))
                        }
                    }
                    .frame(height: 7)
                    Text("\(row.1)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink)
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    private var movesRow: some View {
        HStack(spacing: 8) {
            moveChip(card.strike)
            moveChip(card.utility)
            moveChip(card.special, special: true)
        }
    }

    private func moveChip(_ move: Move, special: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(move.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(special ? BattleTheme.gold : BattleTheme.ink)
                .lineLimit(1)
            Text(move.power > 0 ? "⚔ \(move.power) · ⚡\(move.stamina)" : "⚡\(move.stamina)")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(hex: 0x0E1712))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(special ? BattleTheme.gold.opacity(0.5) : BattleTheme.panelLine, lineWidth: 1))
        )
    }
}

// MARK: - Shared bits

struct TypeChip: View {
    let type: BattleType
    var body: some View {
        Text(type.rawValue.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(Color(hex: 0x0C130F))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(type.color))
    }
}

/// A round portrait — the friend's real photo when present, else a type-tinted monogram.
struct PortraitCircle: View {
    let photoData: Data?
    let type: BattleType
    let monogram: String
    var size: CGFloat = 68

    var body: some View {
        Group {
            if let data = photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(type.color, lineWidth: 3))
            } else {
                Circle()
                    .fill(RadialGradient(colors: [type.color, type.color.darkened(0.45)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: size))
                    .overlay(Text(monogram)
                        .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x0C130F).opacity(0.85)))
                    .frame(width: size, height: size)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }
}

/// m:ss for a rest countdown.
func mmss(_ t: TimeInterval) -> String {
    let s = max(0, Int(t.rounded(.up)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

#Preview {
    NavigationStack { BattlegroundsView() }
        .modelContainer(for: Catch.self, inMemory: true)
}
