import SwiftUI
import SwiftData
import MapKit

/// A map of every place the player has caught a critter. Each geotagged catch
/// drops a cute, rarity-colored pin; tapping one opens that critter's page.
struct DiscoveryMapView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]

    @State private var position: MapCameraPosition = .automatic
    @State private var selected: Catch?

    /// Only catches that actually have coordinates.
    private var geotagged: [Catch] {
        catches.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    ForEach(geotagged) { c in
                        Annotation(c.species.name, coordinate: c.coordinate) {
                            Button {
                                selected = c
                            } label: {
                                MapPin(species: c.species)
                            }
                        }
                    }
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }

                if geotagged.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Discovery Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { c in
                NavigationStack {
                    CreatureDetailView(
                        species: c.species,
                        catches: catches.filter { $0.speciesID == c.speciesID }
                    )
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🗺️").font(.system(size: 56))
            Text("No sightings on the map yet")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Catch a critter with Location turned on and it'll appear right here.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(28)
        .softCard()
        .padding()
    }
}

/// A rarity-tinted teardrop pin with the critter's emoji.
struct MapPin: View {
    let species: Species

    var body: some View {
        Text(species.emoji)
            .font(.system(size: 22))
            .padding(8)
            .background(
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(species.rarity.tint, lineWidth: 4))
            )
            .shadow(color: Theme.ink.opacity(0.25), radius: 4, y: 2)
    }
}

extension Catch {
    /// Convenience coordinate for map annotations. Falls back to (0,0) — callers
    /// should only use this for catches known to be geotagged.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude ?? 0, longitude: longitude ?? 0)
    }
}

#Preview {
    DiscoveryMapView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
