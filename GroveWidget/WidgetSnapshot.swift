import Foundation

/// What the Grove widget shows (Home Screen and StandBy): a handful of
/// friends with small photos, written into the app group the widget can read.
/// The widget never opens the Grove store itself. Keep this shape in step
/// with `Grove/Services/WidgetSnapshot.swift` in the app.
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
