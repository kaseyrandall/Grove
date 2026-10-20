import SwiftUI
import SwiftData

// MARK: - Per-slot state on the home

private enum SlotState {
    case ready
    case away(TimeInterval)
    case resultReady(BattleRoster.MatchOutcome)
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
    @State private var showIntro = false
    @AppStorage(BattleRoster.introSeenKey) private var introSeen = false
    @AppStorage(BattleRoster.setupDoneKey) private var setupDone = false

    private var roster: BattleRoster { .shared }
    private var team: [(friend: Catch, progress: BattleRoster.Progress)] {
        roster.teamCatches(from: catches)
    }
    private var promotable: [Catch] { catches.filter { !roster.teamContains($0) } }
    /// History without results still waiting to be watched, so Last match
    /// and History don't spoil them.
    private var seenHistory: [BattleRoster.MatchRecord] {
        roster.matchHistory().filter { !roster.isUnwatched($0, in: catches) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            MatchDayBackdrop()
            Group {
                switch tab {
                case 1: historyTab
                case 2: trophiesTab
                default: arenaTab
                }
            }
            .id(tab)
            .transition(.opacity.combined(with: .offset(y: 10)))
            // Long lists fade out under the clock and back button.
            if tab != 0 { topFade }
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .toolbar {
            if tab == 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showIntro = true } label: { Image(systemName: "info.circle") }
                        .tint(BattleTheme.ink)
                        .accessibilityLabel("How Battlegrounds works")
                }
            }
        }
        .fullScreenCover(isPresented: $showIntro) {
            ArenaIntroView(friends: introFriends,
                           featured: introFriends.first.map { BattleType(habitat: $0.effectiveZone) } ?? .meadow,
                           finishTitle: team.isEmpty ? "Build my team" : "Let's go") {
                let firstTime = !introSeen
                introSeen = true
                showIntro = false
                // Straight into picking a first fighter.
                if firstTime && team.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showPromote = true }
                }
            }
        }
        .onAppear {
            roster.prepare(with: catches)
            if !introSeen {
                // Someone already playing doesn't need the checklist.
                if setup.isComplete { setupDone = true }
                showIntro = true
            }
            #if DEBUG
            // Test hooks: `-GroveArenaTrophies` opens on Trophies;
            // `-GroveSampleTrophies` fills in a few days of play.
            if LaunchFlag.once("-GroveSampleTrophies") { roster.devSampleTrophies() }
            if LaunchFlag.once("-GroveArenaTrophies") { tab = 2 }
            #endif
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            roster.settleDueMatches(from: catches)
        }
        .sheet(isPresented: $showPromote) { PromotePickerSheet(candidates: promotable) }
    }

    // MARK: Battle tab

    private var arenaTab: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Battle", "Send a friend to a match. Back in 20 minutes with a result.",
                                  accent: "grounds")
                        .overlay(alignment: .topTrailing) {
                            Bolt().stroke(BattleTheme.leaf, lineWidth: 2)
                                .frame(width: 130, height: 22)
                                .offset(x: 16, y: -12)
                                .accessibilityHidden(true)
                        }
                    if !setupDone {
                        SetupChecklist(setup: setup) { withAnimation { setupDone = true } }
                    }
                    // A 0–0 scoreboard means nothing yet; it appears after the
                    // first result.
                    if setupDone || !seenHistory.isEmpty { scoreboard }
                    groupLabel("Your team", detail: "\(team.count) / \(roster.maxSlots)")
                    // Three friends side by side, like a party lineup.
                    // Every card matches the tallest, whatever its state.
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(0..<roster.maxSlots, id: \.self) { i in
                            slot(i).frame(maxWidth: .infinity, maxHeight: .infinity)
                                .arenaEntrance(i + 1)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if !setupDone, let tip = coachTip {
                        CoachTip(title: tip.title, detail: tip.detail)
                    }
                    if let last = seenHistory.first {
                        groupLabel("Last match")
                            .padding(.top, 4)
                        NavigationLink {
                            LazyView {
                                ArenaReplayView(result: last.replay(),
                                                portraits: [BattlePortrait(friend: roster.friend(for: last, in: catches)), last.rivalPortrait])
                            }
                        } label: {
                            LastMatchCard(record: last, friend: roster.friend(for: last, in: catches))
                        }
                        .buttonStyle(ArenaPress())
                    }
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Getting started

    /// Friends for the intro's first screen: the team, else the Grove's
    /// rarest friends with photos.
    private var introFriends: [Catch] {
        if !team.isEmpty { return team.map(\.friend) }
        let named = catches.filter { $0.species.id != Species.mystery.id }
        let withPhotos = named.filter { $0.photoData != nil }
        let pool = (withPhotos.isEmpty ? named : withPhotos).sorted { $0.species.rarity > $1.species.rarity }
        // Three different habitats when possible, so the colors vary.
        var picks: [Catch] = []
        for c in pool where !picks.contains(where: { $0.effectiveZone == c.effectiveZone }) {
            picks.append(c)
            if picks.count == 3 { break }
        }
        for c in pool where picks.count < 3 && !picks.contains(where: { $0 === c }) { picks.append(c) }
        return picks
    }

    private var setup: ArenaSetup {
        let members = team.map(\.friend)
        let sentNow = members.contains { roster.isAway($0) || roster.hasUnwatchedResult($0) }
        return ArenaSetup(picked: !team.isEmpty || !roster.matchHistory().isEmpty,
                          sent: sentNow || !roster.matchHistory().isEmpty,
                          watched: !seenHistory.isEmpty,
                          fullTeam: team.count >= roster.maxSlots)
    }

    /// What to tap next, while getting set up.
    private var coachTip: (title: String, detail: String?)? {
        let s = setup
        let members = team.map(\.friend)
        if !s.picked {
            return ("Tap an open slot", "Pick your first fighter from your Grove.")
        }
        if !s.sent, let f = members.first(where: { roster.canSend($0) }) {
            return ("Tap Ready to send \(f.displayName)", "Your first match is quick: back in a minute.")
        }
        if !s.watched {
            if let f = members.first(where: { roster.hasUnwatchedResult($0) }) {
                return ("Tap Watch to see how \(f.displayName) did", nil)
            }
            if let f = members.first(where: { roster.isAway($0) }) {
                return ("\(f.displayName) is in a match", "Back in \(mmss(roster.awayRemaining(f))). Stay here or come back later.")
            }
        }
        if !s.fullTeam {
            let left = roster.maxSlots - team.count
            return ("Add \(left) more friend\(left == 1 ? "" : "s")", "Tap an open slot to fill your team of three.")
        }
        return nil
    }

    // MARK: Scoreboard (record · streak · power)

    private var scoreboard: some View {
        // Watched results only: an unwatched loss shouldn't show here first.
        let seen = seenHistory
        let wins = seen.filter { $0.outcome == .win }.count
        let losses = seen.filter { $0.outcome == .loss }.count
        let draws = seen.filter { $0.outcome == .draw }.count
        let streak = seen.prefix { $0.won }.count
        return HStack(spacing: 0) {
            score(draws > 0 ? "\(wins)–\(losses)–\(draws)" : "\(wins)–\(losses)",
                  "Record", BattleTheme.gold)
            divider
            score("\(streak)", "Streak", streak > 0 ? Color(hex: 0xFF8A4B) : BattleTheme.ink)
            divider
            score("\(squadPower)", "Power", BattleTheme.ink)
        }
        .padding(.vertical, 12)
        .background(
            Slant(trail: 14)
                .fill(LinearGradient(colors: [BattleTheme.leaf.opacity(0.12), BattleTheme.panel.opacity(0.92)],
                                     startPoint: .leading, endPoint: UnitPoint(x: 0.45, y: 0.5)))
        )
        .overlay(alignment: .leading) { Rectangle().fill(BattleTheme.leaf).frame(width: 3) }
    }

    private var divider: some View {
        Rectangle().fill(BattleTheme.panelLine).frame(width: 1, height: 56)
    }

    private var squadPower: Int {
        team.reduce(0) { $0 + totalBudget(atLevel: $1.progress.level) }
    }

    private func score(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .arenaDisplay(44)
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label.uppercased())
                .arenaFont(10, .bold, .rounded)
                .tracking(2)
                .foregroundStyle(BattleTheme.muted)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// A page-level header shown inside the content of each tab (so the nav bar
    /// doesn't have to repeat the title). `accent` is set in mint after it.
    private func sectionHeader(_ title: String, _ subtitle: String, accent: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text(title.uppercased()).foregroundStyle(BattleTheme.ink)
             + Text(accent.uppercased()).foregroundStyle(BattleTheme.leaf))
                .arenaDisplay(46)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(subtitle)
                .arenaFont(14, .semibold, .rounded)
                .foregroundStyle(BattleTheme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    /// "YOUR TEAM  3/3 ———"
    private func groupLabel(_ text: String, detail: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .arenaDisplay(15)
                .foregroundStyle(BattleTheme.muted)
            if let detail {
                Text(detail)
                    .arenaDisplay(15)
                    .foregroundStyle(BattleTheme.ink.opacity(0.5))
            }
            LinearGradient(colors: [BattleTheme.panelLine, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
        }
    }

    @ViewBuilder private func slot(_ i: Int) -> some View {
        if i < team.count {
            let f = team[i].friend
            let p = team[i].progress
            if roster.hasUnwatchedResult(f) {
                // Lazy, so the replay is only simulated when opened (not on
                // every one-second redraw).
                NavigationLink { LazyView { resultReplay(for: f) } } label: {
                    TeamStatusCard(friend: f, progress: p, state: .resultReady(roster.pendingOutcome(f) ?? .loss))
                }
                .buttonStyle(ArenaPress())
            } else if roster.isAway(f) {
                #if DEBUG
                TeamStatusCard(friend: f, progress: p, state: .away(roster.awayRemaining(f)),
                               devResolve: { roster.devResolveNow(f) })
                #else
                TeamStatusCard(friend: f, progress: p, state: .away(roster.awayRemaining(f)))
                #endif
            } else if roster.isResting(f) {
                #if DEBUG
                TeamStatusCard(friend: f, progress: p, state: .resting(roster.restRemaining(f)),
                               devResolve: { roster.devWake(f) })
                #else
                TeamStatusCard(friend: f, progress: p, state: .resting(roster.restRemaining(f)))
                #endif
            } else {
                NavigationLink { LazyView { FighterCardView(friend: f) } } label: {
                    TeamStatusCard(friend: f, progress: p, state: .ready)
                }
                .buttonStyle(ArenaPress())
            }
        } else {
            EmptySlotCard { showPromote = true }
        }
    }

    @ViewBuilder private func resultReplay(for c: Catch) -> some View {
        if let r = roster.replayResult(for: c) {
            ArenaReplayView(result: r, portraits: [BattlePortrait(friend: c), roster.rivalPortrait(for: c)])
                .onAppear { roster.markWatched(c) }
        }
    }

    // MARK: History tab

    private var historyTab: some View {
        let records = seenHistory
        return ScrollView {
            if records.isEmpty {
                VStack(spacing: 8) {
                    Text("🗒️").arenaFont(36)
                    Text("No matches yet")
                        .arenaFont(18, .bold, .rounded)
                        .foregroundStyle(BattleTheme.ink)
                    Text("Send a friend off to Battlegrounds —\ntheir matches show up here to rewatch.")
                        .multilineTextAlignment(.center)
                        .arenaFont(14, .semibold, .rounded)
                        .foregroundStyle(BattleTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80).padding(.horizontal, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    sectionHeader("History", "Every match your team has fought. Tap to rewatch.")
                        .padding(.bottom, 2)
                    ForEach(Array(records.enumerated()), id: \.element.id) { n, rec in
                        NavigationLink {
                            LazyView {
                                ArenaReplayView(result: rec.replay(),
                                                portraits: [BattlePortrait(friend: roster.friend(for: rec, in: catches)), rec.rivalPortrait])
                            }
                        } label: {
                            LastMatchCard(record: rec, friend: roster.friend(for: rec, in: catches))
                        }
                        .buttonStyle(ArenaPress())
                        .arenaEntrance(n)
                    }
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var topFade: some View {
        GeometryReader { geo in
            LinearGradient(stops: [.init(color: Color(hex: 0x0B1D16), location: 0),
                                   .init(color: Color(hex: 0x0B1D16), location: 0.65),
                                   .init(color: Color(hex: 0x0B1D16).opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: geo.safeAreaInsets.top + 18)
                .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }

    // MARK: Trophies tab

    private var trophiesTab: some View {
        TrophiesTab(ledger: roster.trophies) { roster.markTrophiesSeen() }
    }

    // MARK: Bottom tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(0, "Battle")
            tabItem(1, "History")
            tabItem(2, "Trophies", dot: roster.hasUnseenTrophies && tab != 2)
        }
        .padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 6)
        .background(
            Color(hex: 0x08130E)
                .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 2) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(_ i: Int, _ label: String, dot: Bool = false) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { tab = i } } label: {
            VStack(spacing: 6) {
                Text(label.uppercased())
                    .arenaDisplay(17)
                    // A gold dot: a trophy you haven't seen yet.
                    .overlay(alignment: .topTrailing) {
                        if dot {
                            Circle().fill(TrophyStyle.gold).frame(width: 8, height: 8).offset(x: 8, y: -2)
                        }
                    }
                Lean(amount: 2).fill(tab == i ? BattleTheme.leaf : .clear)
                    .frame(width: 28, height: 3)
            }
            .foregroundStyle(tab == i ? BattleTheme.leaf : BattleTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == i ? .isSelected : [])
    }
}

private struct HistoryRow: View {
    let record: BattleRoster.MatchRecord
    let friend: Catch?

    var body: some View {
        HStack(spacing: 12) {
            PortraitCircle(friend: friend, type: record.fighterType,
                           monogram: String(record.fighterName.prefix(1)), size: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.fighterName)
                        .arenaFont(16, .bold, .rounded)
                        .foregroundStyle(BattleTheme.ink).lineLimit(1)
                    Text("vs \(record.oppName)")
                        .arenaFont(14, .semibold, .rounded)
                        .foregroundStyle(BattleTheme.muted).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(record.outcome == .win ? "WON" : record.outcome == .draw ? "DRAW" : "LOST")
                        .arenaFont(11, .heavy, .rounded)
                        .foregroundStyle(record.outcome == .win ? BattleTheme.leaf
                                         : record.outcome == .draw ? BattleTheme.gold : Color(hex: 0xE8654F))
                    Text("· \(record.date, format: .relative(presentation: .named))")
                        .arenaFont(12, .semibold, .rounded)
                        .foregroundStyle(BattleTheme.muted)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "play.fill").arenaFont(12, .bold)
                Text("Replay").arenaFont(13, .bold, .rounded)
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
    private var isResultReady: Bool {
        if case .resultReady = state { return true }; return false
    }
    /// Which state, ignoring the ticking timers (so the tag pops only on a change).
    private var stateKey: String {
        switch state {
        case .ready: "ready"
        case .away: "away"
        case .resultReady: "result"
        case .resting: "resting"
        }
    }
    /// How far the card leans (points across its height).
    private let lean: CGFloat = 12
    private var shape: Slant { Slant(lead: lean, trail: lean) }
    private var edge: Color { isResultReady ? BattleTheme.gold : type.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName.uppercased())
                    .arenaDisplay(23)
                    .foregroundStyle(BattleTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(archetype.rawValue.uppercased())
                    .arenaFont(10.5, .bold, .rounded)
                    .tracking(0.3)
                    .foregroundStyle(BattleTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                xpBar.padding(.top, 7).padding(.bottom, 10).padding(.trailing, 6)
                Spacer(minLength: 0)
                statusButton.padding(.trailing, 4)
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.top, 18).padding(.bottom, 9)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(shape.fill(BattleTheme.panel))
        .clipShape(shape)
        .overlay(shape.stroke(edge, lineWidth: 2))
        .shadow(color: edge.opacity(glowOpacity), radius: glowRadius)
        .overlay(alignment: .topLeading) {
            tag.offset(x: lean + 2, y: -12)
                .id(stateKey)
                .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: stateKey)
        .padding(.top, 12)
        .contentShape(shape)
        .onAppear {
            guard isResultReady, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }

    /// The tab riding the top edge: what the friend is up to, at a glance.
    @ViewBuilder private var tag: some View {
        switch state {
        case .ready:
            EmptyView() // the button already says Ready
        case .away(let t):
            SlantTag(text: "Away \(mmss(t))", ink: BattleTheme.leaf)
        case .resting(let t):
            SlantTag(text: "Nap \(mmss(t))", ink: BattleTheme.gold)
        case .resultReady:
            SlantTag(text: "Finished", fill: BattleTheme.gold, ink: Color(hex: 0x120E02), outline: nil)
        }
    }

    /// The photo (or art) across the top, habitat-colored hex level riding
    /// its bottom edge.
    private var photo: some View {
        PortraitFill(portrait: BattlePortrait(friend: friend), color: type.color,
                     monogram: String(friend.displayName.prefix(1)))
            .frame(height: 148)
            .frame(maxWidth: .infinity)
            .clipped()
            .saturation(dim ? 0.4 : 1)
            .brightness(dim ? -0.25 : 0)
            .overlay {
                LinearGradient(colors: [.clear, BattleTheme.panel], startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) { devSkipButton.padding(.top, 8).padding(.trailing, 6) }
            .overlay(alignment: .bottomLeading) { levelHex.padding(.leading, 10).offset(y: 16) }
            .zIndex(1)
    }

    private var levelHex: some View {
        Text("\(progress.level)")
            .arenaDisplay(17)
            .foregroundStyle(Color(hex: 0x08110C))
            .frame(width: 34, height: 38)
            .background(Hexagon().fill(type.color))
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .accessibilityLabel("Level \(progress.level)")
    }

    private var glowOpacity: Double {
        if dim { return 0.15 }
        if isResultReady { return pulse ? 0.65 : 0.3 }
        return 0.4
    }
    private var glowRadius: CGFloat { isResultReady ? (pulse ? 16 : 10) : 9 }

    /// The action (or status) at the bottom of the card.
    @ViewBuilder private var statusButton: some View {
        switch state {
        case .ready:       LeanButtonFace(text: "Ready", style: .action)
        case .resultReady: LeanButtonFace(text: "Watch ▶", style: .reward, shimmer: true)
        case .away:        LeanButtonFace(text: "In a match", style: .quiet)
        case .resting:     LeanButtonFace(text: "Resting", style: .quiet)
        }
    }

    /// Dev: skip the wait (finish the match, or wake from the nap).
    @ViewBuilder private var devSkipButton: some View {
        #if DEBUG
        if let devResolve {
            Button(action: devResolve) {
                Image(systemName: "forward.end.fill")
                    .arenaFont(11, .bold)
                    .foregroundStyle(BattleTheme.ink)
                    .padding(7)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
        }
        #endif
    }

    private var xpBar: some View {
        let need = BattleRoster.xpNeeded(for: progress.level)
        let frac = progress.level >= 30 ? 1 : Double(progress.xp) / Double(max(1, need))
        return LeanBar(fraction: max(0.04, frac), color: BattleTheme.gold, height: 4)
    }
}

// MARK: - Empty slot

private struct EmptySlotCard: View {
    let action: () -> Void
    private let shape = Slant(lead: 12, trail: 12)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .arenaFont(20, .bold)
                    .foregroundStyle(BattleTheme.muted)
                    .frame(width: 46, height: 50)
                    .background(Hexagon().strokeBorder(BattleTheme.panelLine, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])))
                Text("OPEN SLOT").arenaDisplay(17).foregroundStyle(BattleTheme.ink)
                Text("Add a friend").arenaFont(11.5, .semibold, .rounded).foregroundStyle(BattleTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: .infinity)
            .background(
                shape.fill(Color.white.opacity(0.02))
                    .overlay(shape.stroke(BattleTheme.panelLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])))
            )
            .contentShape(shape)
            .padding(.top, 12)
        }
        .buttonStyle(ArenaPress())
        .accessibilityLabel("Open slot. Add a friend to the team.")
    }
}

// MARK: - Last match

/// The most recent match: both faces in hexes, the result, and a Replay.
private struct LastMatchCard: View {
    let record: BattleRoster.MatchRecord
    let friend: Catch?

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                HexPortrait(portrait: BattlePortrait(friend: friend), color: record.fighterType.color,
                            monogram: String(record.fighterName.prefix(1)), width: 40)
                HexPortrait(portrait: record.rivalPortrait, color: record.oppType.color,
                            monogram: String(record.oppName.prefix(1)), width: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                (Text(record.fighterName.uppercased()).foregroundStyle(BattleTheme.ink)
                 + Text(" VS \(rivalName.uppercased())").foregroundStyle(BattleTheme.muted))
                    .arenaDisplay(18)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                (Text(outcomeText) + Text(" · ") + Text(record.date, format: .relative(presentation: .named)))
                    .arenaFont(10.5, .bold, .rounded)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(outcomeColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text("▶ REPLAY")
                .arenaDisplay(16)
                .foregroundStyle(BattleTheme.gold)
                .fixedSize()
        }
        .padding(.leading, 14).padding(.trailing, 22).padding(.vertical, 10)
        .background(
            Slant(trail: 12)
                .fill(LinearGradient(colors: [outcomeColor.opacity(0.14), BattleTheme.panel],
                                     startPoint: .leading, endPoint: UnitPoint(x: 0.45, y: 0.5)))
        )
        .overlay(alignment: .leading) { Rectangle().fill(outcomeColor).frame(width: 3) }
    }

    /// "Wild Salamander" reads as "Salamander" here; there's no room for both.
    private var rivalName: String {
        record.oppName.hasPrefix("Wild ") ? String(record.oppName.dropFirst(5)) : record.oppName
    }
    private var outcomeText: String {
        switch record.outcome { case .win: "Won"; case .draw: "Draw"; case .loss: "Lost" }
    }
    private var outcomeColor: Color {
        switch record.outcome {
        case .win: BattleTheme.leaf
        case .draw: BattleTheme.gold
        case .loss: BattleTheme.foe
        }
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
    @State private var showPlan = false
    @State private var dispatching = false

    private var roster: BattleRoster { .shared }
    private var level: Int { roster.progress(for: friend)?.level ?? 1 }
    private var contender: Contender { .from(friend) }

    init(friend: Catch) {
        self.friend = friend
        _seed = State(initialValue: UInt64.random(in: 0 ..< UInt64.max))
    }

    var body: some View {
        ZStack {
            MatchDayBackdrop(glow: contender.type.color)
            ScrollView {
                VStack(spacing: 16) {
                    BattleCardView(card: contender.card(level: level),
                                   portrait: BattlePortrait(friend: friend),
                                   rarity: friend.species.rarity,
                                   xp: xpProgress)
                        .frame(maxWidth: .infinity)
                    planButton
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            // The send button stays put at the bottom; the card scrolls
            // under it and fades out behind.
            .safeAreaInset(edge: .bottom, spacing: 0) { sendBar }
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
                    .arenaFont(16, .bold)
                    .foregroundStyle(BattleTheme.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("BATTLE PLAN")
                        .arenaDisplay(20)
                        .foregroundStyle(BattleTheme.ink)
                    Text("\(planCount) rule\(planCount == 1 ? "" : "s") · tap to coach")
                        .arenaFont(11, .bold, .rounded)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(BattleTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .arenaFont(13, .bold)
                    .foregroundStyle(BattleTheme.muted)
            }
            .padding(.leading, 16).padding(.trailing, 24).padding(.vertical, 12)
            .background(Slant(trail: 12).fill(BattleTheme.panel.opacity(0.92)))
            .overlay(alignment: .leading) { Rectangle().fill(BattleTheme.gold).frame(width: 3) }
            .contentShape(Rectangle())
        }
        .buttonStyle(ArenaPress())
    }

    /// The pinned bottom bar: a fade over the scrolling card, the button and
    /// a line about the hidden rival.
    private var sendBar: some View {
        VStack(spacing: 10) {
            sendButton
            Text("Off to face a wild challenger, revealed when they're back.")
                .arenaFont(12, .semibold, .rounded)
                .foregroundStyle(BattleTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal).padding(.top, 34).padding(.bottom, 6)
        .background(
            LinearGradient(stops: [.init(color: BattleTheme.night.opacity(0), location: 0),
                                   .init(color: BattleTheme.night, location: 0.22),
                                   .init(color: BattleTheme.night, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        )
    }

    private var sendButton: some View {
        Button {
            let plan = roster.storedPlan(for: friend, archetype: contender.archetype)
            let rival = Contender.rival(near: level, avoiding: contender.name, seed: seed)
            let r = simulate(contender.card(level: level), plan.battlePlan,
                             vs: rival.contender.card(level: rival.level), .defaultPlan(for: rival.contender.archetype),
                             seed: seed)
            roster.send(friend, opponent: rival.contender, opponentLevel: rival.level, level: level,
                        plan: plan, seed: seed, result: r)
            withAnimation(.easeInOut(duration: 0.25)) { dispatching = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                dismiss()
            }
        } label: {
            SendToBattleFace()
        }
        .buttonStyle(ArenaPress())
    }
}

/// The big Send to battle button: a slow breathing glow and a bright
/// shimmer sweeping across every few seconds (both off under Reduce Motion).
private struct SendToBattleFace: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        LeanButtonFace(text: "Send to battle", style: .action, height: 60, size: 26, shimmer: true)
            .shadow(color: BattleTheme.leaf.opacity(glow ? 0.6 : 0.3), radius: glow ? 22 : 12)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
            }
            .accessibilityLabel("Send to battle")
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
            BattleTheme.night.opacity(0.95).ignoresSafeArea()
            RadialGradient(colors: [BattleTheme.leaf.opacity(0.18), .clear],
                           center: .center, startRadius: 8, endRadius: 280)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                banner
                    .offset(y: bannerIn ? 0 : -14)
                    .opacity(bannerIn ? 1 : 0)
                HexPortrait(portrait: BattlePortrait(friend: fighter), color: type.color,
                            monogram: String(fighter.displayName.prefix(1)), width: 128, ring: BattleTheme.leaf)
                    .shadow(color: BattleTheme.leaf.opacity(0.4), radius: 20)
                    .rotationEffect(.degrees(marched ? 7 : 0))
                    .offset(x: marched ? 480 : 0, y: bob ? -10 : 6)
                    .opacity(marched ? 0 : 1)
                VStack(spacing: 6) {
                    Text("\(fighter.displayName.uppercased()) MARCHES OFF!")
                        .arenaDisplay(34)
                        .foregroundStyle(BattleTheme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text("Off to face a wild challenger. We'll let you know how it went.")
                        .arenaFont(14, .semibold, .rounded)
                        .foregroundStyle(BattleTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 30)
        }
        .transition(.opacity)
        .onAppear { runSequence() }
    }

    private var banner: some View {
        SlantTag(text: "To Battlegrounds", fill: BattleTheme.gold, ink: Color(hex: 0x1C1503), outline: nil, size: 16)
            .shadow(color: BattleTheme.gold.opacity(0.45), radius: 12)
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
    @Query private var catches: [Catch]
    @Environment(\.dismiss) private var dismiss
    private var roster: BattleRoster { .shared }

    var body: some View {
        NavigationStack {
            ZStack {
                MatchDayBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            (Text("PICK A ").foregroundStyle(BattleTheme.ink)
                             + Text("FIGHTER").foregroundStyle(BattleTheme.leaf))
                                .arenaDisplay(38)
                            Text("They join your team and keep what they've earned.")
                                .arenaFont(13.5, .semibold, .rounded)
                                .foregroundStyle(BattleTheme.muted)
                        }
                        .padding(.bottom, 8)
                        if candidates.isEmpty {
                            Text("Every friend is already on your team, or you haven't met any yet.")
                                .arenaFont(14, .semibold, .rounded)
                                .foregroundStyle(BattleTheme.muted)
                                .padding(.top, 30)
                        }
                        ForEach(candidates) { c in
                            Button {
                                if roster.promote(c) { dismiss() }
                            } label: {
                                PromoteRow(friend: c, benched: roster.hasEverPromoted(c))
                            }
                            .buttonStyle(ArenaPress())
                            .disabled(!roster.hasFreeSlot(among: catches))
                            .opacity(roster.hasFreeSlot(among: catches) ? 1 : 0.5)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
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
            HexPortrait(portrait: BattlePortrait(friend: friend), color: type.color,
                        monogram: String(friend.displayName.prefix(1)), width: 50, ring: type.color)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName.uppercased())
                    .arenaDisplay(22)
                    .foregroundStyle(BattleTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 7) {
                    TypeChip(type: type)
                    Text(archetype.rawValue.uppercased())
                        .arenaFont(10, .bold, .rounded)
                        .tracking(0.5)
                        .foregroundStyle(BattleTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if benched, let p = BattleRoster.shared.progress(for: friend) {
                        Text("LV \(p.level) BENCHED")
                            .arenaDisplay(12)
                            .foregroundStyle(BattleTheme.gold)
                    }
                }
            }
            Spacer(minLength: 6)
            LeanButtonFace(text: "Add", style: .action, height: 34, size: 15)
                .frame(width: 64)
        }
        .padding(.leading, 14).padding(.trailing, 20).padding(.vertical, 10)
        .background(Slant(trail: 12).fill(BattleTheme.panel.opacity(0.92)))
        .overlay(alignment: .leading) { Rectangle().fill(type.color).frame(width: 3) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Adds \(friend.displayName) to your team")
    }
}

// MARK: - Battle card (a tall, raised trading card)

/// A friend as a collectible battle card: their photo as the card face with the
/// type badge and level on it, then HP/STA meters, an ATK/DEF/SPD triad, their
/// moves, and (optionally) an XP bar. Type-tinted, lightly raised.
struct BattleCardView: View {
    let card: BattleCard
    let portrait: BattlePortrait
    var rarity: Rarity? = nil
    /// When set, shows an XP bar at the foot of the card.
    var xp: (fraction: Double, caption: String)? = nil

    private var type: BattleType { card.type }
    private var accent: Color { type.color }
    /// The card's shape: square corners, the bottom-right cut away.
    private var shape: CutCorner { CutCorner(cut: 26) }

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
        .background(shape.fill(Color(hex: 0x09140F)))
        .clipShape(shape)
        .overlay(shape.stroke(accent, lineWidth: 2))
        .shadow(color: accent.opacity(0.35), radius: 18)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }

    // Header: name + playstyle, with the rarity as a slanted tag.
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(card.name.uppercased())
                    .arenaDisplay(30)
                    .foregroundStyle(BattleTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(card.archetype.rawValue.uppercased())
                    .arenaFont(11, .bold, .rounded)
                    .tracking(1)
                    .foregroundStyle(BattleTheme.muted)
            }
            Spacer(minLength: 6)
            if let rarity {
                SlantTag(text: rarity.title, fill: rarity.tint.opacity(0.25), ink: BattleTheme.ink,
                         outline: rarity.tint.opacity(0.6), size: 13)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.06)], startPoint: .leading, endPoint: .trailing))
    }

    // Face: the friend's photo as card art, framed as they cropped it and in
    // the same 4:3 shape as everywhere else in Grove (or their kind's art),
    // with the level hex and habitat tag on it.
    private var face: some View {
        Color.clear
            .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
            .overlay {
                PortraitFill(portrait: portrait, color: accent, monogram: String(card.name.prefix(1)), artScale: 0.6)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Color(hex: 0x09140F).opacity(0.85)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(spacing: -2) {
                    Text("LV").arenaDisplay(11)
                    Text("\(card.level)").arenaDisplay(22)
                }
                .foregroundStyle(Color(hex: 0x08110C))
                .frame(width: 48, height: 53)
                .background(Hexagon().fill(accent))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .padding(12)
                .accessibilityLabel("Level \(card.level)")
            }
            .overlay(alignment: .bottomTrailing) { TypeChip(type: type).padding(14) }
    }

    // HP + Stamina meters.
    private var meters: some View {
        VStack(spacing: 10) {
            meter("HP", card.stats.hp, BattleTheme.leaf)
            meter("STA", card.stats.sta, BattleTheme.sta)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
    }

    private func meter(_ lab: String, _ val: Int, _ color: Color) -> some View {
        let ref = Double(totalBudget(atLevel: card.level)) * 0.40
        return HStack(spacing: 10) {
            Text(lab)
                .arenaDisplay(15)
                .foregroundStyle(BattleTheme.muted)
                .frame(width: 34, alignment: .leading)
            LeanBar(fraction: max(0.04, Double(val) / ref), color: color, height: 10)
            Text("\(val)")
                .arenaDisplay(20)
                .monospacedDigit()
                .foregroundStyle(BattleTheme.ink)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // ATK / DEF / SPD as three leaning boxes.
    private var triad: some View {
        HStack(spacing: 8) {
            triadBox("ATK", card.stats.atk)
            triadBox("DEF", card.stats.def)
            triadBox("SPD", card.stats.spd)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func triadBox(_ k: String, _ n: Int) -> some View {
        VStack(spacing: 0) {
            Text("\(n)")
                .arenaDisplay(30)
                .monospacedDigit()
                .foregroundStyle(BattleTheme.ink)
            Text(k)
                .arenaFont(10, .bold, .rounded)
                .tracking(1.5)
                .foregroundStyle(BattleTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(Lean(amount: 8).fill(.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }

    // The three moves.
    private var moves: some View {
        VStack(spacing: 9) {
            moveRow(card.strike)
            moveRow(card.utility)
            moveRow(card.special, special: true)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, xp == nil ? 18 : 12)
        .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 1).padding(.horizontal, 16) }
    }

    private func moveRow(_ m: Move, special: Bool = false) -> some View {
        HStack(spacing: 10) {
            Lean(amount: 3)
                .fill(special ? BattleTheme.gold : accent)
                .frame(width: 12, height: 10)
            Text(m.name.uppercased())
                .arenaDisplay(18)
                .foregroundStyle(special ? BattleTheme.gold : BattleTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(m.power > 0 ? "⚔ \(m.power) · ⚡\(m.stamina)" : "⚡\(m.stamina)")
                .arenaFont(11.5, .bold, .rounded)
                .monospacedDigit()
                .foregroundStyle(BattleTheme.muted)
        }
    }

    private func xpBar(_ xp: (fraction: Double, caption: String)) -> some View {
        HStack(spacing: 10) {
            Text("XP").arenaDisplay(15).foregroundStyle(BattleTheme.muted)
            LeanBar(fraction: max(0.03, xp.fraction), color: BattleTheme.gold, height: 7)
            Text(xp.caption.uppercased())
                .arenaDisplay(15)
                .monospacedDigit()
                .foregroundStyle(BattleTheme.gold)
        }
        .padding(.leading, 16).padding(.trailing, 30).padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .overlay(alignment: .top) { Rectangle().fill(BattleTheme.panelLine).frame(height: 1) }
    }
}

// MARK: - Shared bits

struct TypeChip: View {
    let type: BattleType
    var body: some View {
        Text(type.rawValue.uppercased())
            .arenaFont(10, .heavy, .rounded)
            .tracking(0.5)
            .foregroundStyle(Color(hex: 0x0C130F))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 3.5)
            .background(Lean(amount: 4).fill(type.color))
    }
}

/// A round portrait — the friend's real photo when present, else a type-tinted monogram.
struct PortraitCircle: View {
    let portrait: BattlePortrait
    let type: BattleType
    let monogram: String
    var size: CGFloat = 68

    init(friend: Catch?, type: BattleType, monogram: String, size: CGFloat = 68) {
        self.portrait = BattlePortrait(friend: friend)
        self.type = type
        self.monogram = monogram
        self.size = size
    }

    var body: some View {
        PortraitFill(portrait: portrait, color: type.color, monogram: monogram)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(portrait.image != nil ? type.color : .white.opacity(0.18),
                                     lineWidth: portrait.image != nil ? 3 : 1))
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
