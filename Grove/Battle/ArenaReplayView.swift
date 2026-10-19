import SwiftUI


// MARK: - Transient overlays

private struct Floater: Identifiable {
    let id = UUID(); let side: Int; let text: String; let color: Color; let big: Bool
}
private struct BadgePop: Identifiable {
    enum Style { case edge, resist, miss, feint, guardUp, daze, blur }
    let id = UUID(); let side: Int; let text: String; let style: Style
}

// MARK: - Arena replay

/// Plays a finished `BattleResult` back beat-by-beat: HP bars drain, numbers pop,
/// fighters lunge and flinch, and the message box types out the same event stream
/// the engine produced. Deterministic in, cinematic out.
struct ArenaReplayView: View {
    let result: BattleResult
    private let portraits: [BattlePortrait]

    // playback
    @State private var idx = 0
    @State private var playing = false
    @State private var speedIndex = 0
    @State private var driver: Task<Void, Never>?
    @State private var typingTask: Task<Void, Never>?

    // displayed state
    @State private var hp: [Int]
    @State private var sta: [Int]
    @State private var round = 1
    @State private var message = ""
    @State private var activeSide: Int?
    @State private var showBanner = false

    // effects
    @State private var floats: [Floater] = []
    @State private var badges: [BadgePop] = []
    @State private var lungeOffset: [CGSize] = [.zero, .zero]
    /// Reduce Motion keeps the flinch's fade but drops lunges and shakes.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hurtX: [CGFloat] = [0, 0]
    @State private var hurtOpacity: [Double] = [1, 1]
    @State private var stageOffset: CGSize = .zero
    /// The name cards' measured sizes ([yours, rival's]), for placing fighters.
    @State private var plateSize: [CGSize] = [CGSize(width: 236, height: 150), CGSize(width: 286, height: 110)]
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Double] = [1, 2, 3.25]
    private var speed: Double { speeds[speedIndex] }

    init(result: BattleResult, portraits: [BattlePortrait] = [.none, .none]) {
        self.result = result
        self.portraits = (0..<2).map { i in portraits.indices.contains(i) ? portraits[i] : .none }
        _hp = State(initialValue: [result.fighters[0].maxHP, result.fighters[1].maxHP])
        _sta = State(initialValue: [result.fighters[0].maxStamina, result.fighters[1].maxStamina])
    }

    var body: some View {
        ZStack {
            MatchDayBackdrop()

            VStack(spacing: 12) {
                stage
                    .offset(stageOffset)
                messageBox
                controls
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            // On iPad, keep the match phone-shaped in the middle.
            .frame(maxWidth: 520, maxHeight: 940)

            if showBanner { banner.transition(.opacity) }
        }
        .navigationTitle("Arena")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .groveTabBarHidden()
        .onAppear { typewrite("Tap play to watch the match.") }
        .onDisappear { driver?.cancel(); typingTask?.cancel() }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            // Each side's light: red behind the rival, mint behind you.
            // (Spilling past the stage, so they fade out instead of stopping at an edge.)
            RadialGradient(colors: [BattleTheme.foe.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.8, y: 0.32), startRadius: 0, endRadius: 230)
                .padding(-60)
            RadialGradient(colors: [BattleTheme.leaf.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.2, y: 0.68), startRadius: 0, endRadius: 230)
                .padding(-60)
            LinearGradient(colors: [.clear, .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
                .rotationEffect(.degrees(-14))
                .padding(.horizontal, -60)
            Text("VS")
                .arenaDisplay(40)
                .foregroundStyle(.white.opacity(0.1))
                .accessibilityHidden(true)

            roundPips
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
            plate(side: 1)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { plateSize[1] = $0 }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, pipsHeight)
            plate(side: 0)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { plateSize[0] = $0 }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, 10)

            // The fighters fill what the name cards leave: rival up right,
            // yours down left, always a diagonal and never over a card.
            GeometryReader { g in
                let spot = fighterSpots(in: g.size)
                fighter(side: 1, size: spot.rival)
                    .position(spot.rivalCenter)
                fighter(side: 0, size: spot.mine)
                    .position(spot.mineCenter)
            }
        }
    }

    /// Space the round counter takes at the top of the stage.
    private let pipsHeight: CGFloat = 44

    /// Sizes and centers for the two fighters on a stage of `size`, given the
    /// name cards' measured sizes. Starts big and shrinks until both fit
    /// clear of the cards with the rival higher than your friend.
    private func fighterSpots(in size: CGSize) -> (rival: CGFloat, mine: CGFloat, rivalCenter: CGPoint, mineCenter: CGPoint) {
        let w = size.width, h = size.height
        let foeCard = plateSize[1], myCard = plateSize[0]
        let foeCardBottom = pipsHeight + foeCard.height + 8
        let myCardTop = h - 10 - myCard.height - 8
        let ratio: CGFloat = 150 / 128
        let tall: (CGFloat) -> CGFloat = { $0 * 1.1 + 16 }
        var scale: CGFloat = 1.15
        while true {
            let rival = 128 * scale, mine = 150 * scale
            let rivalLeft = w - 18 - rival, mineRight = 12 + mine
            // Rival: beside its card if there's room, else below it; never
            // down into your card's corner.
            let rivalTop = rivalLeft > foeCard.width + 8 ? pipsHeight : foeCardBottom
            let rivalBottomLimit = rivalLeft < w - myCard.width ? myCardTop : h
            // Yours: beside your card if there's room, else above it; never
            // up into the rival card's corner.
            let mineBottom = mineRight < w - myCard.width - 8 ? h - 4 : myCardTop
            let mineTopLimit = mineRight > foeCard.width ? foeCardBottom : pipsHeight
            let rivalY = rivalTop + tall(rival) / 2
            let mineY = mineBottom - tall(mine) / 2
            let fits = rivalTop + tall(rival) <= rivalBottomLimit
                && mineBottom - tall(mine) >= mineTopLimit
                && mineY - rivalY >= mine * 0.25
                && rival + mine + 30 <= w
            if fits || scale <= 0.45 {
                return (rival, rival * ratio, CGPoint(x: w - 18 - rival / 2, y: rivalY),
                        CGPoint(x: 12 + mine / 2, y: mineY))
            }
            scale -= 0.05
        }
    }

    /// "ROUND 2 OF 6", with a slim leaning bar filling as it goes.
    private var roundPips: some View {
        let shown = min(max(round, 1), result.turns)
        return VStack(spacing: 5) {
            Text("ROUND \(shown) OF \(result.turns)")
                .arenaDisplay(19)
                .foregroundStyle(BattleTheme.muted)
                .monospacedDigit()
            LeanBar(fraction: Double(shown) / Double(max(1, result.turns)), color: BattleTheme.gold, height: 3)
                .frame(width: 110)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Round \(shown) of \(result.turns)")
    }

    // MARK: Nameplate

    private func plate(side: Int) -> some View {
        let f = result.fighters[side]
        let frac = Double(hp[side]) / Double(max(1, f.maxHP))
        let mine = side == 0
        let tint = mine ? BattleTheme.leaf : BattleTheme.foe
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(f.name.uppercased())
                    .arenaDisplay(27)
                    .foregroundStyle(BattleTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if mine {
                    Text("LV \(f.level)").arenaDisplay(16).foregroundStyle(BattleTheme.muted).fixedSize()
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if !mine {
                    Text("LV \(f.level)").arenaDisplay(16).foregroundStyle(BattleTheme.muted).fixedSize()
                }
                Text(f.archetype.rawValue.uppercased())
                    .arenaFont(11, .bold, .rounded)
                    .tracking(0.5)
                    .foregroundStyle(BattleTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(f.type.rawValue.uppercased())
                    .arenaFont(9.5, .bold, .rounded)
                    .tracking(1)
                    .foregroundStyle(Color(hex: 0x08110C))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Lean(amount: 4).fill(f.type.color))
            }

            LeanBar(fraction: frac, color: tint, height: 10).padding(.top, 5)
            // Like the classic games: your HP in numbers, the rival's as a bar.
            if mine {
                HStack(alignment: .firstTextBaseline) {
                    Text("HP").arenaFont(10, .bold, .rounded).tracking(2).foregroundStyle(BattleTheme.muted)
                    Spacer()
                    Text("\(max(0, hp[side])) / \(f.maxHP)")
                        .arenaDisplay(24)
                        .foregroundStyle(BattleTheme.ink)
                        .monospacedDigit()
                }
                staminaBar(side: side)
            }
        }
        .padding(.leading, mine ? 26 : 16).padding(.trailing, mine ? 16 : 26)
        .padding(.vertical, 11)
        .frame(width: mine ? 236 : 286, alignment: .leading)
        .background(
            (mine ? Slant(lead: 14) : Slant(trail: 14))
                .fill(Color(hex: 0x09140F).opacity(0.92))
        )
        .overlay(alignment: mine ? .trailing : .leading) {
            Rectangle().fill(tint).frame(width: 3)
        }
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }

    private func staminaBar(side: Int) -> some View {
        let f = result.fighters[side]
        let frac = Double(sta[side]) / Double(max(1, f.maxStamina))
        return LeanBar(fraction: frac, color: BattleTheme.sta, height: 4).padding(.top, 2)
    }

    // MARK: Fighter token

    private func fighter(side: Int, size: CGFloat) -> some View {
        let f = result.fighters[side]
        let big = side == 0
        return VStack(spacing: 6) {
            TokenView(letter: String(f.name.prefix(1)), color: f.type.color, size: size, portrait: portraits[side],
                      ring: side == 0 ? BattleTheme.leaf : BattleTheme.foe)
                .shadow(color: activeSide == side ? BattleTheme.gold.opacity(0.9) : .clear,
                        radius: activeSide == side ? 18 : 0)
                .offset(lungeOffset[side])
                .offset(x: hurtX[side])
                .opacity(hurtOpacity[side])
                .overlay(alignment: .top) { reactions(side: side, big: big) }
            Ellipse().fill(.black.opacity(0.45))
                .frame(width: size * 0.66, height: 10)
                .blur(radius: 4)
                .offset(y: -2)
        }
    }

    private func reactions(side: Int, big: Bool) -> some View {
        ZStack {
            ForEach(badges.filter { $0.side == side }) { BadgeView(badge: $0) }
                .offset(y: -34)
            ForEach(floats.filter { $0.side == side }) { FloaterView(floater: $0) }
                .offset(y: -6)
        }
        .frame(width: 160, height: 60)
        .allowsHitTesting(false)
    }

    // MARK: Message box

    private var messageBox: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ROUND \(round)")
                .arenaDisplay(13)
                .foregroundStyle(BattleTheme.gold)
            HStack(alignment: .top, spacing: 3) {
                Text(message)
                    .arenaFont(16, .bold, .rounded)
                    .foregroundStyle(BattleTheme.ink)
                BlinkingCursor()
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 16).padding(.trailing, 22).padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .topLeading)
        .background(Slant(trail: 12).fill(Color(hex: 0x09140F).opacity(0.92)))
        .overlay(alignment: .leading) { Rectangle().fill(BattleTheme.gold).frame(width: 3) }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 8) {
            ctlButton(system: "arrow.counterclockwise", label: "Restart") { restart() }
            Button(action: toggle) {
                Image(systemName: idx >= result.events.count ? "arrow.counterclockwise" : (playing ? "pause.fill" : "play.fill"))
                    .arenaFont(17, .bold)
                    .foregroundStyle(Color(hex: 0x04130C))
                    .frame(width: 76, height: 46)
                    .background(Lean(amount: 9).fill(LinearGradient(colors: [BattleTheme.leaf, BattleTheme.leafDeep],
                                                                    startPoint: .top, endPoint: .bottom)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? "Pause" : "Play")
            ctlButton(system: "forward.end.fill", label: "Step") { stepOnce() }

            Spacer()

            Button { speedIndex = (speedIndex + 1) % speeds.count } label: {
                (Text("SPEED ").foregroundStyle(BattleTheme.muted) + Text(speedLabel).foregroundStyle(BattleTheme.gold))
                    .arenaDisplay(17)
                    .padding(.horizontal, 20).frame(height: 46)
                    .background(Lean(amount: 9).fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speed \(speedLabel)")
        }
    }

    private var speedLabel: String {
        speed == 3.25 ? "3¼×" : "\(Int(speed))×"
    }

    private func ctlButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .arenaFont(15, .bold)
                .foregroundStyle(BattleTheme.ink)
                .frame(width: 54, height: 46)
                .background(Lean(amount: 9).fill(.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Result screen

    private var banner: some View {
        // Side 0 is always the player's friend, so the result reads from their side.
        let you = result.fighters[0]
        let youWon = result.winner == 0
        let youLost = result.winner == 1
        let title = youWon ? "Victory" : (youLost ? "Tuckered out" : "Draw")
        let tint = youWon ? BattleTheme.leaf : (youLost ? BattleTheme.foe : BattleTheme.gold)
        let sub = youWon ? "\(you.name) wins in \(result.turns) rounds"
                : (youLost ? "\(you.name) needs a nap" : "\(result.turns) rounds, dead even")
        let xp = BattleRoster.MatchOutcome(result).xp
        return ZStack {
            MatchDayBackdrop(glow: tint)
            Color.black.opacity(0.25).ignoresSafeArea()
            // A streak of light behind the cards.
            Capsule()
                .fill(LinearGradient(colors: [.clear, tint, .white, tint, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 4)
                .blur(radius: 1)
                .shadow(color: tint.opacity(0.6), radius: 24)
                .rotationEffect(.degrees(-8))
                .padding(.horizontal, -60)
                .offset(y: -130)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .arenaDisplay(youLost ? 54 : 72)
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.45), radius: 24)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(sub.uppercased())
                    .arenaFont(13, .bold, .rounded)
                    .tracking(1.5)
                    .foregroundStyle(BattleTheme.muted)
                    .padding(.top, 6)

                Spacer(minLength: 20)
                HStack(spacing: 14) {
                    resultCard(side: 0)
                    resultCard(side: 1)
                }
                Spacer(minLength: 20)

                HStack(alignment: .firstTextBaseline) {
                    Text("+\(xp) XP").arenaDisplay(24).foregroundStyle(BattleTheme.ink)
                    Spacer()
                    Text("EARNED").arenaFont(11, .bold, .rounded).tracking(2).foregroundStyle(BattleTheme.muted)
                }
                LeanBar(fraction: 1, color: BattleTheme.gold, height: 6).padding(.top, 8)

                HStack(spacing: 10) {
                    Button { restart() } label: { LeanButtonFace(text: "Watch again", style: .quiet, height: 54, size: 20) }
                        .buttonStyle(.plain)
                    Button { dismiss() } label: { LeanButtonFace(text: "Done", style: .reward, height: 54, size: 20) }
                        .buttonStyle(.plain)
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12).padding(.bottom, 16)
        }
    }

    /// One fighter's card on the result screen: face, name, their biggest hit.
    private func resultCard(side: Int) -> some View {
        let f = result.fighters[side]
        let tint = side == 0 ? BattleTheme.leaf : BattleTheme.foe
        let best = result.events.compactMap { e -> (damage: Int, move: String)? in
            guard e.actor == side, case .strike(let move, let damage, _) = e.kind else { return nil }
            return (damage, move)
        }.max { $0.damage < $1.damage }
        let name = f.name.hasPrefix("Wild ") ? String(f.name.dropFirst(5)) : f.name
        return VStack(spacing: 4) {
            HexPortrait(portrait: portraits[side], color: f.type.color,
                        monogram: String(f.name.prefix(1)), width: 92, artScale: 0.66)
                .padding(.bottom, 8)
            Text(name.uppercased())
                .arenaDisplay(24)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(best?.damage ?? 0)")
                .arenaDisplay(54)
                .foregroundStyle(BattleTheme.ink)
                .monospacedDigit()
            Text("BIGGEST HIT")
                .arenaFont(10.5, .bold, .rounded)
                .tracking(1.5)
                .foregroundStyle(tint)
            Text("\((best?.move ?? "—").uppercased()) · HP \(max(0, hp[side]))")
                .arenaFont(10, .bold, .rounded)
                .tracking(1)
                .foregroundStyle(BattleTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 16).padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle().fill(Color(hex: 0x09140F).opacity(0.94))
                .overlay(Rectangle().fill(tint.opacity(0.08)))
        )
        .overlay(Rectangle().stroke(tint, lineWidth: 2))
        .shadow(color: tint.opacity(0.45), radius: 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Playback

    private func toggle() {
        if idx >= result.events.count { restart(); return }
        if playing { driver?.cancel(); playing = false }
        else { start() }
    }

    private func start() {
        playing = true
        driver?.cancel()
        driver = Task { @MainActor in
            while idx < result.events.count {
                if Task.isCancelled { return }
                let e = result.events[idx]; idx += 1
                apply(e)
                let step = max(14.0, 27.0 / speed)
                let typeMs = Double(e.text.count) * step
                let dwell = isSlowBeat(e.kind) ? 1300.0 : 980.0
                try? await Task.sleep(for: .milliseconds(Int(typeMs + dwell / speed)))
                if Task.isCancelled { return }
            }
            finish()
        }
    }

    private func stepOnce() {
        driver?.cancel(); playing = false
        if idx >= result.events.count { finish(); return }
        let e = result.events[idx]; idx += 1
        apply(e)
    }

    private func restart() {
        driver?.cancel(); typingTask?.cancel(); playing = false
        idx = 0; round = 1; activeSide = nil; showBanner = false
        floats = []; badges = []
        hp = [result.fighters[0].maxHP, result.fighters[1].maxHP]
        sta = [result.fighters[0].maxStamina, result.fighters[1].maxStamina]
        typewrite("The friends face off…")
        driver = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            if Task.isCancelled { return }
            start()
        }
    }

    private func finish() {
        playing = false; activeSide = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showBanner = true }
    }

    private func isSlowBeat(_ k: ReplayEvent.Kind) -> Bool {
        if case .strike = k { return true }
        if case .heal = k { return true }
        return false
    }

    // MARK: Apply one beat

    private func apply(_ e: ReplayEvent) {
        round = e.round
        activeSide = e.actor
        typewrite(e.text)

        // HP deltas → floats + flinch, straight off the snapshot.
        for side in 0..<2 {
            let before = hp[side], after = max(0, e.hpAfter[side])
            if after < before {
                let d = before - after
                spawnFloat(side: side, text: "-\(d)", color: BattleTheme.dmg, big: d >= 35)
                flinch(side)
                if d >= 35 { shakeStage() }
            } else if after > before {
                spawnFloat(side: side, text: "+\(after - before)", color: BattleTheme.heal, big: false)
            }
        }
        withAnimation(.easeOut(duration: 0.5)) {
            hp = [max(0, e.hpAfter[0]), max(0, e.hpAfter[1])]
            sta = [max(0, e.staminaAfter[0]), max(0, e.staminaAfter[1])]
        }

        let foe = 1 - e.actor
        switch e.kind {
        case .strike(_, _, let eff):
            lunge(e.actor)
            if eff == .advantaged { spawnBadge(side: foe, text: "TYPE EDGE", style: .edge) }
            else if eff == .resisted { spawnBadge(side: foe, text: "resisted", style: .resist) }
        case .miss:        spawnBadge(side: foe, text: "MISS", style: .miss)
        case .feint:       spawnBadge(side: e.actor, text: "Feint ✦", style: .feint)
        case .brace:       spawnBadge(side: e.actor, text: "Guard ▲", style: .guardUp)
        case .stunApplied: spawnBadge(side: foe, text: "DAZED ✦", style: .daze)
        case .dazedSkip:   spawnBadge(side: e.actor, text: "z z z", style: .daze)
        case .shrugOff:    spawnBadge(side: foe, text: "shrug off", style: .guardUp)
        case .extraMove:   spawnBadge(side: e.actor, text: "BLUR »", style: .blur)
        case .heal, .catchBreath, .winded: break
        }
    }

    // MARK: Effects

    private func typewrite(_ text: String) {
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            message = ""
            let step = Int(max(14.0, 27.0 / speed))
            for ch in text {
                if Task.isCancelled { return }
                message.append(ch)
                try? await Task.sleep(for: .milliseconds(step))
            }
        }
    }

    private func spawnFloat(side: Int, text: String, color: Color, big: Bool) {
        let f = Floater(side: side, text: text, color: color, big: big)
        floats.append(f)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1050))
            floats.removeAll { $0.id == f.id }
        }
    }

    private func spawnBadge(side: Int, text: String, style: BadgePop.Style) {
        let b = BadgePop(side: side, text: text, style: style)
        badges.append(b)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeOut(duration: 0.2)) { badges.removeAll { $0.id == b.id } }
        }
    }

    private func lunge(_ side: Int) {
        guard !reduceMotion else { return }
        let dx: CGFloat = side == 0 ? 46 : -46
        let dy: CGFloat = side == 0 ? -34 : 34
        withAnimation(.easeOut(duration: 0.16)) { lungeOffset[side] = CGSize(width: dx, height: dy) }
        withAnimation(.easeIn(duration: 0.22).delay(0.16)) { lungeOffset[side] = .zero }
    }

    private func flinch(_ side: Int) {
        withAnimation(.easeInOut(duration: 0.09)) { hurtOpacity[side] = 0.3 }
        withAnimation(.easeInOut(duration: 0.12).delay(0.09)) { hurtOpacity[side] = 1 }
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.06)) { hurtX[side] = -6 }
        withAnimation(.easeInOut(duration: 0.06).delay(0.1)) { hurtX[side] = 6 }
        withAnimation(.easeInOut(duration: 0.06).delay(0.2)) { hurtX[side] = 0 }
    }

    private func shakeStage() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.06)) { stageOffset = CGSize(width: 5, height: -3) }
        withAnimation(.easeInOut(duration: 0.06).delay(0.06)) { stageOffset = CGSize(width: -5, height: 3) }
        withAnimation(.easeInOut(duration: 0.06).delay(0.12)) { stageOffset = CGSize(width: 3, height: 2) }
        withAnimation(.easeInOut(duration: 0.06).delay(0.18)) { stageOffset = .zero }
    }
}

