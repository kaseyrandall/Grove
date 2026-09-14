import SwiftUI
import SwiftData

// MARK: - Per-slot state on the home

private enum SlotState {
    case ready
    case away(TimeInterval)
    case resultReady(won: Bool)
    case resting(TimeInterval)
}

// MARK: - Battlegrounds home: Find a Match + your team

/// The Arena's home. You **send a friend off** to a match from here; they're
/// away a short while, then come back with a result and a nap. The team shows
/// each friend's state: Ready · In a match · Result ready · Resting.
struct BattlegroundsView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]
    @State private var tab = 0
    @State private var showPromote = false

    private var roster: BattleRoster { .shared }
    private var team: [(friend: Catch, progress: BattleRoster.Progress)] {
        roster.teamCatches(from: catches)
    }
    private var promotable: [Catch] { catches.filter { !roster.teamContains($0) } }
    private func readyFighters() -> [Catch] { team.map(\.friend).filter { roster.canSend($0) } }

    var body: some View {
        ZStack {
            BattleTheme.background.ignoresSafeArea()
            Group {
                switch tab {
                case 1: historyTab
                case 2: trophiesTab
                default: arenaTab
                }
            }
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .onAppear { roster.prune(against: catches); roster.settleDueMatches(from: catches) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            roster.settleDueMatches(from: catches)
        }
        .sheet(isPresented: $showPromote) { PromotePickerSheet(candidates: promotable) }
    }

    // MARK: Arena tab

    private var arenaTab: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("The Arena",
                                      "Send a friend off to a match. They're away a bit, then come back with a result — and a nap.")
                        squadStrip
                        teamLabel
                        ForEach(0..<roster.maxSlots, id: \.self) { i in slot(i) }
                    }
                    .padding()
                }
                findMatchButton
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
        .background(alignment: .top) { arenaBackdrop }
    }

    /// Torch-lit sense of place: a warm top glow with slow-drifting embers,
    /// behind the whole Arena tab.
    private var arenaBackdrop: some View {
        ZStack(alignment: .top) {
            RadialGradient(colors: [BattleTheme.gold.opacity(0.12), .clear],
                           center: .top, startRadius: 6, endRadius: 300)
            EmberField()
                .mask(LinearGradient(colors: [.black, .black, .clear],
                                     startPoint: .top, endPoint: .bottom))
        }
        .frame(height: 230)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: Squad strip (power · streak · record)

    private var squadStrip: some View {
        let rec = roster.record
        let streak = roster.winStreak
        return HStack(spacing: 10) {
            statTile(icon: "bolt.fill", value: "\(squadPower)", label: "Squad power", tint: BattleTheme.leaf)
            statTile(icon: streak > 0 ? "flame.fill" : "flame",
                     value: "\(streak)", label: "Win streak",
                     tint: streak > 0 ? Color(hex: 0xE8743B) : BattleTheme.muted)
            statTile(icon: "rosette", value: "\(rec.wins)–\(rec.losses)", label: "Record", tint: BattleTheme.gold)
        }
    }

    private var squadPower: Int {
        team.reduce(0) { $0 + totalBudget(atLevel: $1.progress.level) }
    }

    private func statTile(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.ink).monospacedDigit()
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.5)
                .foregroundStyle(BattleTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    /// A page-level header shown inside the content of each tab (so the nav bar
    /// doesn't have to repeat the title).
    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
    }

    @ViewBuilder private var findMatchButton: some View {
        let ready = readyFighters()
        if ready.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "bolt.slash.fill").font(.system(size: 14, weight: .bold))
                Text(team.isEmpty ? "Send a friend to the Arena to begin" : "Everyone's away or resting")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(BattleTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1)))
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
                .shadow(color: BattleTheme.leaf.opacity(0.35), radius: 14, y: 6)
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
            let f = team[i].friend
            let p = team[i].progress
            if roster.hasUnwatchedResult(f) {
                NavigationLink { resultReplay(for: f) } label: {
                    TeamStatusCard(friend: f, progress: p, state: .resultReady(won: roster.pendingWon(f) ?? false))
                }
                .buttonStyle(.plain)
            } else if roster.isAway(f) {
                TeamStatusCard(friend: f, progress: p, state: .away(roster.awayRemaining(f)),
                               devResolve: { roster.devResolveNow(f) })
            } else if roster.isResting(f) {
                TeamStatusCard(friend: f, progress: p, state: .resting(roster.restRemaining(f)))
            } else {
                TeamStatusCard(friend: f, progress: p, state: .ready)
            }
        } else {
            EmptySlotCard { showPromote = true }
        }
    }

    @ViewBuilder private func resultReplay(for c: Catch) -> some View {
        if let r = roster.replayResult(for: c) {
            ArenaReplayView(result: r, portraits: [c.photoData, nil])
                .onAppear { roster.markWatched(c) }
        }
    }

    // MARK: History tab

    private var historyTab: some View {
        let records = roster.matchHistory()
        return ScrollView {
            if records.isEmpty {
                VStack(spacing: 8) {
                    Text("🗒️").font(.system(size: 36))
                    Text("No matches yet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink)
                    Text("Send a friend off from the Arena —\ntheir matches show up here to rewatch.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80).padding(.horizontal, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    sectionHeader("History", "Every match your team has fought. Tap to rewatch.")
                        .padding(.bottom, 2)
                    ForEach(records) { rec in
                        NavigationLink {
                            ArenaReplayView(result: rec.replay(),
                                            portraits: [roster.friendPhoto(for: rec, in: catches), nil])
                        } label: {
                            HistoryRow(record: rec, photo: roster.friendPhoto(for: rec, in: catches))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: Trophies tab (placeholder until achievements land)

    private var trophiesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Trophies", "Prestige, never power — earned by playing. Coming soon.")
                    .padding(.bottom, 2)
                lockedTrophy("🥇", "First blood", "Win your first match.")
                lockedTrophy("🔥", "On a roll", "Win five matches in a row.")
                lockedTrophy("🎭", "Full deck", "Win with every archetype.")
                lockedTrophy("🧗", "Giant-slayer", "Beat a higher-level rival.")
                lockedTrophy("🌳", "Seasoned", "Reach Trainer Lv 10.")
            }
            .padding()
        }
    }

    private func lockedTrophy(_ emoji: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(Color.white.opacity(0.05)).frame(width: 48, height: 48)
                    .overlay(Text(emoji).font(.system(size: 22)).grayscale(1).opacity(0.55))
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BattleTheme.muted)
                    .padding(4)
                    .background(Circle().fill(BattleTheme.panel))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(BattleTheme.ink.opacity(0.85))
                Text(desc).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(BattleTheme.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(BattleTheme.panelFill)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1)))
    }

    // MARK: Bottom tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(0, "bolt.shield.fill", "Arena")
            tabItem(1, "clock.arrow.circlepath", "History")
            tabItem(2, "trophy.fill", "Trophies")
        }
        .padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 8)
        .background(
            BattleTheme.panel
                .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(_ i: Int, _ icon: String, _ label: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { tab = i } } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tab == i ? BattleTheme.leaf : BattleTheme.muted)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryRow: View {
    let record: BattleRoster.MatchRecord
    let photo: Data?

    var body: some View {
        HStack(spacing: 12) {
            PortraitCircle(photoData: photo, type: record.fighterType,
                           monogram: String(record.fighterName.prefix(1)), size: 46)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.fighterName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink).lineLimit(1)
                    Text("vs \(record.oppName)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(record.won ? "WON" : "LOST")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(record.won ? BattleTheme.leaf : Color(hex: 0xE8654F))
                    Text("· \(record.date, format: .relative(presentation: .named))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                Text("Replay").font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(BattleTheme.gold)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(BattleTheme.panelFill)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1)))
    }
}

// MARK: - Team status card

private struct TeamStatusCard: View {
    let friend: Catch
    let progress: BattleRoster.Progress
    let state: SlotState
    var devResolve: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var type: BattleType { BattleType(habitat: friend.effectiveZone) }
    private var archetype: Archetype { .derived(fromSpeciesID: friend.speciesID) }
    private var dim: Bool {
        switch state { case .away, .resting: return true; default: return false }
    }

    var body: some View {
        HStack(spacing: 14) {
            PortraitCircle(photoData: friend.photoData, type: type,
                           monogram: String(friend.displayName.prefix(1)), size: 56)
                .overlay(alignment: .bottomTrailing) { levelShield }
                .opacity(dim ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(friend.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink).lineLimit(1)
                    TypeChip(type: type)
                }
                Text(archetype.rawValue.capitalized)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
                xpBar
            }
            Spacer(minLength: 6)
            statusPill
        }
        .padding(14)
        .background(cardBackground)
        .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius, y: 3)
        .onAppear {
            guard isResultReady, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// A gentle breathing aura on the result-ready card; a steady, softer one
    /// otherwise; none while away or resting.
    private var glowOpacity: Double {
        if dim { return 0 }
        if isResultReady { return pulse ? 0.42 : 0.16 }
        return 0.16
    }
    private var glowRadius: CGFloat {
        if isResultReady { return pulse ? 15 : 9 }
        return 9
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(BattleTheme.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderStyle, lineWidth: 1.2)
            )
    }

    /// A shield insignia on the portrait carrying the fighter's level.
    private var levelShield: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .font(.system(size: 21))
                .foregroundStyle(LinearGradient(colors: [type.color, type.color.darkened(0.32)],
                                                startPoint: .top, endPoint: .bottom))
                .overlay(Image(systemName: "shield")
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(.white.opacity(0.35)))
            Text("\(progress.level)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: -0.5)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
        .offset(x: 5, y: 5)
    }

    private var isResultReady: Bool {
        if case .resultReady = state { return true }; return false
    }

    /// Colored aura behind the card — gold when a result waits, else the
    /// fighter's own type color.
    private var glowColor: Color { isResultReady ? BattleTheme.gold : type.color }

    private var borderStyle: AnyShapeStyle {
        if isResultReady {
            return AnyShapeStyle(BattleTheme.gold.opacity(0.65))
        }
        return AnyShapeStyle(LinearGradient(colors: [type.color.opacity(0.55), BattleTheme.panelLine],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    @ViewBuilder private var statusPill: some View {
        switch state {
        case .ready:
            pill(text: "Ready", color: BattleTheme.leaf, dot: true)
        case .away(let t):
            HStack(spacing: 8) {
                pill(text: "In a match · \(mmss(t))", color: Color(hex: 0x5FC7D6), dot: true)
                #if DEBUG
                if let devResolve {
                    Button(action: devResolve) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BattleTheme.muted)
                            .padding(6)
                            .background(Circle().stroke(BattleTheme.panelLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
        case .resultReady:
            HStack(spacing: 5) {
                Text("Result ready")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0x07130B))
                Image(systemName: "play.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0x07130B))
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(BattleTheme.gold))
        case .resting(let t):
            pill(text: "Resting \(mmss(t))", color: BattleTheme.gold, dot: true)
        }
    }

    private func pill(text: String, color: Color, dot: Bool) -> some View {
        HStack(spacing: 5) {
            if dot { PulseDot(color: color) }
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
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

// MARK: - Matchmaking: choose a ready fighter, send them off vs a hidden rival

struct MatchmakingView: View {
    let fighters: [Catch]

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Catch
    @State private var seed: UInt64
    @State private var opponent: Contender
    @State private var showPlan = false
    @State private var dispatching = false

    private var roster: BattleRoster { .shared }
    private var level: Int { roster.progress(for: selected)?.level ?? 1 }
    private var fighterContender: Contender { .from(selected) }

    init(fighters: [Catch]) {
        self.fighters = fighters
        _selected = State(initialValue: fighters[0])
        let s = UInt64.random(in: 0 ..< UInt64.max)
        _seed = State(initialValue: s)
        _opponent = State(initialValue: .wildRival(seed: s))
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
                    planButton
                    Text("VS").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(BattleTheme.gold)
                    labeled("YOUR OPPONENT") { HiddenOpponentCard() }
                    sendButton
                }
                .padding()
            }
        }
        .overlay { if dispatching { DispatchOverlay(fighter: selected) } }
        .navigationTitle("Find a Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .sheet(isPresented: $showPlan) {
            BattlePlanEditorView(fighter: selected, archetype: fighterContender.archetype)
        }
    }

    private var planCount: Int {
        roster.storedPlan(for: selected, archetype: fighterContender.archetype).rules.count
    }

    private var planButton: some View {
        Button { showPlan = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BattleTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battle Plan")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink)
                    Text("\(planCount) rule\(planCount == 1 ? "" : "s") · tap to coach")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BattleTheme.muted.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BattleTheme.panelFill)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
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

    private var sendButton: some View {
        Button {
            let plan = roster.storedPlan(for: selected, archetype: fighterContender.archetype)
            let r = simulate(fighterContender.card(level: level), plan.battlePlan,
                             vs: opponent.card(level: level), .defaultPlan(for: opponent.archetype),
                             seed: seed)
            roster.send(selected, opponent: opponent, level: level, plan: plan, seed: seed, result: r)
            withAnimation(.easeInOut(duration: 0.25)) { dispatching = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                dismiss()
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "paperplane.fill")
                Text("Send to battle")
            }
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

// MARK: - Hidden opponent (revealed only when you watch the result)

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
                Text("Revealed when the match comes back.")
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

// MARK: - Dispatch confirmation ("off they go")

private struct DispatchOverlay: View {
    let fighter: Catch
    @State private var bob = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 20) {
                PortraitCircle(photoData: fighter.photoData,
                               type: BattleType(habitat: fighter.effectiveZone),
                               monogram: String(fighter.displayName.prefix(1)), size: 116)
                    .offset(y: bob ? -10 : 6)
                Text("\(fighter.displayName) is off to the Arena!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.ink)
                    .multilineTextAlignment(.center)
                Text("We'll ping you when the match is done.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
            }
            .padding(.horizontal, 30)
        }
        .transition(.opacity)
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true } }
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

/// m:ss for a countdown.
func mmss(_ t: TimeInterval) -> String {
    let s = max(0, Int(t.rounded(.up)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - Arena flare (embers · pulse · shimmer)

/// A "live" status dot: a solid core with a soft radar ping expanding out.
private struct PulseDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle().stroke(color, lineWidth: 1.5).frame(width: 7, height: 7)
                    .scaleEffect(animate ? 2.4 : 1)
                    .opacity(animate ? 0 : 0.7)
            }
            Circle().fill(color).frame(width: 7, height: 7)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { animate = true }
        }
    }
}

/// A gold sheen sweeping across a card — used to draw the eye to a ready result.
/// A few soft, warm motes drifting slowly upward behind the Arena header —
/// firelight, not confetti. Cheap Canvas, deterministic layout (a GLSL-style
/// hash) so it never jumps on redraw, blurred so the dots read as glow.
private struct EmberField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let count = 9
    private static let warm: [Color] = [Color(hex: 0xF3D17A), Color(hex: 0xE8A24B)]

    private func hash(_ i: Int, _ salt: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return x - floor(x)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 3600 : 1.0 / 30.0)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<count {
                    let baseX = 0.08 + hash(i, 1) * 0.84
                    let speed = 0.018 + hash(i, 2) * 0.03        // very slow rise
                    let phase = hash(i, 3)
                    let radius = 3 + hash(i, 4) * 3
                    let swayAmp = 4 + hash(i, 5) * 8
                    let color = Self.warm[i % Self.warm.count]

                    let t = reduceMotion ? phase : (now * speed + phase).truncatingRemainder(dividingBy: 1)
                    let y = size.height * (1 - t)
                    let sway = reduceMotion ? 0 : sin((now * speed + phase) * .pi * 2) * swayAmp
                    let x = baseX * size.width + sway
                    let fade = reduceMotion ? 0.14 : sin(t * .pi) * 0.30
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(fade)))
                }
            }
            .blur(radius: 2.5)
        }
    }
}

#Preview {
    NavigationStack { BattlegroundsView() }
        .modelContainer(for: Catch.self, inMemory: true)
}
