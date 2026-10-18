import SwiftUI
import SwiftData

/// The Grove — the heart of the app. Every friend you've photographed lives here
/// as its own individual, settled into a habitat zone. No `???` silhouettes,
/// just a cozy world that fills with life as you explore.
struct GroveView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]

    /// Jumps to the camera (owned by RootView's tab selection). Optional so
    /// previews work without it; when nil, the "go look" prompts are hidden.
    var onSnap: (() -> Void)? = nil

    /// Play the graceful entrance only the first time the Grove is ever shown —
    /// i.e. right after the tutorial.
    @AppStorage("hasSeenGroveIntro") private var seenIntro = false
    @State private var revealed = false

    /// Coach-mark "seen" flag (shared with RootView by key). Set when the player
    /// dismisses the daily card, so that hint retires on use instead of only
    /// when its bubble is tapped. (The "meet a friend" flag is set in ZoneCard,
    /// where that target lives.)
    @AppStorage("hasSeenGoalCoach") private var hasSeenGoalCoach = false

    /// The day (day-number since 1970) the player dismissed today's challenge,
    /// persisted so it stays dismissed across launches until a new day rotates
    /// in. The visible state is driven by `challengeDismissed` (a `@State`) so
    /// the show/hide animates — setting `@AppStorage` inside `withAnimation`
    /// does not reliably carry the transaction.
    @AppStorage("challengeDismissedDay") private var challengeDismissedDay = 0
    @State private var challengeDismissed = false
    /// Whether today's challenge was already complete when it was dismissed. If
    /// not, and it later completes while collapsed, we badge the reopen button.
    @AppStorage("challengeDismissedComplete") private var dismissedWhileComplete = false
    private var todayKey: Int { Int((Calendar.current.startOfDay(for: .now).timeIntervalSince1970 / 86_400).rounded()) }

    private var shown: Bool { seenIntro || revealed }

    /// The open Duo in landscape: the Grove lays out as a two-page spread.
    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX
    #if DEBUG
    @State private var debugFriend: Catch?
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if isSpread {
                    spreadLayout
                } else {
                    ScrollView {
                        if !challengeDismissed {
                            dailyChallengeCard
                                .coachTarget(.dailyGoal)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .opacity(shown ? 1 : 0)
                                .offset(y: shown ? 0 : -6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: shown)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        #if DEBUG
                        arenaSignpost
                            .padding(.horizontal)
                            .padding(.top, 12)
                        #endif

                        if catches.isEmpty {
                            firstFriendCard
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .opacity(shown ? 1 : 0)
                                .offset(y: shown ? 0 : -6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: shown)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }

                        VStack(spacing: 12) {
                            // A busy zone gets the full width to itself.
                            ForEach(wideZones, id: \.zone) { item in
                                animatedZoneCard(item)
                            }
                            HStack(alignment: .top, spacing: 12) {
                                masonryColumn(masonry.left)
                                masonryColumn(masonry.right)
                            }
                        }
                        .padding()
                    }
                }
            }
            .clearsGroveTabBar()
            // The standard large title, like the Journal; it shrinks into the
            // bar as you scroll. The spread draws its own title on each page.
            .navigationTitle("Your Grove")
            .toolbar(isSpread ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                if challengeDismissed && !isSpread {
                    ToolbarItem(placement: .topBarTrailing) { reopenChallengeButton(inToolbar: true) }
                }
            }
            #if DEBUG
            // Test hook: `-GroveOpenFriend` opens your rarest friend's page on launch.
            .navigationDestination(item: $debugFriend) { GuideEntryView(friend: $0) }
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-GroveOpenFriend") else { return }
                try? await Task.sleep(for: .milliseconds(600)) // let sample data land first
                debugFriend = catches.max { $0.species.rarity < $1.species.rarity }
            }
            #endif
            .onAppear {
                challengeDismissed = (challengeDismissedDay == todayKey)
                guard !seenIntro else { return }
                revealed = true
                // Persist once the cascade has finished so it never replays.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { seenIntro = true }
            }
        }
    }

    // MARK: Spread (the open Duo in landscape)

    /// The whole Grove at a glance: the title on the left page, today's
    /// challenge on the right, then all eight zones in two rows of four — two
    /// columns per page, so the fold always falls between cards.
    private var spreadLayout: some View {
        // Measure the space the page is given (not the scroll view, whose size
        // follows its content) so the pages can be fitted around the fold.
        GeometryReader { geo in
            spreadContent(frame: geo.frame(in: .global))
        }
    }

    private func spreadContent(frame: CGRect) -> some View {
        let outerLeading: CGFloat = 24, outerTrailing: CGFloat = 16
        let topPadding: CGFloat = 26, bottomPadding: CGFloat = 16
        let headerHeight: CGFloat = 96, spacing: CGFloat = 16
        let pages = DuoSpread.pageWidths(in: frame, foldX: foldX,
                                         leading: outerLeading, trailing: outerTrailing)
        // Two rows that fill the screen; a busy zone can still grow its row.
        let rowHeight = max(180, (frame.height - topPadding - bottomPadding
                                  - headerHeight - spacing * 2) / 2)
        let zones = spreadZones

        return ScrollView {
            HStack(alignment: .top, spacing: DuoSpread.foldGutter * 2) {
                VStack(alignment: .leading, spacing: spacing) {
                    titleRow
                    .frame(height: headerHeight, alignment: .topLeading)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : -10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: shown)

                    spreadZoneGrid(zones.left, rowHeight: rowHeight)
                }
                .frame(width: pages.leading)

                VStack(spacing: spacing) {
                    ZStack(alignment: .top) {
                        if !challengeDismissed {
                            dailyChallengeCard
                                .coachTarget(.dailyGoal)
                                .opacity(shown ? 1 : 0)
                                .offset(y: shown ? 0 : -6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: shown)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .frame(height: headerHeight, alignment: .top)

                    spreadZoneGrid(zones.right, rowHeight: rowHeight)
                }
                .frame(width: pages.trailing)
            }
            .padding(.leading, outerLeading)
            .padding(.trailing, outerTrailing)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(width: frame.width, alignment: .topLeading)
        }
    }

    /// The zones read row by row across all four columns: the first two of
    /// each row on the left page, the next two on the right.
    private var spreadZones: (left: [(index: Int, zone: Habitat)], right: [(index: Int, zone: Habitat)]) {
        let zones = Habitat.ordered.enumerated().map { (index: $0.offset, zone: $0.element) }
        return (zones.filter { $0.index % 4 < 2 }, zones.filter { $0.index % 4 >= 2 })
    }

    /// One page's zones, two per row; cards in a row share its height.
    private func spreadZoneGrid(_ items: [(index: Int, zone: Habitat)], rowHeight: CGFloat) -> some View {
        let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        return Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            ForEach(rows, id: \.first!.zone) { row in
                GridRow {
                    ForEach(row, id: \.zone) { item in
                        ZoneCard(zone: item.zone, catches: catches, fillsHeight: true)
                            .frame(minHeight: rowHeight)
                            .frame(maxHeight: .infinity)
                            .opacity(shown ? 1 : 0)
                            .offset(y: shown ? 0 : 26)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.82)
                                .delay(0.1 + Double(item.index) * 0.07),
                                value: shown
                            )
                    }
                }
            }
        }
    }

    // MARK: Portrait masonry

    /// Split the zones into two independently-flowing columns, kept as close in
    /// height as possible. We assign the tallest zones first, each into whichever
    /// column is currently shorter (the "longest-processing-time" rule) — this
    /// balances far better than walking the zones in order, which tended to pile
    /// the short cards into one column. Each column is then shown back in natural
    /// zone order. Unlike a `LazyVGrid`, this packs a tall, busy zone beside a
    /// short one without a locked-row gap, and stays balanced as zones fill up.
    private var masonry: (left: [(index: Int, zone: Habitat)], right: [(index: Int, zone: Habitat)]) {
        let wide = Set(wideZones.map(\.zone))
        let zones = Habitat.ordered.enumerated()
            .map { (index: $0.offset, zone: $0.element) }
            .filter { !wide.contains($0.zone) }
        var left: [(index: Int, zone: Habitat)] = []
        var right: [(index: Int, zone: Habitat)] = []
        var leftWeight = 0.0, rightWeight = 0.0
        for item in zones.sorted(by: { weight(of: $0.zone) > weight(of: $1.zone) }) {
            if leftWeight <= rightWeight {
                left.append(item); leftWeight += weight(of: item.zone)
            } else {
                right.append(item); rightWeight += weight(of: item.zone)
            }
        }
        left.sort { $0.index < $1.index }
        right.sort { $0.index < $1.index }
        return (left, right)
    }

    /// Approximate rendered height of a zone card (in points), used only to
    /// balance the two masonry columns so they stay close in height as zones
    /// fill up. The old estimate under-counted both empty cards (their "quiet
    /// spot" line makes them nearly as tall as a small full card) and busy ones
    /// (a column is only wide enough for ~2 avatars per row, not 3), which left
    /// the columns ragged. This tracks the real layout much more closely.
    private func weight(of zone: Habitat) -> Double {
        let residents = catches.filter { $0.effectiveZone == zone }.count
        let base = 80.0                                    // header + padding + inter-card gap
        guard residents > 0 else { return base + 72 }      // + visitor hints and the where-to-look line
        let rows = (Double(residents) / 2.0).rounded(.up)  // ~2 avatars per column-width row
        return base + rows * 66                             // + each avatar row
    }

    /// Zones with this many friends or more span the full width (above the
    /// two columns), so a busy zone isn't a long, narrow strip.
    static let wideZoneThreshold = 8

    private var wideZones: [(index: Int, zone: Habitat)] {
        Habitat.ordered.enumerated()
            .map { (index: $0.offset, zone: $0.element) }
            .filter { item in
                catches.filter { $0.effectiveZone == item.zone }.count >= Self.wideZoneThreshold
            }
    }

    private func masonryColumn(_ items: [(index: Int, zone: Habitat)]) -> some View {
        VStack(spacing: 12) {
            ForEach(items, id: \.zone) { item in
                animatedZoneCard(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func animatedZoneCard(_ item: (index: Int, zone: Habitat)) -> some View {
        ZoneCard(zone: item.zone, catches: catches)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.82)
                .delay(0.1 + Double(item.index) * 0.07),
                value: shown
            )
    }

    #if DEBUG
    /// A gated "arena at night" signpost that sits among the pastel habitats —
    /// the in-Grove door into Battlegrounds (dev-only).
    private var arenaSignpost: some View {
        NavigationLink {
            BattlegroundsView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x16261D), Color(hex: 0x0E1A14)], startPoint: .top, endPoint: .bottom))
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: 0xF3D17A))
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battlegrounds")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Send a friend to the Arena")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x1D2A22), Color(hex: 0x121C16)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(hex: 0xF3D17A).opacity(0.25), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
    #endif

    /// The page title, with the challenge's calendar button beside it once the
    /// card is put away. Part of the scroll content, so it scrolls away with
    /// the page rather than staying pinned.
    private var titleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Your Grove")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if challengeDismissed {
                reopenChallengeButton()
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
            }
        }
        .frame(minHeight: 44)
    }

    /// The cold-start nudge for a brand-new Grove: the easiest friends to meet
    /// are usually a few steps away, so lower the bar for that first snap.
    /// Disappears for good once anyone comes home.
    private var firstFriendCard: some View {
        let easyFinds = ["housecat", "dog", "pigeon", "squirrel"]
            .compactMap { id in CreatureCatalog.all.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your first friend is closer than you think")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                ForEach(easyFinds) { species in
                    SpeciesGlyph(species: species, size: 22)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.cream))
                }
            }
            .accessibilityHidden(true)
            Text("A pet, a pigeon, a backyard squirrel: they all count. Even a blur becomes a Mystery Friend.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            if let onSnap {
                Button(action: onSnap) {
                    Label("Snap your first friend", systemImage: "camera.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    /// Shown in the top-right once the card is dismissed, to bring it back — a
    /// calendar, since the challenge is a daily/event thing.
    /// `inToolbar`: drawn as a plain icon, since the navigation bar gives
    /// its buttons their own background.
    private func reopenChallengeButton(inToolbar: Bool = false) -> some View {
        let challenge = DailyChallenge.today()
        let todays = catches.filter { Calendar.current.isDateInToday($0.caughtAt) }
        // Completed since it was collapsed (and it wasn't already done then).
        let justCompleted = challenge.isComplete(todays, PlayerStats(catches: catches)) && !dismissedWhileComplete
        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                challengeDismissed = false
            }
            challengeDismissedDay = 0
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: inToolbar ? 30 : 42, height: inToolbar ? 30 : 42)
                .background(Circle().fill(inToolbar ? .clear : .white))
                .shadow(color: Theme.ink.opacity(inToolbar ? 0 : 0.1), radius: 8, y: 4)
                .overlay(alignment: .topTrailing) {
                    if justCompleted {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(x: 3, y: -3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(justCompleted ? "Show today's challenge, completed" : "Show today's challenge")
    }

    /// Today's bite-sized goal — a fresh reason to open the app each day.
    private var dailyChallengeCard: some View {
        let challenge = DailyChallenge.today()
        let todays = catches.filter { Calendar.current.isDateInToday($0.caughtAt) }
        let stats = PlayerStats(catches: catches)
        let complete = challenge.isComplete(todays, stats)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(complete ? Theme.mint.opacity(0.55) : Theme.accent.opacity(0.14))
                    .frame(width: 48, height: 48)
                Text(complete ? "✅" : challenge.emoji)
                    .font(.system(size: 24))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S CHALLENGE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.4))
                Text(challenge.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                if complete {
                    Text("Done — nice work! 🎉")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                } else if challenge.goal > 1 {
                    Text("\(challenge.current(todays, stats))/\(challenge.goal)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .softCard()
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    challengeDismissed = true
                }
                challengeDismissedDay = todayKey
                dismissedWhileComplete = complete
                hasSeenGoalCoach = true // engaging with the card retires its hint
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.3))
                    .padding(9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss today's challenge")
        }
    }
}

/// One habitat zone in the Grove, showing each individual friend who lives there.
struct ZoneCard: View {
    let zone: Habitat
    let catches: [Catch]
    /// Stretch to fill the space offered (the spread's equal-height rows).
    var fillsHeight = false

    /// Shared with RootView by key — set when the player opens a friend, so the
    /// "meet your friend" coach mark retires on use, not only on bubble-tap.
    @AppStorage("hasSeenMeetCoach") private var hasSeenMeetCoach = false

    /// Individual friends who currently live in this zone (rarer kinds first).
    private var residents: [Catch] {
        catches
            .filter { $0.effectiveZone == zone }
            .sorted {
                $0.species.rarity != $1.species.rarity
                    ? $0.species.rarity > $1.species.rarity
                    : $0.caughtAt > $1.caughtAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("\(zone.emoji) \(zone.shortName)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text("\(residents.count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.45))
            }

            if residents.isEmpty {
                emptyInvite
                    .frame(maxHeight: fillsHeight ? .infinity : nil)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 10) {
                    ForEach(Array(residents.enumerated()), id: \.element.persistentModelID) { index, friend in
                        NavigationLink {
                            GuideEntryView(friend: friend)
                        } label: {
                            ResidentPortrait(friend: friend, index: index)
                        }
                        .buttonStyle(.plain)
                        // Point the "meet your friend" mark at the very first catch.
                        .coachTarget(.meetFriend, active: catches.count == 1)
                        // Opening a friend is the lesson — retire the hint on tap.
                        .simultaneousGesture(TapGesture().onEnded { hasSeenMeetCoach = true })
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: fillsHeight ? .infinity : nil,
               maxHeight: fillsHeight ? .infinity : nil,
               alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(zone.gradient)
        )
        .shadow(color: Theme.ink.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    /// An empty zone, made inviting: a few friends who might drop by (rotated
    /// daily) and a hint of where to look.
    /// They're friendly suggestions, not `???` silhouettes — nothing reads as
    /// "missing", just "who's next".
    private var emptyInvite: some View {
        let visitors = zone.likelyVisitors()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(visitors.enumerated()), id: \.element.id) { index, species in
                    VisitorHint(species: species, index: index)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Might visit: \(visitors.map(\.name).formatted(.list(type: .or)))")

            if !visitors.isEmpty {
                Text(zone.lookHint)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.5))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A soft, dashed bubble holding the emoji of a friend who might visit an
/// empty zone — clearly a hint (no photo, no rarity ring), gently bobbing so
/// the quiet spot still feels alive.
private struct VisitorHint: View {
    let species: Species
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        SpeciesGlyph(species: species, size: 20)
            .opacity(0.75)
            .frame(width: 38, height: 38)
            .background(Circle().fill(.white.opacity(0.45)))
            .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            .offset(y: floating ? -2 : 2)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 2.2 + Double(index) * 0.3)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.35)
                ) {
                    floating = true
                }
            }
    }
}

