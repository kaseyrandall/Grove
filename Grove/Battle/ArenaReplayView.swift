import SwiftUI

// MARK: - Battlegrounds palette (a committed dark arena)

/// Battlegrounds runs dark by default — its own self-contained palette, separate
/// from Grove's soft daylight `Theme`.
private enum Arena {
    static let ink      = Color(hex: 0xEAF3EC)
    static let muted    = Color(hex: 0x8FAE9C)
    static let panel    = Color(hex: 0x132019)
    static let panelLo  = Color(hex: 0x0E1712)
    static let panelLine = Color(hex: 0x294536)
    static let gold     = Color(hex: 0xF3D17A)
    static let leaf     = Color(hex: 0x6FC07A)
    static let leafDeep = Color(hex: 0x3F9A58)
    static let sta      = Color(hex: 0x5FC7D6)
    static let hpGood   = Color(hex: 0x6FC07A)
    static let hpMid    = Color(hex: 0xF0C24B)
    static let hpLow    = Color(hex: 0xE8654F)
    static let dmg      = Color(hex: 0xFFD9CF)
    static let heal     = Color(hex: 0xC8F5CF)

    static var background: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x0E1A14), Color(hex: 0x0A130F)],
                       startPoint: .top, endPoint: .bottom)
    }
    static var stage: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x16261D), Color(hex: 0x0A1310)],
                       startPoint: .top, endPoint: .bottom)
    }
}

private extension BattleType {
    var color: Color {
        switch self {
        case .hearth: return Color(hex: 0xE8743B)
        case .bloom:  return Color(hex: 0xEC7FB0)
        case .tide:   return Color(hex: 0x3F82CF)
        case .shore:  return Color(hex: 0x63C2C9)
        case .meadow: return Color(hex: 0x6FB84A)
        case .timber: return Color(hex: 0xA9834F)
        case .gale:   return Color(hex: 0x8FB6D6)
        case .feral:  return Color(hex: 0xA96FD0)
        }
    }
}

