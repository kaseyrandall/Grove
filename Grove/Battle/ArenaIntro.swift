import SwiftUI

// MARK: - First-run intro

/// Three quick screens the first time someone opens the Arena (and again
/// from the ⓘ button): friends can fight, habitats matter, send-wait-watch.
struct ArenaIntroView: View {
    /// Friends to show on the first screen (the team, or the Grove's best).
    let friends: [Catch]
    /// The habitat the wheel is centered on.
    let featured: BattleType
    var finishTitle = "Build my team"
    let onFinish: () -> Void

    @State private var page = 0
    private let pages = 3

    var body: some View {
        ZStack {
            MatchDayBackdrop()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { onFinish() }
                        .arenaFont(15, .semibold, .rounded)
                        .foregroundStyle(BattleTheme.muted)
                        .opacity(page < pages - 1 ? 1 : 0)
                        .disabled(page >= pages - 1)
                }
                .padding(.horizontal, 20).padding(.top, 8)

                dots.padding(.top, 14)

                TabView(selection: $page) {
                    IntroPage(title: "Your friends", accent: "can now fight",
                              text: "Pick three friends from your Grove for your Arena team. Each fights its own way, set by its kind.") {
                        TeamFan(friends: friends)
                    }
                    .tag(0)
                    IntroPage(title: "Habitats", accent: "matter",
                              text: "Every friend fights for the habitat it lives in. It hits the next two around the wheel harder, and takes more from the two before it.") {
                        HabitatWheel(featured: featured)
                    }
                    .tag(1)
                    IntroPage(title: "Send, wait,", accent: "then watch",
                              text: "No tapping in a fight: you set them up, they do the rest. They earn XP win or lose, and level up as they go.") {
                        MatchSteps()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Button {
                    if page < pages - 1 { withAnimation { page += 1 } } else { onFinish() }
                } label: {
                    LeanButtonFace(text: page < pages - 1 ? "Next" : finishTitle, style: .action, height: 56, size: 22)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages, id: \.self) { i in
                Lean(amount: 2)
                    .fill(i <= page ? BattleTheme.leaf : .white.opacity(0.15))
                    .frame(width: 24, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(page + 1) of \(pages)")
    }
}

private struct IntroPage<Art: View>: View {
    let title: String
    let accent: String
    let text: String
    @ViewBuilder let art: () -> Art

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: -4) {
                    Text(title.uppercased()).foregroundStyle(BattleTheme.ink)
                    Text(accent.uppercased()).foregroundStyle(BattleTheme.leaf)
                }
                .arenaDisplay(46)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityElement(children: .combine)
                Text(text)
                    .arenaFont(15, .semibold, .rounded)
                    .foregroundStyle(BattleTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22).padding(.bottom, 22)
        }
    }
}

/// Three friends as leaning team cards, fanned like a hand.
private struct TeamFan: View {
    let friends: [Catch]
    @State private var shown = false

    var body: some View {
        let picks = Array(friends.prefix(3))
        ZStack {
            ForEach(Array(picks.enumerated()), id: \.offset) { i, f in
                let spot = picks.count == 3 ? i - 1 : (picks.count == 2 ? (i == 0 ? -1 : 1) : 0)
                MiniCard(friend: f)
                    .rotationEffect(.degrees(Double(spot) * 9))
                    .offset(x: CGFloat(spot) * 114, y: spot == 0 ? -16 : 12)
                    .zIndex(spot == 0 ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.85)
                    .opacity(shown ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(i) * 0.08), value: shown)
            }
        }
        .onAppear { shown = true }
        .accessibilityHidden(true)
    }
}

/// A small leaning card: photo and name, outlined in the habitat color.
private struct MiniCard: View {
    let friend: Catch
    private var type: BattleType { BattleType(habitat: friend.effectiveZone) }
    private var shape: Slant { Slant(lead: 10, trail: 10) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PortraitFill(portrait: BattlePortrait(friend: friend), color: type.color,
                         monogram: String(friend.displayName.prefix(1)))
                .frame(width: 118, height: 132)
                .clipped()
                .overlay {
                    LinearGradient(colors: [.clear, BattleTheme.panel], startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: .bottom)
                }
            Text(friend.displayName.uppercased())
                .arenaDisplay(21)
                .foregroundStyle(BattleTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 16)
        }
        .frame(width: 118)
        .background(shape.fill(BattleTheme.panel))
        .clipShape(shape)
        .overlay(shape.stroke(type.color, lineWidth: 2))
        .shadow(color: type.color.opacity(0.5), radius: 16)
    }
}

