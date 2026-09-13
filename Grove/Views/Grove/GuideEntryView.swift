import SwiftUI
import SwiftData

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
    @Query private var allCatches: [Catch]

    private var species: Species { friend.species }
    private var zone: Habitat { friend.effectiveZone }
    private var nickname: String? { friend.nickname }
    private var isMystery: Bool { species.id == Species.mystery.id }
    private var heroImage: UIImage? { friend.photoData.flatMap(UIImage.init(data:)) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    nameBlock
                    if let place = friend.placeName, !place.isEmpty {
                        Label("Met at \(place)", systemImage: "mappin.and.ellipse")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    }
                    metaRow
                    infoCard
                    #if DEBUG
                    arenaSection
                    #endif
                }
                .padding()
                .padding(.bottom, Theme.tabBarClearance)
            }
        }
        .navigationTitle("\(species.emoji) \(species.name)")
        .navigationBarTitleDisplayMode(.inline)
        .groveTabBarHidden()
        .photoLightbox(isPresented: $showPhoto, image: heroImage)
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
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
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
                context.delete(friend)
                try? context.save()
                dismiss()
            }
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
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(species.emoji)
                            .font(.system(size: 92))
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
            // don't repeat it here.
            Text(friend.displayName)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Button { showEdit = true } label: {
                if isMystery {
                    Label("Tap to identify this friend", systemImage: "questionmark.circle.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.accent)
                } else if let nickname, !nickname.isEmpty {
                    Label("Tap to rename", systemImage: "pencil")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.4))
                } else {
                    Label("Give it a nickname", systemImage: "pencil")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: Meta

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaTile(value: friend.caughtAt.formatted(.dateTime.month().day()), label: "Met")
            metaTile(value: "\(species.rarity.badge) \(species.rarity.fieldTerm)", label: "Rarity")
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
                Button(role: .destructive) { roster.bench(friend) } label: {
                    Text("Remove from team")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .softCard()
        } else {
            Button {
                if roster.hasFreeSlot { roster.promote(friend) } else { showSwap = true }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(roster.hasFreeSlot ? "Send to the Arena" : "Arena team full — swap someone")
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
                            Button {
                                BattleRoster.shared.swap(out: member, incoming: incoming)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    PortraitCircle(photoData: member.photoData,
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
                                    Text("Bench")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                                .padding()
                                .contentShape(Rectangle())
                                .softCard()
                            }
                            .buttonStyle(.plain)
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
