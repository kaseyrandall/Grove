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

    /// The open Duo in landscape: what you tap opens in a panel on the right
    /// page, beside the map, instead of a sheet over the fold.
    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX

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
                                Button { selected = c; selectedCluster = nil } label: { MapPin(species: c.species) }
                            } else {
                                Button { selectedCluster = cluster; selected = nil } label: { ClusterBubble(catches: cluster.catches) }
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

                if isSpread, let panel = sidePanel {
                    GeometryReader { geo in
                        let pages = DuoSpread.pageWidths(in: geo.frame(in: .global), foldX: foldX,
                                                         leading: 16, trailing: 16)
                        panel
                            .frame(width: pages.trailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                            .padding(.vertical, 16)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selected?.persistentModelID)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedCluster?.id)
            .clearsGroveTabBar()
            #if DEBUG
            // Test hook: `-GroveMapSelect friend|cluster` selects a pin on launch.
            .task {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "-GroveMapSelect"), i + 1 < args.count else { return }
                try? await Task.sleep(for: .milliseconds(800))
                if args[i + 1] == "cluster" {
                    selectedCluster = clusters.max { $0.catches.count < $1.catches.count }
                } else {
                    selected = geotagged.max { $0.species.rarity < $1.species.rarity }
                }
            }
            #endif
            .navigationTitle("Discovery Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: isSpread ? .constant(nil) : $selected) { friend in
                NavigationStack { GuideEntryView(friend: friend) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: isSpread ? .constant(nil) : $selectedCluster) { cluster in
                NavigationStack { ClusterListView(cluster: cluster) }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// The right-page panel for whatever's selected (nil when nothing is).
    private var sidePanel: MapSidePanel? {
        let close = { selected = nil; selectedCluster = nil }
        if let friend = selected {
            return MapSidePanel(title: friend.placeName ?? friend.displayName,
                                friends: [friend], onClose: close)
        }
        if let cluster = selectedCluster {
            return MapSidePanel(title: ClusterListView.title(for: cluster),
                                friends: cluster.catches, onClose: close)
        }
        return nil
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

    private var title: String { Self.title(for: cluster) }

    /// The spot's place name when everyone was met in one place, else a count.
    static func title(for cluster: MapCluster) -> String {
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
                            MapFriendRow(friend: c)
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

}

/// One friend in a list of friends met at a spot.
struct MapFriendRow: View {
    let friend: Catch

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white)
                if let data = friend.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill().clipShape(Circle()).padding(2)
                } else {
                    Text(friend.species.emoji).font(.system(size: 22))
                }
            }
            .frame(width: 46, height: 46)
            .overlay(Circle().stroke(friend.species.rarity.tint, lineWidth: 2.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(friend.caughtAt.formatted(.dateTime.month().day().year()))
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

/// On the open Duo, what you tap on the map opens here, on the right page
/// beside the map: a preview of one friend, or everyone met at a spot. Each
/// friend opens its full page.
struct MapSidePanel: View {
    let title: String
    /// One friend, or everyone at a clustered spot.
    let friends: [Catch]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label(title, systemImage: "mappin.and.ellipse")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.ink.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 10) {
                    if friends.count == 1, let friend = friends.first {
                        preview(friend)
                    } else {
                        ForEach(friends) { friend in
                            NavigationLink {
                                GuideEntryView(friend: friend)
                            } label: {
                                MapFriendRow(friend: friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding([.horizontal, .bottom], 16)
            }
        }
        // Solid underneath: the app's wash is partly see-through, which would
        // let the map show through the text.
        .background(Theme.cream)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.18), radius: 18, y: 8)
    }

    /// A single friend at a glance, with a way into its full page.
    private func preview(_ friend: Catch) -> some View {
        let species = friend.species
        let zone = friend.effectiveZone
        return VStack(spacing: 14) {
            Color.clear
                .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    ZStack {
                        zone.gradient
                        if let data = friend.photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else {
                            Text(species.emoji).font(.system(size: 72))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topLeading) {
                    RarityBadge(rarity: species.rarity).padding(10)
                }

            VStack(spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Met \(friend.caughtAt.formatted(.dateTime.month().day())) · \(zone.emoji) \(zone.shortName) · \(friend.sparksEarned) ✨")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }

            Text(species.blurb)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            NavigationLink {
                GuideEntryView(friend: friend)
            } label: {
                Label("Open friend page", systemImage: "book.closed.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
        }
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
