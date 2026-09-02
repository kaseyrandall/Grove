import SwiftUI
import SwiftData

/// The joyful "you caught it!" celebration. When the catch came back as a
/// Mystery Friend (Vision couldn't name it), the player can tap a chip to say
/// who it really was — which re-logs the catch as that friend.
struct CatchResultView: View {
    let result: CatchResult
    /// Called when the player is done celebrating — the presenter uses it to
    /// leave the catch flow (e.g. hop over to the Grove to see the new friend).
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    // Live state so a mystery correction updates the celebration in place.
    @State private var species: Species
    @State private var sparks: Int
    @State private var isFirst: Bool
    @State private var zone: Habitat
    @State private var wasMystery: Bool
    @State private var popped = false
    /// Drives the push to the full, searchable catalog.
    @State private var showPicker = false

    init(result: CatchResult, onDone: @escaping () -> Void = {}) {
        self.result = result
        self.onDone = onDone
        _species = State(initialValue: result.species)
        _sparks = State(initialValue: result.sparks)
        _isFirst = State(initialValue: result.isFirstSighting)
        _zone = State(initialValue: result.record.effectiveZone)
        _wasMystery = State(initialValue: result.species.id == Species.mystery.id)
    }

    private var isMystery: Bool { species.id == Species.mystery.id }

    var body: some View {
        NavigationStack {
            ZStack {
                species.rarity.tint.opacity(0.35).ignoresSafeArea()
                Theme.background.opacity(0.4).ignoresSafeArea()

                Confetti(themeEmoji: isMystery ? nil : species.emoji)

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 18) {
                            Text(isFirst ? "A new friend found your Grove!" : "Another friend found your Grove!")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.ink.opacity(0.7))
                                .multilineTextAlignment(.center)

                            photo

                            VStack(spacing: 8) {
                                Text(species.name)
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                RarityBadge(rarity: species.rarity)
                            }

                            identifySection

                            zonePicker

                            sparksCard

                            if !result.newAchievements.isEmpty {
                                achievementsUnlocked
                            }

                            #if DEBUG
                            visionReadout
                            #endif
                        }
                        .padding()
                    }

                    actionButtons
                        .padding([.horizontal, .bottom])
                        .padding(.top, 4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPicker) {
                SpeciesPickerView(selectedID: species.id) { picked in
                    correct(to: picked)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                popped = true
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            GroveButton(title: "Done", systemImage: "checkmark") {
                onDone()
            }
            HStack(spacing: 10) {
                NavigationLink {
                    GuideEntryView(friend: result.record)
                } label: {
                    secondaryLabel("Details", systemImage: "book.closed.fill")
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    secondaryLabel("Snap another", systemImage: "camera.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func secondaryLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title).font(.system(.subheadline, design: .rounded, weight: .bold))
        }
        .foregroundStyle(Theme.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Capsule().fill(.white))
        .overlay(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1.5))
    }

    // MARK: Photo

    private var photo: some View {
        Image(uiImage: result.image)
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white, lineWidth: 6)
            )
            .overlay(alignment: .bottomTrailing) {
                Text(species.emoji)
                    .font(.system(size: 40))
                    .padding(8)
                    .background(Circle().fill(.white))
                    .offset(x: 10, y: 10)
            }
            .shadow(color: Theme.ink.opacity(0.15), radius: 16, y: 8)
            .scaleEffect(popped ? 1 : 0.6)
            .rotationEffect(.degrees(popped ? 0 : -8))
    }

    // MARK: Sparks

