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
    /// True once the player has picked a zone themselves. Until then a
    /// Mystery Friend shows no zone selected (its stand-in zone means nothing),
    /// and naming the friend moves it to that kind's zone.
    @State private var zoneChosen = false
    private var showsZoneSelection: Bool { zoneChosen || !isMystery }
    /// Badges to celebrate. Starts from what the snap unlocked, and grows when
    /// naming the friend unlocks a species/rarity/zone badge in place.
    @State private var achievements: [Achievement]
    @State private var popped = false
    @State private var showPhoto = false
    @State private var showCrop = false
    /// Drives the push to the full, searchable catalog.
    @State private var showPicker = false
    /// Renaming happens right on the name (see `RenamableName`).
    @State private var isRenaming = false

    /// The open Duo in landscape: the photo stays on the left page while you
    /// choose who it is (and where it lives) on the right.
    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX
    /// The spread's inline field-guide search.
    @State private var query = ""

    init(result: CatchResult, onDone: @escaping () -> Void = {}) {
        self.result = result
        self.onDone = onDone
        _species = State(initialValue: result.species)
        _sparks = State(initialValue: result.sparks)
        _isFirst = State(initialValue: result.isFirstSighting)
        _zone = State(initialValue: result.record.effectiveZone)
        _achievements = State(initialValue: result.newAchievements)
    }

    private var isMystery: Bool { species.id == Species.mystery.id }

    var body: some View {
        NavigationStack {
            ZStack {
                species.rarity.tint.opacity(0.35).ignoresSafeArea()
                Theme.background.opacity(0.4).ignoresSafeArea()

                Confetti(themeEmoji: isMystery ? nil : species.emoji)

                if isSpread {
                    spreadLayout
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            // Roomy: the photo, name and cards each get a beat.
                            VStack(spacing: 28) {
                                headline

                                // Full width, like the friend page, now the
                                // details sit in one row of cards.
                                photo()

                                nameBlock

                                detailTiles

                                if !achievements.isEmpty {
                                    achievementsUnlocked
                                }
                            }
                            .padding()
                            // Tapping anywhere else finishes a rename.
                            .contentShape(Rectangle())
                            .onTapGesture { isRenaming = false }
                        }
                        .scrollDismissesKeyboard(.immediately)

                        // Out of the way while typing a name, so they don't
                        // ride up on the keyboard.
                        if !isRenaming {
                            actionButtons
                                .padding([.horizontal, .bottom])
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .photoLightbox(isPresented: $showPhoto, image: result.image, friend: result.record)
            .photoCropper(isPresented: $showCrop, friend: result.record)
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

    private var headline: some View {
        Text(isFirst ? "A new friend found your Grove!" : "Another friend found your Grove!")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.ink.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    /// The friend's name — tap it to give them one — and, once named, its
    /// rarity. (The kind is on the Animal card below.)
    private var nameBlock: some View {
        VStack(spacing: 12) {
            RenamableName(friend: result.record, isRenaming: $isRenaming, fontSize: 30)
            if !isMystery {
                RarityBadge(rarity: species.rarity, large: true)
            }
        }
    }

    // MARK: Spread (the open Duo in landscape)

    /// The photo, name, sparks and any new badges on the left page; choosing
    /// who it is — right there in the field guide — and where it lives on the
    /// right, with Done at the bottom.
    private var spreadLayout: some View {
        GeometryReader { geo in
            let pages = DuoSpread.pageWidths(in: geo.frame(in: .global), foldX: foldX,
                                             leading: 24, trailing: 24)
            HStack(alignment: .top, spacing: DuoSpread.foldGutter * 2) {
                ScrollView {
                    VStack(spacing: 18) {
                        headline
                        photo(width: min(pages.leading, 420) - 12)
                        nameBlock
                        detailTiles
                        if !achievements.isEmpty {
                            achievementsUnlocked
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .contentShape(Rectangle())
                    .onTapGesture { isRenaming = false }
                }
                .scrollDismissesKeyboard(.immediately)
                .frame(width: pages.leading)

                VStack(alignment: .leading, spacing: 14) {
                    Text(isMystery ? "What did you find?" : "Choose a different animal")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    searchField
                    ScrollView { inlinePicker }
                    actionButtons
                }
                .padding(.vertical, 20)
                .frame(width: pages.trailing)
            }
            .padding(.horizontal, 24)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.ink.opacity(0.4))
            TextField("Search the field guide", text: $query)
                .font(.system(.body, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
    }

    /// The field guide, right on the page: tap a friend to name your find.
    @ViewBuilder private var inlinePicker: some View {
        let results = CreatureCatalog.matching(query)
        if results.isEmpty {
            Text("No animals match “\(query.trimmingCharacters(in: .whitespaces))”.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                ForEach(results) { candidate in
                    let chosen = candidate.id == species.id
                    Button {
                        guard !chosen else { return }
                        correct(to: candidate)
                    } label: {
                        VStack(spacing: 4) {
                            Text(candidate.emoji).font(.system(size: 28))
                            Text(candidate.name)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(chosen ? Theme.accent.opacity(0.14) : .white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(chosen ? Theme.accent : Theme.ink.opacity(0.08),
                                        lineWidth: chosen ? 2.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            .padding(2)
        }
    }

    /// Details and Snap another as pills, with Done as a round, floating
    /// check button beside them.
    private var actionButtons: some View {
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

            Button { onDone() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.accent))
                    .shadow(color: Theme.accent.opacity(0.4), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Done")
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

    /// The friend's photo in the shared 4:3 card. With no width it fills the
    /// width it's given, like the friend page's photo.
    private func photo(width: CGFloat? = nil) -> some View {
        Color.clear
            .aspectRatio(Theme.photoAspectRatio, contentMode: .fit) // shared 4:3 shape
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay { FriendPhoto(image: result.image, framing: result.record.framing) }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white, lineWidth: 6)
            )
            .overlay(alignment: .topTrailing) {
                Button { showCrop = true } label: {
                    Label("Crop", systemImage: "crop")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(species.emoji)
                    .font(.system(size: 40))
                    .padding(8)
                    .background(Circle().fill(.white))
                    .offset(x: -4, y: 14) // inside the edge now the photo is full width
            }
            .shadow(color: Theme.ink.opacity(0.15), radius: 16, y: 8)
            .scaleEffect(popped ? 1 : 0.6)
            .rotationEffect(.degrees(popped ? 0 : -8))
            .onTapGesture { showPhoto = true }
    }

    // MARK: Details — animal, zone and sparks as three matching cards

    /// Who it is, where it lives and what it earned, as a row of cards like
    /// the friend page's. Naming the friend is the main job here, so while
    /// it's a Mystery Friend the Animal card is outlined in the accent.
    private var detailTiles: some View {
        HStack(spacing: 10) {
            animalTile
            zoneTile
            sparksTile
        }
    }

    @ViewBuilder private var animalTile: some View {
        let label = tile(label: "Animal",
                         systemImage: isSpread ? nil : "chevron.right",
                         highlighted: isMystery) {
            Text(isMystery ? "❓ Choose" : "\(species.emoji) \(species.name)")
                .foregroundStyle(isMystery ? Theme.accent : Theme.ink)
        }
        if isSpread {
            // The field guide is open on the right page already.
            label
        } else {
            Button { showPicker = true } label: { label }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the field guide")
        }
    }

    private var zoneTile: some View {
        Menu {
            ForEach(Habitat.ordered) { habitat in
                Button { setZone(habitat) } label: {
                    if isSelected(habitat) {
                        Label("\(habitat.emoji) \(habitat.shortName)", systemImage: "checkmark")
                    } else {
                        Text("\(habitat.emoji) \(habitat.shortName)")
                    }
                }
            }
        } label: {
            tile(label: "Lives in", systemImage: "chevron.down") {
                if showsZoneSelection {
                    Text("\(zone.emoji) \(zone.shortName)")
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("Pick one")
                        .foregroundStyle(Theme.ink.opacity(0.45))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var sparksTile: some View {
        tile(label: isFirst ? "2× first find" : "Sparks",
             labelColor: isFirst ? Theme.accent : Theme.ink.opacity(0.5)) {
            Text("+\(sparks) ✨")
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
        }
    }

    /// One card: a bold value over a small caption, like the friend page's.
    private func tile<Value: View>(label: String,
                                   systemImage: String? = nil,
                                   highlighted: Bool = false,
                                   labelColor: Color = Theme.ink.opacity(0.5),
                                   @ViewBuilder value: () -> Value) -> some View {
        VStack(spacing: 5) {
            value()
                .font(.system(.headline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                Text(label.uppercased())
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 8, weight: .heavy))
                }
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(labelColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 6)
        .softCard()
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.accent, lineWidth: highlighted ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Identify — the player names their new friend

    private func correct(to chosen: Species) {
        // Is this the player's first sighting of the chosen friend (ignoring
        // this very record)?
        let others = (try? context.fetch(FetchDescriptor<Catch>())) ?? []
        let first = !others.contains { $0 !== result.record && $0.speciesID == chosen.id }
        let newSparks = Progression.sparks(for: chosen, isFirstSighting: first)

        // Snapshot achievements before/after naming the friend, so the species,
        // rarity and zone badges it unlocks are celebrated right here — they
        // couldn't fire at snap time while the catch was still unidentified.
        let before = PlayerStats(catches: others)

        result.record.speciesID = chosen.id
        result.record.isFirstSighting = first
        result.record.sparksEarned = newSparks
        // Keep a zone the player already picked; otherwise it moves to the
        // identified kind's zone.
        let newZone = zoneChosen ? zone : chosen.zone
        result.record.zoneOverride = (newZone == chosen.zone) ? nil : newZone
        try? context.save()

        let after = PlayerStats(catches: others) // same records, now re-identified
        let freshlyUnlocked = AchievementCatalog.newlyUnlocked(before: before, after: after)
            .filter { new in !achievements.contains { $0.id == new.id } }

        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            species = chosen
            sparks = newSparks
            isFirst = first
            zone = newZone
            achievements.append(contentsOf: freshlyUnlocked)
        }
    }

    private func isSelected(_ habitat: Habitat) -> Bool {
        showsZoneSelection && zone == habitat
    }

    private func setZone(_ habitat: Habitat) {
        zoneChosen = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { zone = habitat }
        result.record.zoneOverride = (habitat == species.zone) ? nil : habitat
        try? context.save()
    }

    // MARK: Achievements

    private var achievementsUnlocked: some View {
        VStack(spacing: 8) {
            Text("🎖 Achievement\(achievements.count > 1 ? "s" : "") unlocked!")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.accent)
            ForEach(achievements) { achievement in
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

/// A cheap, cheerful emoji confetti burst. Before the player names their find,
/// it rains a fun jumble of *random animal* emoji (with a little sparkle); once
/// a friend is chosen, the burst is mostly *that* animal instead.
struct Confetti: View {
    var themeEmoji: String? = nil
    @State private var animate = false
    /// A fresh shuffle of catalog animals for this burst, so no two catches
    /// rain the same critters. Held in state so it stays stable across redraws.
    @State private var randomAnimals: [String] = Confetti.randomAnimalPieces()

    private var pieces: [String] {
        guard let e = themeEmoji else {
            return randomAnimals
        }
        // Weight the burst toward the animal itself, sprinkle in a little sparkle.
        return [e, e, e, "✨", e, "🎉", e, e, "⭐️", e, "💫", e]
    }

    /// A shuffled handful of real catalog animal emoji, dotted with sparkles,
    /// for the "friend found!" moment before it's been identified.
    private static func randomAnimalPieces() -> [String] {
        let animals = CreatureCatalog.all.map(\.emoji).shuffled().prefix(9)
        return Array(animals) + ["✨", "🎉", "⭐️"]
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
