import SwiftUI
import SwiftData
import MapKit

/// A map of every place the player has caught a friend. Nearby catches cluster
/// into an avatar bubble (so a busy spot doesn't become a pile of overlapping
/// pins); tapping a single pin opens that friend, tapping a cluster lists them.
struct DiscoveryMapView: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]

    @State private var position: MapCameraPosition = .automatic
    @State private var span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    @State private var selected: Catch?
    @State private var selectedCluster: MapCluster?

    private var geotagged: [Catch] {
        catches.filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Group geotagged catches into clusters sized to the current zoom, so pins
    /// merge when zoomed out and separate as you zoom in.
    private var clusters: [MapCluster] {
        let bucket = max(span.latitudeDelta / 12, 0.00005)
        var groups: [String: [Catch]] = [:]
        for c in geotagged {
            guard let lat = c.latitude, let lng = c.longitude else { continue }
            let key = "\(Int((lat / bucket).rounded()))_\(Int((lng / bucket).rounded()))"
            groups[key, default: []].append(c)
        }
        return groups.map { key, members in
            let lat = members.reduce(0.0) { $0 + ($1.latitude ?? 0) } / Double(members.count)
            let lng = members.reduce(0.0) { $0 + ($1.longitude ?? 0) } / Double(members.count)
            return MapCluster(id: key, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), catches: members)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    ForEach(clusters) { cluster in
                        Annotation("", coordinate: cluster.coordinate) {
                            if cluster.catches.count == 1, let c = cluster.catches.first {
                                Button { selected = c } label: { MapPin(species: c.species) }
                            } else {
                                Button { selectedCluster = cluster } label: { ClusterBubble(catches: cluster.catches) }
                            }
                        }
                    }
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    span = context.region.span
                }

                if geotagged.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Discovery Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { friend in
                NavigationStack { GuideEntryView(friend: friend) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedCluster) { cluster in
                NavigationStack { ClusterListView(cluster: cluster) }
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
            Text("Catch a friend with Location turned on and it'll appear right here.")
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

/// A group of catches close together on the map.
struct MapCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let catches: [Catch]
}

/// A rarity-tinted pin with the friend's emoji (single catch).
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

/// A stack of avatars with a count, shown when several friends share a spot.
struct ClusterBubble: View {
    let catches: [Catch]

    var body: some View {
        HStack(spacing: -14) {
            ForEach(Array(catches.prefix(3).enumerated()), id: \.element.persistentModelID) { index, c in
                miniAvatar(c).zIndex(Double(3 - index))
            }
        }
        .overlay(alignment: .topTrailing) {
            Text("\(catches.count)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Theme.accent))
                .offset(x: 10, y: -8)
        }
        .shadow(color: Theme.ink.opacity(0.22), radius: 4, y: 2)
    }

    private func miniAvatar(_ c: Catch) -> some View {
        ZStack {
            Circle().fill(.white)
            if let data = c.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill().clipShape(Circle()).padding(3)
            } else {
                Text(c.species.emoji).font(.system(size: 18))
            }
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().stroke(c.species.rarity.tint, lineWidth: 2.5))
        .background(Circle().fill(.white).padding(-2)) // white gap between overlapping avatars
    }
}

/// The list of friends sharing one spot, shown from a cluster tap.
struct ClusterListView: View {
    let cluster: MapCluster

    private var title: String {
        let places = Set(cluster.catches.compactMap { $0.placeName })
        if places.count == 1, let p = places.first { return p }
        return "\(cluster.catches.count) friends here"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(cluster.catches) { c in
                        NavigationLink {
                            GuideEntryView(friend: c)
                        } label: {
                            row(c)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ c: Catch) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white)
                if let data = c.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill().clipShape(Circle()).padding(2)
                } else {
                    Text(c.species.emoji).font(.system(size: 22))
                }
            }
            .frame(width: 46, height: 46)
            .overlay(Circle().stroke(c.species.rarity.tint, lineWidth: 2.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(c.displayName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(c.caughtAt.formatted(.dateTime.month().day().year()))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.ink.opacity(0.25))
        }
        .padding()
        .softCard()
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
