import SwiftUI
import SwiftData
import MapKit

/// A field page for one individual friend: their photo, their kind, where they
/// live in your Grove, and the personal touches you've given them.
struct GuideEntryView: View {
    let friend: Catch

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showEdit = false
    @State private var wasReleased = false
    @State private var showPhoto = false
    @State private var showSwap = false
    @State private var showMap = false
    /// Drives the push to the catalog, to say who a Mystery Friend is.
    @State private var showIdentify = false
    /// Renaming happens right on the name: tap it, type, done.
    /// Renaming happens right on the name (see `RenamableName`).
    @State private var isRenaming = false
    @State private var showFavoritesFull = false
    @Query private var allCatches: [Catch]

    private var species: Species { friend.species }
    private var zone: Habitat { friend.effectiveZone }
    private var isMystery: Bool { species.id == Species.mystery.id }
    private var heroImage: UIImage? { friend.photoData.flatMap(UIImage.init(data:)) }

    /// The open Duo in landscape: the photo on the left page, the details on
    /// the right.
    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isSpread {
                spreadLayout
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        nameBlock
                        metaRow
                        infoCard
                        whereYouMetCard
                        #if DEBUG
                        arenaSection
                        #endif
                    }
                    .padding()
                    // Tapping anywhere else finishes a rename.
                    .contentShape(Rectangle())
                    .onTapGesture { isRenaming = false }
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .navigationTitle("\(species.emoji) \(species.name)")
        .navigationBarTitleDisplayMode(.inline)
        .groveTabBarHidden()
        .photoLightbox(isPresented: $showPhoto, image: heroImage, friend: friend)
        .navigationDestination(isPresented: $showIdentify) {
            SpeciesPickerView(selectedID: species.id) { picked in
                identify(as: picked)
            }
        }
        .fullScreenCover(isPresented: $showMap) {
            MeetingSpotMap(friend: friend)
        }
        .task {
            // Fill in the place name for older catches (or if it wasn't ready yet).
            if friend.placeName == nil, let lat = friend.latitude, let lng = friend.longitude {
                if let place = await Geocoder.placeName(latitude: lat, longitude: lng) {
                    friend.placeName = place
                    try? context.save()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if !Favorites.toggle(friend, among: allCatches, context: context) {
                        showFavoritesFull = true
                    }
                } label: {
                    Image(systemName: friend.favoritedAt != nil ? "heart.fill" : "heart")
                }
                .accessibilityLabel(friend.favoritedAt != nil ? "Remove from favorites" : "Add to favorites")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .alert("Your favorites are full", isPresented: $showFavoritesFull) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can pin \(Favorites.limit) friends to your Profile. Unpin one there to make room.")
        }
        #if DEBUG
        // Test hook: `-GroveOpenEdit` opens Edit on the first friend page shown.
        .onAppear {
            if LaunchFlag.once("-GroveOpenEdit") { showEdit = true }
        }
        #endif
        .groveSheet(isPresented: $showEdit) {
            EditFriendView(friend: friend, onRelease: { wasReleased = true })
        }
        #if DEBUG
        .sheet(isPresented: $showSwap) {
            ArenaSwapSheet(incoming: friend, team: BattleRoster.shared.teamCatches(from: allCatches).map(\.friend))
        }
        #endif
        .onChange(of: showEdit) { _, showing in
            // The edit sheet closed after a release request → remove the friend
            // now (nothing is holding the sheet), then leave the page.
            if !showing && wasReleased {
                BattleRoster.shared.forget(friend)
                context.delete(friend)
                try? context.save()
                dismiss()
            }
        }
    }

    // MARK: Spread (the open Duo in landscape)