/// The eight habitats as a ring. The featured one is lit, the two it beats
/// glow mint, the two that beat it glow red.
private struct HabitatWheel: View {
    let featured: BattleType

    var body: some View {
        let all = BattleType.allCases
        let n = all.count
        let fi = all.firstIndex(of: featured) ?? 0
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let ring = side - 86
            ZStack {
                ForEach(Array(all.enumerated()), id: \.offset) { i, t in
                    let role = role(for: (i - fi + n) % n, n: n)
                    let slice = 360.0 / Double(n)
                    Arc(start: .degrees(Double(i) * slice - 90 - slice / 2 + 2),
                        end: .degrees(Double(i) * slice - 90 + slice / 2 - 2))
                        .stroke(t.color.opacity(role == .neutral ? 0.28 : 1),
                                style: StrokeStyle(lineWidth: role == .featured ? 30 : 20))
                        .frame(width: ring, height: ring)
                        .shadow(color: role == .featured ? t.color.opacity(0.7) : .clear, radius: 14)
                    let mid = Double(i) * slice * .pi / 180 - .pi / 2
                    Text(t.rawValue.uppercased())
                        .arenaFont(9.5, .bold, .rounded)
                        .tracking(1)
                        .foregroundStyle(role.label)
                        .position(x: g.size.width / 2 + cos(mid) * (ring / 2 + 30),
                                  y: g.size.height / 2 + sin(mid) * (ring / 2 + 30))
                }
                // Inner arcs: mint over the two it beats, red over the two
                // it's weak to.
                let slice = 360.0 / Double(n)
                Arc(start: .degrees(Double(fi + 1) * slice - 90 - slice / 2 + 3),
                    end: .degrees(Double(fi + 2) * slice - 90 + slice / 2 - 3))
                    .stroke(BattleTheme.leaf, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: ring - 52, height: ring - 52)
                    .shadow(color: BattleTheme.leaf.opacity(0.8), radius: 6)
                Arc(start: .degrees(Double(fi - 2) * slice - 90 - slice / 2 + 3),
                    end: .degrees(Double(fi - 1) * slice - 90 + slice / 2 - 3))
                    .stroke(BattleTheme.foe, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: ring - 52, height: ring - 52)
                    .shadow(color: BattleTheme.foe.opacity(0.8), radius: 6)
                VStack(spacing: 6) {
                    Text(featured.rawValue.uppercased())
                        .arenaDisplay(28)
                        .foregroundStyle(featured.color)
                    HStack(spacing: 14) {
                        legend("1.25×", "Beats", BattleTheme.leaf)
                        legend("0.8×", "Weak to", BattleTheme.foe)
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .accessibilityElement()
        .accessibilityLabel("Habitat wheel. \(featured.rawValue.capitalized) beats the next two habitats and is weak to the two before it.")
    }

    private func role(for diff: Int, n: Int) -> Role {
        if diff == 0 { return .featured }
        if diff == 1 || diff == 2 { return .beats }
        if diff == n - 1 || diff == n - 2 { return .weak }
        return .neutral
    }

    private func legend(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value).arenaDisplay(17).foregroundStyle(color)
            Text(label.uppercased()).arenaFont(8.5, .bold, .rounded).tracking(1).foregroundStyle(BattleTheme.muted)
        }
    }

    enum Role {
        case featured, beats, weak, neutral
        var label: Color {
            switch self {
            case .featured: return BattleTheme.ink
            case .beats:    return BattleTheme.leaf
            case .weak:     return BattleTheme.foe
            case .neutral:  return BattleTheme.muted.opacity(0.55)
            }
        }
    }
}

private struct Arc: Shape {
    let start: Angle
    let end: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                 startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

/// Send → 20 min → Watch → Nap, as a short ladder.
private struct MatchSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            step("Send", "Off to a match", BattleTheme.leaf)
            step("20 min", "Back with a result", BattleTheme.gold)
            step("Watch", "Replay how it went", BattleTheme.gold)
            step("Nap", "Rest, then go again", BattleTheme.muted)
        }
        .padding(.horizontal, 22)
        .accessibilityElement(children: .combine)
    }

    private func step(_ word: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 14) {
            Text(word.uppercased())
                .arenaDisplay(26)
                .foregroundStyle(color)
                .frame(width: 96, alignment: .leading)
            Text(text)
                .arenaFont(15, .bold, .rounded)
                .foregroundStyle(BattleTheme.ink)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Slant(trail: 12).fill(Color(hex: 0x0A1712)))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
    }
}

