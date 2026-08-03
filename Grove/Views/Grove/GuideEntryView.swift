import SwiftUI
import SwiftData

/// A field-guide page for one friend: its story, where it lives in your Grove,
/// your history with it, and the personal touches you've given it.
struct GuideEntryView: View {
    let species: Species
    let catches: [Catch]

    @Query private var profiles: [FriendProfile]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showEdit = false
    @State private var showReleaseConfirm = false

    private var profile: FriendProfile? { profiles.first { $0.speciesID == species.id } }

    private var isCaught: Bool { !catches.isEmpty }
    private var earliest: Catch? { catches.min { $0.caughtAt < $1.caughtAt } }
    private var latest: Catch? { catches.max { $0.caughtAt < $1.caughtAt } }
    private var totalSparks: Int { catches.reduce(0) { $0 + $1.sparksEarned } }

    /// Nickname from the friend's profile, falling back to any set on a catch.
    private var nickname: String? { profile?.nickname ?? earliest?.nickname }
    /// Where the friend lives — the player's chosen zone or the catalog default.
    private var zone: Habitat { profile?.zoneOverride ?? species.zone }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    nameBlock
                    if isCaught { metaRow }
                    infoCard
                    if isCaught { sightingsCard }
                    if isCaught { releaseButton }
                }
                .padding()
            }
        }
        .navigationTitle(isCaught ? species.name : "Not yet spotted")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Release \(species.name)?", isPresented: $showReleaseConfirm, titleVisibility: .visible) {
            Button("Release back to the wild", role: .destructive) { release() }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("They'll leave your Grove and their sightings will be let go. You can always meet them again out in the wild.")
        }
        .toolbar {
            if isCaught {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditFriendView(
                species: species,
                currentNickname: nickname ?? "",
                currentZone: zone
            )
        }
    }

    // MARK: Hero — a fixed, cropped card so every friend looks consistent.

    private var hero: some View {
        ZStack {
            zone.gradient

            if let data = latest?.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(species.emoji)
                    .font(.system(size: 92))
                    .opacity(isCaught ? 1 : 0.4)
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topLeading) {
            RarityBadge(rarity: species.rarity).padding(12)
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
    }

    // MARK: Name + nickname

    private var nameBlock: some View {
        VStack(spacing: 4) {
            Text(species.name)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)

            if isCaught {
                Button { showEdit = true } label: {
                    if let nickname, !nickname.isEmpty {
                        Text("you named it “\(nickname)”  ✎")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    } else {
                        Label("Give it a nickname", systemImage: "pencil")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    // MARK: Meta

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaTile(value: earliest.map { $0.caughtAt.formatted(.dateTime.month().day()) } ?? "—",
                     label: "First met")
            metaTile(value: "\(catches.count)×", label: "Times seen")
            metaTile(value: "\(totalSparks) ✨", label: "Sparks")
        }
    }

    private func metaTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .softCard()
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(spacing: 12) {
            Text(isCaught ? species.blurb : "You haven't spotted this friend yet. Keep exploring!")
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

    // MARK: Release

    private var releaseButton: some View {
        Button { showReleaseConfirm = true } label: {
            Text("🍃 Release \(species.name) back to the wild")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.45))
        }
        .padding(.top, 6)
    }

    /// Let this friend go: remove their sightings and any customization, then
    /// leave the page. Their sparks were derived from those catches, so the
    /// player's totals adjust naturally.
    private func release() {
        for sighting in catches {
            context.delete(sighting)
        }
        if let profile {
            context.delete(profile)
        }
        try? context.save()
        dismiss()
    }

    // MARK: Sightings

    private var sightingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your photos (\(catches.count))")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catches.sorted { $0.caughtAt > $1.caughtAt }) { c in
                        VStack(spacing: 6) {
                            if let data = c.photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.ink.opacity(0.06))
                                    .frame(width: 96, height: 96)
                                    .overlay(Text(species.emoji).font(.largeTitle))
                            }
                            Text(c.caughtAt, format: .dateTime.month().day())
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}
