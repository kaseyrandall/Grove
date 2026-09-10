import SwiftUI
import SwiftData

/// The Grove — the heart of the app. Every friend you've photographed lives here
/// as its own individual, settled into a habitat zone. No `???` silhouettes,
/// just a cozy world that fills with life as you explore.
struct GroveView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]

    /// Play the graceful entrance only the first time the Grove is ever shown —
    /// i.e. right after the tutorial.
    @AppStorage("hasSeenGroveIntro") private var seenIntro = false
    @State private var revealed = false

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

    private var friendCount: Int { catches.count }
    private var shown: Bool { seenIntro || revealed }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    header
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .opacity(shown ? 1 : 0)
                        .offset(y: shown ? 0 : -10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: shown)

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

                    HStack(alignment: .top, spacing: 12) {
                        masonryColumn(masonry.left)
                        masonryColumn(masonry.right)
                    }
                    .padding()
                    .padding(.bottom, Theme.tabBarClearance)
                }
            }
            // Overlaid (not a real toolbar item) so it can transition in and
            // out gracefully instead of popping. Attached to the root content —
            // not the whole NavigationStack — so it shows ONLY on the Grove and
            // never bleeds onto pushed detail screens over their Edit button.
            .overlay(alignment: .topTrailing) {
                if challengeDismissed {
                    reopenChallengeButton
                        .padding(.trailing, 18)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .topTrailing)))
                }
            }
            .navigationTitle("Your Grove")
            .onAppear {
                challengeDismissed = (challengeDismissedDay == todayKey)
                guard !seenIntro else { return }
                revealed = true
                // Persist once the cascade has finished so it never replays.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { seenIntro = true }
            }
        }
    }

    /// Split the zones into two independently-flowing columns, kept as close in
    /// height as possible. We assign the tallest zones first, each into whichever
    /// column is currently shorter (the "longest-processing-time" rule) — this
    /// balances far better than walking the zones in order, which tended to pile
    /// the short cards into one column. Each column is then shown back in natural
    /// zone order. Unlike a `LazyVGrid`, this packs a tall, busy zone beside a
    /// short one without a locked-row gap, and stays balanced as zones fill up.
    private var masonry: (left: [(index: Int, zone: Habitat)], right: [(index: Int, zone: Habitat)]) {
        let zones = Habitat.ordered.enumerated().map { (index: $0.offset, zone: $0.element) }
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
        guard residents > 0 else { return base + 52 }      // + the "quiet spot" line
        let rows = (Double(residents) / 2.0).rounded(.up)  // ~2 avatars per column-width row
        return base + rows * 66                             // + each avatar row
    }

    private func masonryColumn(_ items: [(index: Int, zone: Habitat)]) -> some View {
        VStack(spacing: 12) {
            ForEach(items, id: \.zone) { item in
                ZoneCard(zone: item.zone, catches: catches)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 26)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.82)
                        .delay(0.1 + Double(item.index) * 0.07),
                        value: shown
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("🌳").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 1) {
                Text(friendCount == 0
                     ? "Your Grove is waiting"
                     : "\(friendCount) friend\(friendCount == 1 ? " has" : "s have") come home")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Grow a place full of the life you've met.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Shown in the top-right once the card is dismissed, to bring it back — a
    /// calendar, since the challenge is a daily/event thing.
    private var reopenChallengeButton: some View {
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
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white))
                .shadow(color: Theme.ink.opacity(0.1), radius: 8, y: 4)
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
                HStack {
                    Spacer()
                    Text("a quiet spot, waiting for its first visitor…")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.45))
                    Spacer()
                }
                .frame(height: 64)
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
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(zone.gradient)
        )
        .shadow(color: Theme.ink.opacity(0.08), radius: 10, x: 0, y: 5)
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
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(3)
            } else {
                Text(friend.species.emoji).font(.system(size: 26))
            }
        }
        .frame(width: 56, height: 56)
        .overlay(Circle().stroke(friend.species.rarity.tint, lineWidth: 3))
        // The kind, as a small badge on the corner — replaces the name label.
        // Skipped when there's no photo, since the avatar is already the emoji.
        .overlay(alignment: .bottomTrailing) {
            if friend.photoData != nil {
                Text(friend.species.emoji)
                    .font(.system(size: 13))
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
