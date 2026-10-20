import WidgetKit
import SwiftUI

/// One moment in the widget's day: which friend to show.
struct FriendEntry: TimelineEntry {
    let date: Date
    let friend: WidgetSnapshot.Friend?
    let photo: UIImage?
    let challenge: String
}

/// Reads the snapshot the app wrote to the app group and steps through the
/// friends, one every half hour.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> FriendEntry {
        FriendEntry(date: .now, friend: nil, photo: nil, challenge: "🐾 Meet a friend today")
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendEntry) -> Void) {
        completion(entries(from: .now).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendEntry>) -> Void) {
        let list = entries(from: .now)
        completion(Timeline(entries: list.isEmpty ? [placeholder(in: context)] : list, policy: .atEnd))
    }

    private func entries(from start: Date) -> [FriendEntry] {
        guard let folder = WidgetSnapshot.folder,
              let data = try? Data(contentsOf: folder.appendingPathComponent(WidgetSnapshot.fileName)),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return [] }
        guard !snapshot.friends.isEmpty else {
            return [FriendEntry(date: start, friend: nil, photo: nil, challenge: snapshot.challenge)]
        }
        // Start on a different friend each half hour, so it isn't always the first.
        let slot = Int(start.timeIntervalSince1970 / 1800)
        return (0..<snapshot.friends.count).map { step in
            let friend = snapshot.friends[(slot + step) % snapshot.friends.count]
            let photo = UIImage(contentsOfFile: folder.appendingPathComponent(friend.photo).path)
            return FriendEntry(date: start.addingTimeInterval(Double(step) * 1800),
                               friend: friend, photo: photo, challenge: snapshot.challenge)
        }
    }
}

struct GroveWidgetEntryView: View {
    var entry: FriendEntry
    @Environment(\.widgetFamily) private var family

    private let ink = Color(red: 0x4A / 255, green: 0x44 / 255, blue: 0x58 / 255)
    private let accent = Color(red: 1, green: 0x7E / 255, blue: 0xA6 / 255)

    var body: some View {
        if let friend = entry.friend, let photo = entry.photo {
            switch family {
            case .systemMedium: medium(friend, photo)
            default:            small(friend, photo)
            }
        } else {
            empty
        }
    }

    /// The photo edge to edge, the name over a soft fade.
    private func small(_ friend: WidgetSnapshot.Friend, _ photo: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: photo).resizable().scaledToFill()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(friend.name).font(.system(.headline, design: .rounded, weight: .heavy))
                    if friend.isFavorite { Image(systemName: "heart.fill").font(.caption2).foregroundStyle(accent) }
                }
                // A nicknamed friend shows its kind; otherwise the name already
                // is the kind, so show when you met.
                Text(friend.name == friend.kind
                     ? "\(friend.emoji) \(friend.metOn.formatted(.dateTime.month(.abbreviated).day()))"
                     : "\(friend.emoji) \(friend.kind)")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(12)
        }
    }

    /// Photo on the left; name, where and when, and today's challenge on the right.
    private func medium(_ friend: WidgetSnapshot.Friend, _ photo: UIImage) -> some View {
        HStack(spacing: 14) {
            Image(uiImage: photo).resizable().scaledToFill()
                .frame(width: 130)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR GROVE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.45))
                HStack(spacing: 4) {
                    Text(friend.name).font(.system(.title3, design: .rounded, weight: .heavy))
                    if friend.isFavorite { Image(systemName: "heart.fill").font(.caption).foregroundStyle(accent) }
                }
                .foregroundStyle(ink)
                if friend.name != friend.kind {
                    Text("\(friend.emoji) \(friend.kind)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.7))
                }
                Text(caption(friend))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(entry.challenge)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("🌳").font(.system(size: 40))
            Text("Snap your first friend")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(ink.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func caption(_ friend: WidgetSnapshot.Friend) -> String {
        let date = friend.metOn.formatted(.dateTime.month(.abbreviated).day().year())
        if let place = friend.place, !place.isEmpty { return "Met at \(place) · \(date)" }
        return "Met \(date)"
    }
}

struct GroveWidget: Widget {
    let kind = "GroveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GroveWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 1, green: 0.97, blue: 0.94),
                                            Color(red: 0.86, green: 0.94, blue: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Grove friends")
        .description("Your favorite friends, taking turns through the day.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