// MARK: - Get set up

/// The four first steps, worked out from what the player has done (so it
/// can't fall out of step with the game).
struct ArenaSetup {
    var picked: Bool
    var sent: Bool
    var watched: Bool
    var fullTeam: Bool

    var doneCount: Int { [picked, sent, watched, fullTeam].filter { $0 }.count }
    var isComplete: Bool { doneCount == 4 }
}

/// "GET SET UP · 1 OF 4", then "YOU'RE ALL SET!" with a Got it.
struct SetupChecklist: View {
    let setup: ArenaSetup
    let onDismiss: () -> Void

    var body: some View {
        if setup.isComplete { allSet } else { steps }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GET SET UP · \(setup.doneCount) OF 4")
                .arenaDisplay(17)
                .foregroundStyle(BattleTheme.leaf)
            row("Pick your first fighter", done: setup.picked, now: !setup.picked)
            row("Send them to their first match", done: setup.sent, now: setup.picked && !setup.sent)
            row("Watch how it went", done: setup.watched, now: setup.sent && !setup.watched)
            row("Fill your team of three", done: setup.fullTeam, now: setup.watched && !setup.fullTeam)
        }
        .padding(.leading, 16).padding(.trailing, 24).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Slant(trail: 12).fill(LinearGradient(colors: [BattleTheme.leaf.opacity(0.10), BattleTheme.panel.opacity(0.92)],
                                                 startPoint: .leading, endPoint: UnitPoint(x: 0.45, y: 0.5)))
        )
        .overlay(alignment: .leading) { Rectangle().fill(BattleTheme.leaf).frame(width: 3) }
        .accessibilityElement(children: .combine)
    }

    private func row(_ text: String, done: Bool, now: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Lean(amount: 3).fill(done ? BattleTheme.leaf : .clear)
                Lean(amount: 3).stroke(done ? .clear : (now ? BattleTheme.leaf : BattleTheme.panelLine), lineWidth: 1.5)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: 0x04130C))
                }
            }
            .frame(width: 20, height: 18)
            .scaleEffect(done ? 1 : 0.85)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
            Text(text)
                .arenaFont(14, .bold, .rounded)
                .strikethrough(done, color: BattleTheme.muted)
                .foregroundStyle(done || !now ? BattleTheme.muted : BattleTheme.ink)
        }
        .accessibilityLabel("\(text), \(done ? "done" : "to do")")
    }

    private var allSet: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("YOU'RE ALL SET!")
                    .arenaDisplay(24)
                    .foregroundStyle(BattleTheme.gold)
                Spacer()
                Button("Got it", action: onDismiss)
                    .arenaFont(14, .bold, .rounded)
                    .foregroundStyle(BattleTheme.gold)
            }
            Text("Send friends whenever they're ready. Next, try a Battle Plan: it coaches how each friend fights. It's on their card.")
                .arenaFont(13.5, .semibold, .rounded)
                .foregroundStyle(BattleTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 16).padding(.trailing, 24).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Slant(trail: 12).fill(LinearGradient(colors: [BattleTheme.gold.opacity(0.16), BattleTheme.panel.opacity(0.92)],
                                                 startPoint: .leading, endPoint: UnitPoint(x: 0.5, y: 0.5)))
        )
        .overlay(alignment: .leading) { Rectangle().fill(BattleTheme.gold).frame(width: 3) }
    }
}

/// The nudge under the team: what to tap next.
struct CoachTip: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .arenaDisplay(20)
                .foregroundStyle(BattleTheme.ink)
            if let detail {
                Text(detail)
                    .arenaFont(13.5, .semibold, .rounded)
                    .foregroundStyle(BattleTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 16).padding(.trailing, 24).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Slant(trail: 12).fill(Color(hex: 0x0A1712).opacity(0.92)))
        .overlay(alignment: .leading) { Rectangle().fill(BattleTheme.leaf).frame(width: 3) }
        .accessibilityElement(children: .combine)
    }
}