/// A round photo portrait of an individual friend, ringed in its rarity color,
/// gently floating in place. Staggered by position so they don't bob in unison.
struct ResidentPortrait: View {
    let friend: Catch
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    private var duration: Double { 2.0 + Double(index % 3) * 0.35 }
    private var startDelay: Double { Double(index) * 0.28 }

    var body: some View {
        ZStack {
            Circle().fill(.white)
            if let data = friend.photoData, let ui = UIImage(data: data) {
                FriendPhoto(image: ui, framing: friend.framing)
                    .clipShape(Circle())
                    .padding(3)
            } else {
                SpeciesGlyph(species: friend.species, size: 26)
            }
        }
        .frame(width: 56, height: 56)
        .overlay(Circle().stroke(friend.species.rarity.tint, lineWidth: 3))
        // The kind, as a small badge on the corner — replaces the name label.
        // Skipped when there's no photo, since the avatar is already the emoji.
        .overlay(alignment: .bottomTrailing) {
            if friend.photoData != nil {
                SpeciesGlyph(species: friend.species, size: 13)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(friend.species.rarity.tint.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: Theme.ink.opacity(0.15), radius: 2, y: 1)
                    .offset(x: 3, y: 3)
            }
        }
        .shadow(color: Theme.ink.opacity(0.15),
                radius: floating ? 5 : 3,
                y: floating ? 5 : 2)
        .rotationEffect(.degrees(floating ? 2.5 : -2.5))
        .offset(y: floating ? -4 : 3)
        .accessibilityLabel(friend.displayName)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(startDelay)
            ) {
                floating = true
            }
        }
    }
}

#Preview {
    GroveView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}

