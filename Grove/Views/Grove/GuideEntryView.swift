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

    private var species: Species { friend.species }
    private var zone: Habitat { friend.effectiveZone }
    private var nickname: String? { friend.nickname }
    private var isMystery: Bool { species.id == Species.mystery.id }

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
                }
                .padding()
                .padding(.bottom, Theme.tabBarClearance)
            }
        }
        .navigationTitle(species.name)
        .navigationBarTitleDisplayMode(.inline)
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
        ZStack {
            zone.gradient

            if let data = friend.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(species.emoji)
                    .font(.system(size: 92))
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

            Button { showEdit = true } label: {
                if isMystery {
                    Label("Tap to identify this friend", systemImage: "questionmark.circle.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.accent)
                } else if let nickname, !nickname.isEmpty {
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

    // MARK: Meta

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaTile(value: friend.caughtAt.formatted(.dateTime.month().day()), label: "Met")
            metaTile(value: "\(species.rarity.badge) \(species.rarity.fieldTerm)", label: "Rarity")
            metaTile(value: "\(friend.sparksEarned) ✨", label: "Sparks")
        }
    }

    private func metaTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
}