// MARK: - Token

private struct TokenView: View {
    let letter: String
    let color: Color
    let size: CGFloat
    var portrait: BattlePortrait = .none
    /// The side's color: mint for you, red for the rival.
    var ring: Color = BattleTheme.leaf
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        HexPortrait(portrait: portrait, color: color, monogram: letter, width: size, ring: ring, artScale: 0.68)
            .shadow(color: ring.opacity(0.35), radius: 18)
            .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
            .offset(y: bob ? -5 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}

// MARK: - Floating number

private struct FloaterView: View {
    let floater: Floater
    @State private var up = false
    var body: some View {
        Text(floater.text)
            .arenaDisplay(floater.big ? 46 : 36)
            .foregroundStyle(floater.color)
            .shadow(color: floater.color.opacity(0.7), radius: 12)
            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            .offset(y: up ? -46 : 4)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { up = true } }
    }
}

// MARK: - Badge

private struct BadgeView: View {
    let badge: BadgePop
    @State private var shown = false

    var body: some View {
        Text(badge.text.uppercased())
            .arenaDisplay(15)
            .foregroundStyle(fg)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Lean(amount: 6).fill(bg))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shown = true } }
    }

    private var bg: AnyShapeStyle {
        switch badge.style {
        case .edge:    return AnyShapeStyle(LinearGradient(colors: [BattleTheme.gold, Color(hex: 0xD9A94A)], startPoint: .top, endPoint: .bottom))
        case .resist:  return AnyShapeStyle(Color(hex: 0x2E3A45))
        case .miss:    return AnyShapeStyle(Color(hex: 0x3A4A41))
        case .feint:   return AnyShapeStyle(Color(hex: 0x2F4A3A))
        case .guardUp: return AnyShapeStyle(Color(hex: 0x2F4A55))
        case .daze:    return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xC9A4EC), Color(hex: 0xA96FD0)], startPoint: .top, endPoint: .bottom))
        case .blur:    return AnyShapeStyle(LinearGradient(colors: [BattleTheme.sta, Color(hex: 0x3F9AA8)], startPoint: .top, endPoint: .bottom))
        }
    }
    private var fg: Color {
        switch badge.style {
        case .edge:    return Color(hex: 0x3A2A06)
        case .resist:  return Color(hex: 0xA9C4D6)
        case .miss:    return Color(hex: 0xCFE0D6)
        case .feint:   return Color(hex: 0xBFEECE)
        case .guardUp: return Color(hex: 0xBFE6EE)
        case .daze:    return Color(hex: 0x241033)
        case .blur:    return Color(hex: 0x062329)
        }
    }
}

// MARK: - Blinking cursor

private struct BlinkingCursor: View {
    @State private var on = true
    var body: some View {
        Text("▸")
            .arenaFont(15, .bold, .rounded)
            .foregroundStyle(BattleTheme.gold)
            .opacity(on ? 1 : 0)
            .onAppear { withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) { on = false } }
    }
}

// MARK: - Demo host (a canned match, for dev preview)

struct ArenaDemoView: View {
    private let result: BattleResult = {
        let a = BattleCard(name: "Robin",  type: .bloom,  archetype: .skirmisher, level: 18)
        let b = BattleCard(name: "Badger", type: .timber, archetype: .bruiser,    level: 18)
        return simulate(a, .defaultPlan(for: .skirmisher), vs: b, .defaultPlan(for: .bruiser), seed: 11)
    }()
    var body: some View { ArenaReplayView(result: result) }
}

#Preview {
    NavigationStack { ArenaDemoView() }
}
