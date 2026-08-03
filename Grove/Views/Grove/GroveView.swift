import SwiftUI
import SwiftData

/// The Grove — the heart of Grove. Friends you've photographed come home and
/// settle into the habitat zone they belong to. Replaces the old flat "Dex":
/// no `???` silhouettes, just a cozy world that fills with life as you explore.
struct GroveView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]

    private var friendCount: Int { Set(catches.map(\.speciesID)).count }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    header
                        .padding(.horizontal)
                        .padding(.top, 4)

                    VStack(spacing: 14) {
                        ForEach(Habitat.ordered) { zone in
                            ZoneCard(zone: zone, catches: catches)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Your Grove")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("🌳").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 1) {
                Text(friendCount == 0
                     ? "Your Grove is waiting"
                     : "\(friendCount) friend\(friendCount == 1 ? "" : "s") have visited")
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
}

/// One habitat zone in the Grove, with its resident friends.
struct ZoneCard: View {
    let zone: Habitat
    let catches: [Catch]

    private var zoneSpecies: [Species] { CreatureCatalog.species(in: zone) }
    private var caughtIDs: Set<String> { Set(catches.map(\.speciesID)) }
    private var residents: [Species] { zoneSpecies.filter { caughtIDs.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(zone.emoji) \(zone.displayName)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(residents.count) friend\(residents.count == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }

            if residents.isEmpty {
                HStack {
                    Spacer()
                    Text("a quiet spot, waiting for its first visitor…")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.45))
                    Spacer()
                }
                .frame(height: 84)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(residents.enumerated()), id: \.element.id) { index, species in
                            NavigationLink {
                                GuideEntryView(
                                    species: species,
                                    catches: catches.filter { $0.speciesID == species.id }
                                )
                            } label: {
                                ResidentPortrait(
                                    species: species,
                                    photoData: latestPhoto(for: species.id),
                                    nickname: nickname(for: species.id),
                                    index: index
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(height: 84)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(zone.gradient)
        )
        .shadow(color: Theme.ink.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    // catches is sorted newest-first, so the first photo hit is the latest one.
    private func latestPhoto(for id: String) -> Data? {
        catches.first { $0.speciesID == id && $0.photoData != nil }?.photoData
    }

    // The species' nickname is whatever the player named their first sighting.
    private func nickname(for id: String) -> String? {
        catches
            .filter { $0.speciesID == id }
            .min { $0.caughtAt < $1.caughtAt }?
            .nickname
    }
}

/// A round photo portrait of a resident, ringed in its rarity color, gently
/// floating in place so the Grove feels alive. Each portrait is staggered by
/// its position so they don't bob in unison.
struct ResidentPortrait: View {
    let species: Species
    let photoData: Data?
    let nickname: String?
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    // Slightly different rhythm per friend for an organic, un-synced feel.
    private var duration: Double { 2.0 + Double(index % 3) * 0.35 }
    private var startDelay: Double { Double(index) * 0.28 }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(.white)
                if let photoData, let ui = UIImage(data: photoData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .padding(3)
                } else {
                    Text(species.emoji).font(.system(size: 26))
                }
            }
            .frame(width: 56, height: 56)
            .overlay(Circle().stroke(species.rarity.tint, lineWidth: 3))
            .shadow(color: Theme.ink.opacity(0.15),
                    radius: floating ? 5 : 3,
                    y: floating ? 5 : 2)
            .rotationEffect(.degrees(floating ? 2.5 : -2.5))
            .offset(y: floating ? -4 : 3)

            Text(nickname ?? species.name)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: 66)
        }
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
