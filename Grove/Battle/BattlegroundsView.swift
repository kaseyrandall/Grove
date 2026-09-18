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

    var body: some View {
        ZStack(alignment: .top) {
            BattleTheme.background.ignoresSafeArea()
            if tab == 0 {
                arenaBackdrop.ignoresSafeArea(edges: .top)
            }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("The Arena",
                                  "Tap a friend to see their card, then send them off to a match. They're away a bit, then come back with a result — and a nap.")
                    squadStrip
                    teamLabel
                    ForEach(0..<roster.maxSlots, id: \.self) { i in slot(i) }
                }
                .padding()
            }
        }
    }

    /// Torch-lit sense of place: a warm glow with slow-drifting embers, running
    /// continuously from behind the nav bar down into the header (no seam).
    private var arenaBackdrop: some View {
        ZStack(alignment: .top) {
            RadialGradient(colors: [BattleTheme.gold.opacity(0.13), .clear],
                           center: .top, startRadius: 8, endRadius: 340)
            EmberField()
                .mask(LinearGradient(colors: [.black, .black, .clear],
                                     startPoint: .top, endPoint: .bottom))
        }
        .frame(height: 320)
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
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.ink).monospacedDigit()
            }
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .heavy, design: .rounded)).tracking(0.5)
                .foregroundStyle(BattleTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    /// A page-level header shown inside the content of each tab (so the nav bar
    /// doesn't have to repeat the title).
    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
    }

    private var teamLabel: some View {
        Text("YOUR TEAM")
            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
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
                #if DEBUG
                TeamStatusCard(friend: f, progress: p, state: .away(roster.awayRemaining(f)),
                               devResolve: { roster.devResolveNow(f) })
                #else
                TeamStatusCard(friend: f, progress: p, state: .away(roster.awayRemaining(f)))
                #endif
            } else if roster.isResting(f) {
                TeamStatusCard(friend: f, progress: p, state: .resting(roster.restRemaining(f)))
            } else {
                NavigationLink { FighterCardView(friend: f) } label: {
                    TeamStatusCard(friend: f, progress: p, state: .ready)
                }
                .buttonStyle(.plain)
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
                Circle().fill(Color.white.opacity(0.05)).frame(width: 52, height: 52)
                    .overlay(Text(emoji).font(.system(size: 24)).grayscale(1).opacity(0.55))
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BattleTheme.muted)
                    .padding(4)
                    .background(Circle().fill(BattleTheme.panel))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(BattleTheme.ink.opacity(0.85))
                Text(desc).font(.system(size: 13.5, weight: .semibold, design: .rounded)).foregroundStyle(BattleTheme.muted)
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
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .bold, design: .rounded))
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
                           monogram: String(record.fighterName.prefix(1)), size: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.fighterName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink).lineLimit(1)
                    Text("vs \(record.oppName)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(record.won ? "WON" : "LOST")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(record.won ? BattleTheme.leaf : Color(hex: 0xE8654F))
                    Text("· \(record.date, format: .relative(presentation: .named))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                Text("Replay").font(.system(size: 13, weight: .bold, design: .rounded))
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
                           monogram: String(friend.displayName.prefix(1)), size: 62)
                .overlay(alignment: .bottomTrailing) { levelShield }
                .opacity(dim ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(friend.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink).lineLimit(1)
                    TypeChip(type: type)
                }
                Text(archetype.rawValue.capitalized)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
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
                .font(.system(size: 24))
                .foregroundStyle(LinearGradient(colors: [type.color, type.color.darkened(0.32)],
                                                startPoint: .top, endPoint: .bottom))
                .overlay(Image(systemName: "shield")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.35)))
            Text("\(progress.level)")
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
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
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0x07130B))
                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x07130B))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(BattleTheme.gold))
        case .resting(let t):
            pill(text: "Resting \(mmss(t))", color: BattleTheme.gold, dot: true)
        }
    }

    private func pill(text: String, color: Color, dot: Bool) -> some View {
        HStack(spacing: 6) {
            if dot { PulseDot(color: color) }
            Text(text)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
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
        .frame(height: 6)
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
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundStyle(BattleTheme.muted)
                }
                .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Open slot").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(BattleTheme.ink)
                    Text("Send a friend to the Arena").font(.system(size: 13.5, weight: .semibold, design: .rounded)).foregroundStyle(BattleTheme.muted)
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

// MARK: - Fighter card: view a friend's card, then send them off vs a hidden rival

/// Tap a ready team member to land here: their full battle card (stats, moves,
/// XP), their Battle Plan, and the button that sends them off. The opponent
/// stays hidden until the match comes back.
struct FighterCardView: View {
    let friend: Catch

    @Environment(\.dismiss) private var dismiss
    @State private var seed: UInt64
    @State private var opponent: Contender
    @State private var showPlan = false
    @State private var dispatching = false

    private var roster: BattleRoster { .shared }
    private var level: Int { roster.progress(for: friend)?.level ?? 1 }
    private var contender: Contender { .from(friend) }

    init(friend: Catch) {
        self.friend = friend
        let s = UInt64.random(in: 0 ..< UInt64.max)
        _seed = State(initialValue: s)
        _opponent = State(initialValue: .wildRival(seed: s))
    }

    var body: some View {
        ZStack {
            BattleTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    BattleCardView(card: contender.card(level: level),
                                   photoData: friend.photoData,
                                   rarity: friend.species.rarity,
                                   xp: xpProgress)
                        .frame(maxWidth: .infinity)
                    planButton
                    VStack(spacing: 8) {
                        sendButton
                        Label("Off to face a wild challenger — revealed when they're back.",
                              systemImage: "questionmark.circle")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(BattleTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
        .overlay { if dispatching { DispatchOverlay(fighter: friend) } }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: dispatching)
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .sheet(isPresented: $showPlan) {
            BattlePlanEditorView(fighter: friend, archetype: contender.archetype)
        }
    }

    /// Progress toward the next level, for the card's XP bar.
    private var xpProgress: (fraction: Double, caption: String) {
        let lvl = level
        let xp = roster.progress(for: friend)?.xp ?? 0
        if lvl >= 30 { return (1, "MAX") }
        let need = BattleRoster.xpNeeded(for: lvl)
        return (Double(xp) / Double(max(1, need)), "\(xp)/\(need) XP")
    }

    private var planCount: Int {
        roster.storedPlan(for: friend, archetype: contender.archetype).rules.count
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

    private var sendButton: some View {
        Button {
            let plan = roster.storedPlan(for: friend, archetype: contender.archetype)
            let r = simulate(contender.card(level: level), plan.battlePlan,
                             vs: opponent.card(level: level), .defaultPlan(for: opponent.archetype),
                             seed: seed)
            roster.send(friend, opponent: opponent, level: level, plan: plan, seed: seed, result: r)
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

// MARK: - Dispatch confirmation ("off they go")

private struct DispatchOverlay: View {
    let fighter: Catch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false
    @State private var marched = false
    @State private var bannerIn = false

    private var type: BattleType { BattleType(habitat: fighter.effectiveZone) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            RadialGradient(colors: [BattleTheme.gold.opacity(0.20), .clear],
                           center: .center, startRadius: 8, endRadius: 260)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                banner
                    .offset(y: bannerIn ? 0 : -14)
                    .opacity(bannerIn ? 1 : 0)
                PortraitCircle(photoData: fighter.photoData, type: type,
                               monogram: String(fighter.displayName.prefix(1)), size: 116)
                    .rotationEffect(.degrees(marched ? 7 : 0))
                    .offset(x: marched ? 480 : 0, y: bob ? -10 : 6)
                    .opacity(marched ? 0 : 1)
                VStack(spacing: 6) {
                    Text("\(fighter.displayName) marches off to the Arena!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(BattleTheme.ink)
                        .multilineTextAlignment(.center)
                    Text("Off to face a wild challenger — we'll ping you with the result.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BattleTheme.muted)
                }
            }
            .padding(.horizontal, 30)
        }
        .transition(.opacity)
        .onAppear { runSequence() }
    }

    private var banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill").font(.system(size: 13, weight: .black))
            Text("TO THE ARENA")
                .font(.system(size: 13, weight: .black, design: .rounded)).tracking(1.5)
        }
        .foregroundStyle(Color(hex: 0x1C1503))
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(Capsule().fill(LinearGradient(colors: [BattleTheme.gold, Color(hex: 0xE3B85C)],
                                                  startPoint: .top, endPoint: .bottom)))
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: BattleTheme.gold.opacity(0.4), radius: 10, y: 4)
    }

    private func runSequence() {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.3)) { bannerIn = true }
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { bannerIn = true }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { bob = true }
        withAnimation(.easeIn(duration: 0.6).delay(0.9)) { marched = true }
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

// MARK: - Battle card (a tall, raised trading card)

/// A friend as a collectible battle card: their photo as the card face with the
/// type badge and level on it, then HP/STA meters, an ATK/DEF/SPD triad, their
/// moves, and (optionally) an XP bar. Type-tinted, lightly raised.
struct BattleCardView: View {
    let card: BattleCard
    let photoData: Data?
    var rarity: Rarity? = nil
    /// When set, shows an XP bar at the foot of the card.
    var xp: (fraction: Double, caption: String)? = nil

    private var type: BattleType { card.type }
    private var accent: Color { type.color }

    var body: some View {
        VStack(spacing: 0) {
            header
            face
            meters
            triad
            moves
            if let xp { xpBar(xp) }
        }
        .frame(maxWidth: .infinity)
        .background(BattleTheme.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }

    // Header: name + archetype, with a cosmetic rarity frame.
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.ink).lineLimit(1)
                Text(card.archetype.rawValue.capitalized)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
            }
            Spacer(minLength: 6)
            if let rarity { rarityFrame(rarity) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(accent.opacity(0.16))
    }

    private func rarityFrame(_ r: Rarity) -> some View {
        VStack(spacing: 0) {
            Text(r.fieldTerm.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.4)
                .foregroundStyle(BattleTheme.ink)
            Text("◆ frame")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.gold)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(
            Capsule().fill(r.tint.opacity(0.22))
                .overlay(Capsule().stroke(r.tint.opacity(0.5), lineWidth: 1))
        )
    }

    // Face: the friend's photo as card art (a 3:2 window that scales with the
    // card width), with the type badge + level on it.
    private var face: some View {
        Color.clear
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .overlay {
                if let photoData, let ui = UIImage(data: photoData) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [accent, accent.darkened(0.45)], startPoint: .top, endPoint: .bottom)
                        .overlay(Text(String(card.name.prefix(1)))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85)))
                }
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) { TypeChip(type: type).padding(10) }
            .overlay(alignment: .bottomTrailing) {
                Text("Lv \(card.level)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0x07130B))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(BattleTheme.gold))
                    .padding(10)
            }
    }

    // HP + Stamina meters.
    private var meters: some View {
        VStack(spacing: 9) {
            meter("HP", card.stats.hp, BattleTheme.leaf)
            meter("STA", card.stats.sta, Color(hex: 0x5FC7D6))
        }
        .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 4)
    }

    private func meter(_ lab: String, _ val: Int, _ color: Color) -> some View {
        let ref = Double(totalBudget(atLevel: card.level)) * 0.40
        return HStack(spacing: 9) {
            Text(lab)
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .foregroundStyle(BattleTheme.muted).frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: max(6, geo.size.width * min(1, Double(val) / ref)))
                }
            }
            .frame(height: 9)
            Text("\(val)")
                .font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(BattleTheme.ink).frame(width: 34, alignment: .trailing)
        }
    }

    // ATK / DEF / SPD as three boxes.
    private var triad: some View {
        HStack(spacing: 6) {
            triadBox("ATK", card.stats.atk)
            triadBox("DEF", card.stats.def)
            triadBox("SPD", card.stats.spd)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func triadBox(_ k: String, _ n: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(n)")
                .font(.system(size: 16, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(BattleTheme.ink)
            Text(k)
                .font(.system(size: 9.5, weight: .heavy, design: .rounded)).tracking(0.5)
                .foregroundStyle(BattleTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    // The three moves.
    private var moves: some View {
        VStack(spacing: 8) {
            moveRow(card.strike)
            moveRow(card.utility)
            moveRow(card.special, special: true)
        }
        .padding(.horizontal, 14).padding(.top, 11).padding(.bottom, xp == nil ? 14 : 11)
        .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 1) }
    }

    private func moveRow(_ m: Move, special: Bool = false) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(special ? BattleTheme.gold : accent)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(special ? 45 : 0))
            Text(m.name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(special ? BattleTheme.gold : BattleTheme.ink).lineLimit(1)
            Spacer(minLength: 6)
            Text(m.power > 0 ? "⚔ \(m.power) · ⚡\(m.stamina)" : "⚡\(m.stamina)")
                .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(BattleTheme.muted)
        }
    }

    private func xpBar(_ xp: (fraction: Double, caption: String)) -> some View {
        HStack(spacing: 9) {
            Text("XP").font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(BattleTheme.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(BattleTheme.gold)
                        .frame(width: max(4, geo.size.width * min(1, xp.fraction)))
                }
            }
            .frame(height: 7)
            Text(xp.caption)
                .font(.system(size: 10.5, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(BattleTheme.gold)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 1) }
    }
}

// MARK: - Shared bits

struct TypeChip: View {
    let type: BattleType
    var body: some View {
        Text(type.rawValue.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(Color(hex: 0x0C130F))
            .padding(.horizontal, 8).padding(.vertical, 3.5)
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
                Circle().stroke(color, lineWidth: 1.5).frame(width: 8, height: 8)
                    .scaleEffect(animate ? 2.4 : 1)
                    .opacity(animate ? 0 : 0.7)
            }
            Circle().fill(color).frame(width: 8, height: 8)
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
