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
}