    /// The photo and name on the left page; the details and the map of where
    /// you met on the right. Each page scrolls on its own.
    private var spreadLayout: some View {
        GeometryReader { geo in
            let pages = DuoSpread.pageWidths(in: geo.frame(in: .global), foldX: foldX,
                                             leading: 16, trailing: 16)
            HStack(alignment: .top, spacing: DuoSpread.foldGutter * 2) {
                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        nameBlock
                    }
                    .padding(.vertical)
                }
                .frame(width: pages.leading)

                ScrollView {
                    VStack(spacing: 18) {
                        metaRow
                        infoCard
                        whereYouMetCard
                        #if DEBUG
                        arenaSection
                        #endif
                    }
                    .padding(.vertical)
                }
                .frame(width: pages.trailing)
            }
            .padding(.horizontal, 16)
            .frame(width: geo.size.width, alignment: .topLeading)
        }
    }

    // MARK: Hero — a fixed, cropped card so every friend looks consistent.

    private var hero: some View {
        Color.clear
            .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                ZStack {
                    zone.gradient
                    if let ui = heroImage {
                        FriendPhoto(image: ui, framing: friend.framing)
                    } else {
                        SpeciesGlyph(species: species, size: 92)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(alignment: .topLeading) {
                RarityBadge(rarity: species.rarity).padding(12)
            }
            .overlay(alignment: .topTrailing) {
                // Hint that the photo opens full-screen.
                if heroImage != nil {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.9)))
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(zone.emoji) Lives in your \(zone.shortName)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.92)))
                    .padding(12)
            }
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture { if heroImage != nil { showPhoto = true } }
    }

    // MARK: Name + nickname

    private var nameBlock: some View {
        VStack(spacing: 4) {
            // The friend's own name leads — their nickname if they have one,
            // otherwise their kind. The kind always shows in the nav bar, so we
            // don't repeat it here. Tap it (or its pencil) to rename.
            RenamableName(friend: friend, isRenaming: $isRenaming)

            if isMystery {
                // Straight to the catalog — one tap to pick who this is.
                Button { showIdentify = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Who is this? Choose your friend")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.accent))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.top, 6)
            }
        }
    }

    /// Names the friend's kind, with its first-of-kind bonus. Where it lives
    /// stays the player's choice (an unchosen zone follows the new kind).
    private func identify(as chosen: Species) {
        guard chosen.id != friend.speciesID else { return }
        let isFirst = !allCatches.contains { $0 !== friend && $0.speciesID == chosen.id }
        friend.speciesID = chosen.id
        friend.isFirstSighting = isFirst
        friend.sparksEarned = Progression.sparks(for: chosen, isFirstSighting: isFirst)
        try? context.save()
    }

    // MARK: Meta

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaTile(value: friend.caughtAt.formatted(.dateTime.month().day()), label: "Met")
            metaTile(value: "\(species.rarity.badge) \(species.rarity.title)", label: "Rarity")
            metaTile(value: "\(friend.sparksEarned) ✨", label: "Sparks")
        }
    }

    private func metaTile(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 6)
        .softCard()
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(spacing: 12) {
            Text(species.blurb)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Divider()

            Label(species.habitatNote, systemImage: "leaf.fill")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .softCard()
    }

    /// A small map of the spot where you met this friend, named when we know
    /// the place. Tap it for a full map you can move around.
    @ViewBuilder private var whereYouMetCard: some View {
        if let lat = friend.latitude, let lng = friend.longitude {
            let spot = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            Button { showMap = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                Map(initialPosition: .region(MKCoordinateRegion(center: spot,
                                                                latitudinalMeters: 700,
                                                                longitudinalMeters: 700)),
                    interactionModes: []) {
                    Annotation("", coordinate: spot) { MapPin(species: species) }
                }
                .frame(height: 170)
                .allowsHitTesting(false)

                HStack(spacing: 8) {
                    Label(friend.meetingPlaceLabel, systemImage: "mappin.and.ellipse")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
                .padding(14)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.08), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the map")
        }
    }

    #if DEBUG
    // MARK: Battlegrounds — the "Send to the Arena" ritual (dev only)

    @ViewBuilder private var arenaSection: some View {
        let roster = BattleRoster.shared
        if roster.teamContains(friend), let p = roster.progress(for: friend) {
            VStack(spacing: 10) {
                Label("On your Arena team", systemImage: "bolt.shield.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("Level \(p.level) · \(p.xp)/\(BattleRoster.xpNeeded(for: p.level)) XP")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                if roster.canBench(friend) {
                    Button(role: .destructive) { roster.bench(friend) } label: {
                        Text("Remove from team")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .padding(.top, 2)
                } else {
                    Text("Away at a match. They can leave the team once they're back.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .softCard()
        } else {
            Button {
                if roster.hasFreeSlot(among: allCatches) { roster.promote(friend) } else { showSwap = true }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(roster.hasFreeSlot(among: allCatches) ? "Send to the Arena" : "Arena team full — swap someone")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if let p = roster.progress(for: friend) {
                            Text("Returns at Lv \(p.level) — keeps what they earned")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.ink.opacity(0.5))
                        } else {
                            Text("Enters fresh at Level 1")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.ink.opacity(0.5))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.3))
                }
                .padding()
                .contentShape(Rectangle())
                .softCard()
            }
            .buttonStyle(.plain)
        }
    }
    #endif
}


#if DEBUG
/// Presented when a full team tries to add another friend: pick who to bench
/// (they keep their level) so the newcomer can take a slot.
private struct ArenaSwapSheet: View {
    let incoming: Catch
    let team: [Catch]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Text("Your team is full. Bench a friend — they keep every level they earned — and \(incoming.displayName) takes the slot.")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 2)
                        ForEach(team, id: \.persistentModelID) { member in
                            let away = !BattleRoster.shared.canBench(member)
                            Button {
                                BattleRoster.shared.swap(out: member, incoming: incoming)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    PortraitCircle(friend: member,
                                                   type: BattleType(habitat: member.effectiveZone),
                                                   monogram: String(member.displayName.prefix(1)), size: 46)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.displayName)
                                            .font(.system(.body, design: .rounded, weight: .bold))
                                            .foregroundStyle(Theme.ink)
                                        if let p = BattleRoster.shared.progress(for: member) {
                                            Text("Lv \(p.level)")
                                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                                .foregroundStyle(Theme.ink.opacity(0.5))
                                        }
                                    }
                                    Spacer()
                                    Text(away ? "Away" : "Bench")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(away ? Theme.ink.opacity(0.35) : Theme.accent)
                                }
                                .padding()
                                .contentShape(Rectangle())
                                .softCard()
                            }
                            .buttonStyle(.plain)
                            .disabled(away)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Swap into the Arena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }
}
#endif
