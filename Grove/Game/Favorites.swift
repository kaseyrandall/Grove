import Foundation
import SwiftData

/// The friends a player pins to their Profile. Stored on each friend
/// (`Catch.favoritedAt`), so favorites follow them through iCloud.
enum Favorites {
    /// How many friends fit on the Profile shelf.
    static let limit = 3

    /// The pinned friends, oldest-pinned first.
    static func of(_ catches: [Catch]) -> [Catch] {
        catches
            .filter { $0.favoritedAt != nil }
            .sorted { ($0.favoritedAt ?? .distantPast) < ($1.favoritedAt ?? .distantPast) }
    }

    /// Pin or unpin a friend. Returns false (and changes nothing) when the
    /// shelf is already full.
    @discardableResult
    static func toggle(_ friend: Catch, among catches: [Catch], context: ModelContext) -> Bool {
        if friend.favoritedAt != nil {
            friend.favoritedAt = nil
        } else {
            guard of(catches).count < limit else { return false }
            friend.favoritedAt = .now
        }
        try? context.save()
        return true
    }
}

#if DEBUG
/// "Player view": hides the developer-only bits (Battlegrounds, the test
/// tools) so screens look the way they do in the App Store build. Long-press
/// the version number on the Profile to bring the tools back.
enum DevPreview {
    static let playerViewKey = "devPlayerView"
}
#endif
