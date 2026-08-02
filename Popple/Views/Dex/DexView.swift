import SwiftUI
import SwiftData

/// The collection screen — a grid of every critter, filling in as you catch them.
/// The empty silhouettes are the whole hook: you *want* to complete the set.
struct DexView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    /// Set of species ids the player has caught at least once.
    private var caughtIDs: Set<String> {
        Set(catches.map(\.speciesID))
    }

    /// Most recent photo per species, for the filled-in tiles.
    private var latestPhoto: [String: Data] {
        var map: [String: Data] = [:]
        for c in catches where map[c.speciesID] == nil {
            if let data = c.photoData { map[c.speciesID] = data }
        }
        return map
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    progressHeader
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CreatureCatalog.all) { species in
                            NavigationLink {
                                CreatureDetailView(
                                    species: species,
                                    catches: catches.filter { $0.speciesID == species.id }
                                )
                            } label: {
                                DexTile(
                                    species: species,
                                    isCaught: caughtIDs.contains(species.id),
                                    photoData: latestPhoto[species.id]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Dex")
        }
    }

    private var progressHeader: some View {
        let caught = caughtIDs.intersection(Set(CreatureCatalog.all.map(\.id))).count
        let total = CreatureCatalog.all.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Collection")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(caught)/\(total)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            ProgressView(value: Double(caught), total: Double(max(total, 1)))
                .tint(Theme.accent)
        }
        .padding()
        .softCard()
    }
}

/// A single square in the Dex grid.
struct DexTile: View {
    let species: Species
    let isCaught: Bool
    let photoData: Data?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isCaught ? species.rarity.tint.opacity(0.5) : Theme.ink.opacity(0.06))

                if isCaught, let photoData, let ui = UIImage(data: photoData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if isCaught {
                    Text(species.emoji).font(.system(size: 40))
                } else {
                    Text("❓")
                        .font(.system(size: 36))
                        .opacity(0.4)
                }
            }
            .frame(height: 100)
            .overlay(alignment: .topTrailing) {
                if isCaught {
                    Text(species.rarity.badge)
                        .font(.caption)
                        .padding(5)
                        .background(Circle().fill(.white.opacity(0.9)))
                        .padding(6)
                }
            }

            Text(isCaught ? species.name : "???")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(isCaught ? 1 : 0.4))
                .lineLimit(1)
        }
    }
}

#Preview {
    DexView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