private extension Color {
    /// Darken toward black by `amount` (0…1) — for the token's shaded underside.
    func darkened(_ amount: Double = 0.4) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let f = 1 - amount
        return Color(.sRGB, red: r * f, green: g * f, blue: b * f, opacity: a)
    }
}

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
    @State private var hurtX: [CGFloat] = [0, 0]
    @State private var hurtOpacity: [Double] = [1, 1]
    @State private var stageOffset: CGSize = .zero

    private let speeds: [Double] = [1, 2, 3.25]
    private var speed: Double { speeds[speedIndex] }

    init(result: BattleResult) {
        self.result = result
        _hp = State(initialValue: [result.fighters[0].maxHP, result.fighters[1].maxHP])
        _sta = State(initialValue: [result.fighters[0].maxStamina, result.fighters[1].maxStamina])
    }

    var body: some View {
        ZStack {
            Arena.background.ignoresSafeArea()

            VStack(spacing: 12) {
                stage
                    .offset(stageOffset)
                messageBox
                controls
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if showBanner { banner.transition(.opacity) }
        }
        .navigationTitle("Arena")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { typewrite("Tap play to watch the match.") }
        .onDisappear { driver?.cancel(); typingTask?.cancel() }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Arena.stage)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )

            roundPips
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)

            plate(side: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding([.top, .leading], 14)
            plate(side: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding([.bottom, .trailing], 14)

            fighter(side: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 92).padding(.trailing, 44)
            fighter(side: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 92).padding(.leading, 34)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var roundPips: some View {
        HStack(spacing: 5) {
            ForEach(0..<result.turns, id: \.self) { i in
                Circle()
                    .fill(i < round ? Arena.gold : .white.opacity(0.14))
                    .frame(width: 7, height: 7)
                    .shadow(color: i < round ? Arena.gold.opacity(0.8) : .clear, radius: 4)
            }
        }
    }

    // MARK: Nameplate

    private func plate(side: Int) -> some View {
        let f = result.fighters[side]
        let frac = Double(hp[side]) / Double(max(1, f.maxHP))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(f.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Arena.ink)
                Text("Lv\(f.level)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Arena.muted)
                Spacer(minLength: 4)
                Text(f.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(Color(hex: 0x0C130F))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(f.type.color))
            }
            Text(f.archetype.rawValue.capitalized)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(Arena.muted)

            hpBar(frac: frac)
            Text("\(max(0, hp[side])) / \(f.maxHP)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Arena.ink)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            if side == 0 { staminaBar(side: side) }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(width: 188, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Arena.panel, Arena.panelLo], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Arena.panelLine, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }

    private func hpBar(frac: Double) -> some View {
        GeometryReader { geo in
            let color = frac > 0.5 ? Arena.hpGood : (frac > 0.22 ? Arena.hpMid : Arena.hpLow)
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.4))
                Capsule().fill(color)
                    .frame(width: max(0, geo.size.width * frac))
            }
        }
        .frame(height: 9)
    }

    private func staminaBar(side: Int) -> some View {
        let f = result.fighters[side]
        let frac = Double(sta[side]) / Double(max(1, f.maxStamina))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(Arena.sta.opacity(0.85))
                    .frame(width: max(0, geo.size.width * frac))
            }
        }
        .frame(height: 5)
        .padding(.top, 1)
    }

    // MARK: Fighter token

    private func fighter(side: Int) -> some View {
        let f = result.fighters[side]
        let big = side == 0
        let size: CGFloat = big ? 104 : 78
        return VStack(spacing: 6) {
            TokenView(letter: String(f.name.prefix(1)), color: f.type.color, size: size)
                .shadow(color: activeSide == side ? Arena.gold.opacity(0.9) : .clear,
                        radius: activeSide == side ? 16 : 0)
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
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Arena.panel, Arena.panelLo], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Arena.panelLine, lineWidth: 1))

            HStack(alignment: .top, spacing: 3) {
                Text(message)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Arena.ink)
                BlinkingCursor()
            }
            .padding(.horizontal, 15).padding(.vertical, 14)

            Text("Round \(round)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(Color(hex: 0x0C130F))
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(Capsule().fill(Arena.gold))
                .offset(x: 14, y: -10)
        }
        .frame(height: 84)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 8) {
            ctlButton(system: "arrow.counterclockwise", label: "Restart") { restart() }
            Button(action: toggle) {
                Image(systemName: idx >= result.events.count ? "arrow.counterclockwise" : (playing ? "pause.fill" : "play.fill"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: 0x07130B))
                    .frame(width: 54, height: 40)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Arena.leaf, Arena.leafDeep], startPoint: .top, endPoint: .bottom)))
            }
            .buttonStyle(.plain)
            ctlButton(system: "forward.end.fill", label: "Step") { stepOnce() }

            Spacer()

            Button { speedIndex = (speedIndex + 1) % speeds.count } label: {
                HStack(spacing: 5) {
                    Text("Speed").font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Arena.muted)
                    Text(speedLabel).font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Arena.gold)
                }
                .padding(.horizontal, 14).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hex: 0x1C2C23))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color(hex: 0x2C4A3A), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(hex: 0x101A15))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Arena.panelLine, lineWidth: 1)))
    }

    private var speedLabel: String {
        speed == 3.25 ? "3¼×" : "\(Int(speed))×"
    }

    private func ctlButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Arena.ink)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hex: 0x1C2C23))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color(hex: 0x2C4A3A), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Win banner

    private var banner: some View {
        let winnerName: String? = { if case .win(let n) = result.outcome { return n } else { return nil } }()
        let winnerFighter = result.fighters.first { $0.name == winnerName }
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 4) {
                Text("🏆").font(.system(size: 44))
                Text(winnerName.map { "\($0) wins!" } ?? "A draw")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(Arena.ink)
                Text(winnerFighter.map { "\($0.archetype.rawValue.capitalized) · \(result.turns) rounds" }
                     ?? "\(result.turns) rounds")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Arena.muted)
                Button { restart() } label: {
                    Text("Watch again")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x0C130F))
                        .padding(.horizontal, 26).padding(.vertical, 11)
                        .background(Capsule().fill(LinearGradient(colors: [Arena.gold, Color(hex: 0xDCAE4E)], startPoint: .top, endPoint: .bottom)))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
        }
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
                spawnFloat(side: side, text: "-\(d)", color: Arena.dmg, big: d >= 35)
                flinch(side)
                if d >= 35 { shakeStage() }
            } else if after > before {
                spawnFloat(side: side, text: "+\(after - before)", color: Arena.heal, big: false)
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
        let dx: CGFloat = side == 0 ? 46 : -46
        let dy: CGFloat = side == 0 ? -34 : 34
        withAnimation(.easeOut(duration: 0.16)) { lungeOffset[side] = CGSize(width: dx, height: dy) }
        withAnimation(.easeIn(duration: 0.22).delay(0.16)) { lungeOffset[side] = .zero }
    }

    private func flinch(_ side: Int) {
        withAnimation(.easeInOut(duration: 0.09)) { hurtOpacity[side] = 0.3 }
        withAnimation(.easeInOut(duration: 0.12).delay(0.09)) { hurtOpacity[side] = 1 }
        withAnimation(.easeInOut(duration: 0.06)) { hurtX[side] = -6 }
        withAnimation(.easeInOut(duration: 0.06).delay(0.1)) { hurtX[side] = 6 }
        withAnimation(.easeInOut(duration: 0.06).delay(0.2)) { hurtX[side] = 0 }
    }

    private func shakeStage() {
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
    @State private var bob = false

    var body: some View {
        ZStack {
            // ears
            ear.offset(x: -size * 0.28, y: -size * 0.42)
            ear.offset(x: size * 0.28, y: -size * 0.42)
            Circle()
                .fill(RadialGradient(colors: [color, color.darkened(0.45)],
                                     center: .init(x: 0.35, y: 0.3),
                                     startRadius: 2, endRadius: size))
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
            Text(letter)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: 0x0C130F).opacity(0.85))
        }
        .frame(width: size, height: size)
        .offset(y: bob ? -5 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    private var ear: some View {
        Circle()
            .fill(color.darkened(0.35))
            .frame(width: size * 0.32, height: size * 0.32)
    }
}

