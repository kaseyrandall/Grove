import SwiftData

/// Per-friend customization the player controls: a nickname and, optionally, a
/// different Grove zone to keep them in. One row per species (keyed by
/// `speciesID`); absent means "use the catalog defaults".
@Model
final class FriendProfile {
    @Attribute(.unique) var speciesID: String
    var nickname: String?
    /// A `Habitat.rawValue` when the player has moved this friend; nil = default.
    var zoneOverrideRaw: String?

    init(speciesID: String, nickname: String? = nil, zoneOverrideRaw: String? = nil) {
        self.speciesID = speciesID
        self.nickname = nickname
        self.zoneOverrideRaw = zoneOverrideRaw
    }

    /// The player's chosen zone, if any (computed from the stored raw value).
    var zoneOverride: Habitat? {
        get { zoneOverrideRaw.flatMap(Habitat.init(rawValue:)) }
        set { zoneOverrideRaw = newValue?.rawValue }
    }
}