    private var sparksCard: some View {
        HStack(spacing: 6) {
            Text("✨")
            Text("+\(sparks) sparks")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            if isFirst {
                Text("· 2× first find!")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .softCard()
    }

    // MARK: Mystery identification

    /// Best guesses drawn from this photo's Vision labels, minus what's already
    /// chosen — the same signal the editor uses.
    private var suggestions: [Species] {
        CreatureCatalog.smartSuggestions(labels: result.visionLabels)
            .filter { $0.id != species.id }
    }

    /// Identify a Mystery Friend, or correct a wrong guess — mirrors the editor:
    /// a few photo-based suggestions up front, the full catalog behind a door.
    private var identifySection: some View {
        VStack(spacing: 10) {
            if wasMystery {
                Text(isMystery ? "Know who this is?" : "Not quite? Tap the right one:")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))

                if !suggestions.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                        ForEach(suggestions) { candidate in
                            SpeciesTile(species: candidate, isSelected: false) { correct(to: candidate) }
                        }
                    }
                }
            }

            Button { showPicker = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill").foregroundStyle(Theme.accent)
                    Text(isMystery ? "Browse all animals" : "Not a \(species.name)? Choose another")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
            }
            .buttonStyle(.plain)
        }
    }

    private func correct(to chosen: Species) {
        // Is this the player's first sighting of the chosen friend (ignoring
        // this very record)?
        let others = (try? context.fetch(FetchDescriptor<Catch>())) ?? []
        let first = !others.contains { $0 !== result.record && $0.speciesID == chosen.id }
        let newSparks = Progression.sparks(for: chosen, isFirstSighting: first)

        result.record.speciesID = chosen.id
        result.record.isFirstSighting = first
        result.record.sparksEarned = newSparks
        result.record.zoneOverride = nil // default to the identified kind's zone
        try? context.save()

        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            species = chosen
            sparks = newSparks
            isFirst = first
            zone = chosen.zone
        }
    }

    // MARK: Found-in zone

    private var zonePicker: some View {
        VStack(spacing: 8) {
            Text("Found in your…")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Habitat.ordered) { habitat in
                        Button { setZone(habitat) } label: {
                            Text("\(habitat.emoji) \(habitat.shortName)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(zone == habitat ? habitat.gradient
                                                   : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
                                )
                                .overlay(Capsule().stroke(zone == habitat ? Theme.accent : Theme.ink.opacity(0.1), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func setZone(_ habitat: Habitat) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { zone = habitat }
        result.record.zoneOverride = (habitat == species.zone) ? nil : habitat
        try? context.save()
    }

    // MARK: DEBUG — what Vision actually saw (for the on-device reality check)

    #if DEBUG
    private var visionReadout: some View {
        VStack(spacing: 4) {
            Text("🔎 Vision saw")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink.opacity(0.5))
            Text(result.visionLabels.isEmpty ? "- nothing -" : result.visionLabels.prefix(8).joined(separator: ", "))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.6)))
    }
    #endif

    // MARK: Achievements

    private var achievementsUnlocked: some View {
        VStack(spacing: 8) {
            Text("🎖 Achievement\(result.newAchievements.count > 1 ? "s" : "") unlocked!")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.accent)
            ForEach(result.newAchievements) { achievement in
                HStack(spacing: 8) {
                    Text(achievement.emoji).font(.title3)
                    Text(achievement.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .softCard(fill: .white.opacity(0.9))
    }
}

/// A cheap, cheerful emoji confetti burst. When given a theme emoji (the caught
/// friend's), the burst is mostly *that* animal, mixed with a few sparkles.
struct Confetti: View {
    var themeEmoji: String? = nil
    @State private var animate = false

    private var pieces: [String] {
        guard let e = themeEmoji else {
            return ["✨", "🎉", "⭐️", "💫", "🌸", "🐾", "🦋", "🐿️", "🐰", "🦊", "🐦"]
        }
        // Weight the burst toward the animal itself, sprinkle in a little sparkle.
        return [e, e, e, "✨", e, "🎉", e, e, "⭐️", e, "💫", e]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<24, id: \.self) { i in
                    Text(pieces[i % pieces.count])
                        .font(.system(size: CGFloat.random(in: 18...30)))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .animation(
                            .easeIn(duration: Double.random(in: 1.8...3.2))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...1.5)),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