// MARK: - Floating number

private struct FloaterView: View {
    let floater: Floater
    @State private var up = false
    var body: some View {
        Text(floater.text)
            .font(.system(size: floater.big ? 34 : 28, weight: .bold, design: .rounded))
            .foregroundStyle(floater.color)
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
        Text(badge.text)
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(fg)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(bg))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shown = true } }
    }

    private var bg: AnyShapeStyle {
        switch badge.style {
        case .edge:    return AnyShapeStyle(LinearGradient(colors: [Arena.gold, Color(hex: 0xD9A94A)], startPoint: .top, endPoint: .bottom))
        case .resist:  return AnyShapeStyle(Color(hex: 0x2E3A45))
        case .miss:    return AnyShapeStyle(Color(hex: 0x3A4A41))
        case .feint:   return AnyShapeStyle(Color(hex: 0x2F4A3A))
        case .guardUp: return AnyShapeStyle(Color(hex: 0x2F4A55))
        case .daze:    return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xC9A4EC), Color(hex: 0xA96FD0)], startPoint: .top, endPoint: .bottom))
        case .blur:    return AnyShapeStyle(LinearGradient(colors: [Arena.sta, Color(hex: 0x3F9AA8)], startPoint: .top, endPoint: .bottom))
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
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Arena.gold)
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
