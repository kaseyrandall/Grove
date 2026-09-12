import SwiftUI
import SwiftData

// MARK: - Battlegrounds entry: pick a friend, see their card, battle

/// The dev flow that turns real friends into fighters: choose one from your
/// Grove, read the card the engine derives, then send it into the Arena.
struct BattlegroundsView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]
    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 12)]

    var body: some View {
        ZStack {
            BattleTheme.background.ignoresSafeArea()
            if catches.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(catches) { c in
                                NavigationLink {
                                    MatchupView(fighterCatch: c, roster: catches)
                                } label: {
                                    RosterChip(catch: c)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Battlegrounds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose your fighter")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Text("Every friend fights by its kind — zone sets its type, species sets its style.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌿").font(.system(size: 40))
            Text("No friends yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Text("Meet a friend or two in your Grove,\nthen come back to send them into the Arena.")
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
        .padding(40)
    }
}

// MARK: - Roster chip

private struct RosterChip: View {
    let `catch`: Catch
    private var type: BattleType { BattleType(habitat: `catch`.effectiveZone) }
    private var archetype: Archetype { .derived(fromSpeciesID: `catch`.speciesID) }

    var body: some View {
        VStack(spacing: 8) {
            PortraitCircle(photoData: `catch`.photoData, type: type,
                           monogram: String(`catch`.displayName.prefix(1)), size: 68)
            Text(`catch`.displayName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
                .lineLimit(1)
            HStack(spacing: 5) {
                TypeChip(type: type)
                Text(archetype.rawValue.capitalized)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }
}

// MARK: - Matchup: fighter card, level, opponent, battle

struct MatchupView: View {
    let fighter: Contender
    let roster: [Catch]

    @State private var opponent: Contender
    @State private var level: Int
    @State private var seed: UInt64

    init(fighterCatch: Catch, roster: [Catch]) {
        self.fighter = .from(fighterCatch)
        self.roster = roster
        let s = UInt64.random(in: 0 ..< UInt64.max)
        _seed = State(initialValue: s)
        _level = State(initialValue: 12)
        let others = roster.filter { $0.persistentModelID != fighterCatch.persistentModelID }
        _opponent = State(initialValue: others.randomElement().map(Contender.from) ?? .wildRival(seed: s))
    }

    var body: some View {
        ZStack {
            BattleTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    labeled("YOUR FIGHTER") {
                        BattleCardView(card: fighter.card(level: level), photoData: fighter.photoData)
                    }

                    levelStepper

                    Text("VS")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(BattleTheme.gold)

                    labeled("OPPONENT", trailing: shuffleButton) {
                        BattleCardView(card: opponent.card(level: level), photoData: opponent.photoData, compact: true)
                    }

                    battleButton
                }
                .padding()
            }
        }
        .navigationTitle("Matchup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func labeled<Content: View>(_ title: String, trailing: (some View)? = Optional<EmptyView>.none, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(BattleTheme.muted)
                Spacer()
                trailing
            }
            content()
        }
    }

    private var shuffleButton: some View {
        Button {
            let s = UInt64.random(in: 0 ..< UInt64.max)
            seed = s
            let others = roster.filter { $0.displayName != fighter.name }
            withAnimation(.easeInOut(duration: 0.2)) {
                opponent = others.randomElement().map(Contender.from) ?? .wildRival(seed: s)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "shuffle")
                Text("Shuffle")
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(BattleTheme.leaf)
        }
        .buttonStyle(.plain)
    }

    private var levelStepper: some View {
        HStack {
            Text("Level")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Spacer()
            HStack(spacing: 16) {
                stepButton("minus") { if level > 1 { level -= 1 } }
                Text("\(level)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.gold)
                    .frame(minWidth: 32)
                    .monospacedDigit()
                stepButton("plus") { if level < 30 { level += 1 } }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    private func stepButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(BattleTheme.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(hex: 0x1C2C23)).overlay(Circle().stroke(Color(hex: 0x2C4A3A), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var battleButton: some View {
        NavigationLink {
            ArenaReplayView(result: makeResult(),
                            portraits: [fighter.photoData, opponent.photoData])
        } label: {
            Text("Battle!")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x07130B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(LinearGradient(colors: [BattleTheme.leaf, BattleTheme.leafDeep], startPoint: .top, endPoint: .bottom)))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func makeResult() -> BattleResult {
        simulate(fighter.card(level: level), .defaultPlan(for: fighter.archetype),
                 vs: opponent.card(level: level), .defaultPlan(for: opponent.archetype),
                 seed: seed)
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
                            .foregroundStyle(BattleTheme.ink)
                        TypeChip(type: card.type)
                    }
                    Text("\(card.archetype.rawValue.capitalized) · Lv\(card.level)")
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

/// A round portrait — the friend's real photo when present, else a type-tinted
/// monogram (matching the Arena token).
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

#Preview {
    NavigationStack { BattlegroundsView() }
        .modelContainer(for: Catch.self, inMemory: true)
}
