import Foundation

/// What's new in each version, in Grove's own voice. The What's New sheet and
/// the "Grove just got new features" notification read from here, so adding a
/// release's highlights is the only step when shipping a version with news.
/// A version with no entry (a bug-fix build) updates quietly.
struct ReleaseNotes: Identifiable, Equatable {
    struct Item: Identifiable, Equatable {
        let emoji: String
        let title: String
        let detail: String
        var id: String { title }
    }

    /// Marketing version, e.g. "1.2".
    let version: String
    let items: [Item]
    var id: String { version }

    static func forVersion(_ version: String) -> ReleaseNotes? {
        all.first { $0.version == version }
    }

    static let all: [ReleaseNotes] = [
        ReleaseNotes(version: "1.2", items: [
            Item(emoji: "☁️", title: "Backed up to iCloud",
                 detail: "Your Grove lives in your own iCloud now, so it comes back on a new phone or after reinstalling."),
            Item(emoji: "🎉", title: "A cozier catch celebration",
                 detail: "Name your new friend right on the spot, then pick who it is and where it lives."),
            Item(emoji: "🏡", title: "You choose where friends live",
                 detail: "Any friend can move into any zone. Change it any time from Edit."),
            Item(emoji: "🌱", title: "Inviting empty zones",
                 detail: "Empty zones suggest who might visit and where to look."),
        ]),
    ]
}

extension String {
    /// Whether this version string is newer than `other`, comparing each
    /// number in turn ("1.10" is newer than "1.9"; "1.2" and "1.2.0" match).
    func isNewerVersion(than other: String) -> Bool {
        let mine = split(separator: ".").map { Int($0) ?? 0 }
        let theirs = other.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(mine.count, theirs.count) {
            let a = i < mine.count ? mine[i] : 0
            let b = i < theirs.count ? theirs[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}
