import Foundation
import SwiftData
import UIKit
import WidgetKit

/// What the Grove widget shows (Home Screen and StandBy): a handful of
/// friends with small photos, written into the app group the widget can read.
/// The widget never opens the Grove store itself. Keep this shape in step
/// with `GroveWidget/WidgetSnapshot.swift`.
struct WidgetSnapshot: Codable {
    struct Friend: Codable {
        let name: String
        let kind: String
        let emoji: String
        let place: String?
        let metOn: Date
        let isFavorite: Bool
        /// File name of the photo in the snapshot folder.
        let photo: String
    }
    let friends: [Friend]
    let challenge: String
    let writtenAt: Date

    static let appGroup = "group.com.kaseyrandall.grove"
    static let folderName = "WidgetSnapshot"
    static let fileName = "snapshot.json"
    /// How many friends the widget cycles through.
    static let limit = 8

    static var folder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(folderName, isDirectory: true)
    }
}

/// Refreshes the widget's snapshot from the Grove: favorites first, then the
/// rarest and newest friends with photos. Cheap to call often; it only
/// rewrites when something the widget shows has changed.
@MainActor
enum WidgetSnapshotWriter {
    private static var lastSignature = ""

    static func refresh(catches: [Catch]) {
        guard let folder = WidgetSnapshot.folder else { return }
        let withPhotos = catches.filter { $0.photoData != nil }
        let favorites = Favorites.of(withPhotos)
        let rest = withPhotos.filter { $0.favoritedAt == nil }.sorted {
            $0.species.rarity != $1.species.rarity
                ? $0.species.rarity > $1.species.rarity
                : $0.caughtAt > $1.caughtAt
        }
        let picks = Array((favorites + rest).prefix(WidgetSnapshot.limit))
        let challenge = DailyChallenge.today()
        let signature = picks.map { "\($0.persistentModelID.hashValue)|\($0.displayName)|\($0.favoritedAt != nil)|\($0.cropZoom ?? 0)" }
            .joined(separator: ",") + challenge.id + Date.now.formatted(.iso8601.year().month().day())
        guard signature != lastSignature else { return }
        lastSignature = signature

        let fm = FileManager.default
        try? fm.removeItem(at: folder)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        var friends: [WidgetSnapshot.Friend] = []
        for (i, friend) in picks.enumerated() {
            guard let data = friend.photoData, let image = UIImage(data: data),
                  let thumb = thumbnail(image, framing: friend.framing)?.jpegData(compressionQuality: 0.8) else { continue }
            let name = "friend-\(i).jpg"
            try? thumb.write(to: folder.appendingPathComponent(name), options: .atomic)
            friends.append(.init(name: friend.displayName, kind: friend.species.name, emoji: friend.species.emoji,
                                 place: friend.placeName, metOn: friend.caughtAt,
                                 isFavorite: friend.favoritedAt != nil, photo: name))
        }
        let snapshot = WidgetSnapshot(friends: friends,
                                      challenge: "\(challenge.emoji) \(challenge.title)",
                                      writtenAt: .now)
        if let json = try? JSONEncoder().encode(snapshot) {
            try? json.write(to: folder.appendingPathComponent(WidgetSnapshot.fileName), options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// A square ~600 px crop honoring the player's framing (widgets have a
    /// tight memory budget, so full photos are too big).
    private static func thumbnail(_ image: UIImage, framing: PhotoFraming?) -> UIImage? {
        let side: CGFloat = 600
        let size = CGSize(width: side, height: side)
        let placed = (framing ?? PhotoFraming()).layout(photo: image.size, in: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: placed.origin, size: placed.size))
        }
    }
}
