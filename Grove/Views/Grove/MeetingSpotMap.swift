import SwiftUI
import SwiftData
import MapKit

/// The "Where you met" card, opened up: a full map of the spot where you met a
/// friend that you can move around, with your other friends' pins for company.
/// It opens over the friend page, so closing it puts you right back there.
struct MeetingSpotMap: View {
    let friend: Catch

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var allCatches: [Catch]
    @State private var position: MapCameraPosition

    init(friend: Catch) {
        self.friend = friend
        let spot = CLLocationCoordinate2D(latitude: friend.latitude ?? 0, longitude: friend.longitude ?? 0)
        _position = State(initialValue: .region(MKCoordinateRegion(center: spot,
                                                                   latitudinalMeters: 900,
                                                                   longitudinalMeters: 900)))
    }

    private var spot: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: friend.latitude ?? 0, longitude: friend.longitude ?? 0)
    }

    /// Everyone else with a spot on the map.
    private var others: [Catch] {
        allCatches.filter { $0 !== friend && $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        Map(position: $position) {
            ForEach(others, id: \.persistentModelID) { other in
                Annotation(other.displayName,
                           coordinate: CLLocationCoordinate2D(latitude: other.latitude ?? 0,
                                                              longitude: other.longitude ?? 0)) {
                    MapPin(species: other.species)
                        .scaleEffect(0.75)
                        .opacity(0.85)
                }
            }
            // This friend last, so their pin sits on top.
            Annotation(friend.displayName, coordinate: spot) {
                MapPin(species: friend.species).scaleEffect(1.25)
            }
        }
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom) { openInMapsButton }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(friend.meetingPlaceLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(friend.displayName) · \(friend.caughtAt.formatted(.dateTime.month().day().year()))")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(.white))
            .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 2)

            Spacer(minLength: 0)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white))
                    .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 2)
            }
            .accessibilityLabel("Close map")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var openInMapsButton: some View {
        Button {
            var parts = URLComponents(string: "https://maps.apple.com/")
            parts?.queryItems = [
                URLQueryItem(name: "ll", value: "\(spot.latitude),\(spot.longitude)"),
                URLQueryItem(name: "q", value: friend.placeName ?? "Where you met \(friend.displayName)"),
            ]
            if let url = parts?.url { openURL(url) }
        } label: {
            Label("Open in Maps", systemImage: "arrow.up.right.square")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Capsule().fill(.white))
                .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 2)
        }
        .padding(.bottom, 10)
    }
}
