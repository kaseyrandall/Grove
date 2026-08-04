import Foundation
import SwiftData

/// A single friend the player met — one photo, one individual. Its *kind* is a
/// catalog `Species` (Cat, Fox…) that gives it art, rarity, and lore, but each
/// catch is its own friend you can name, place, and release. Player stats
/// (sparks, level, counts) are all derived from the set of `Catch` records.
@Model
final class Catch {
    /// Stable id of the matched `Species` — this friend's *kind*.
    var speciesID: String
    var caughtAt: Date
    var sparksEarned: Int
    /// True if this was the first friend of its kind the player met (spark bonus).
    var isFirstSighting: Bool

    /// A personal nickname the player gave this individual friend.
    var nickname: String?

    /// A `Habitat.rawValue` when the player has moved this friend to a different
    /// Grove zone; nil means "live in the kind's default zone".
    var zoneOverrideRaw: String?

    /// The player's photo. `.externalStorage` keeps large blobs out of the
    /// main store file for performance.
    @Attribute(.externalStorage) var photoData: Data?

    /// Where it was spotted, if location was available.
    var latitude: Double?
    var longitude: Double?
    /// A human-readable place for the coordinates (reverse-geocoded), e.g. a
    /// park or neighborhood. Filled in shortly after the catch.
    var placeName: String?

    init(
        speciesID: String,
        caughtAt: Date = .now,
        sparksEarned: Int,
        isFirstSighting: Bool,
        nickname: String? = nil,
        zoneOverrideRaw: String? = nil,
        photoData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil
    ) {
        self.speciesID = speciesID
        self.caughtAt = caughtAt
        self.sparksEarned = sparksEarned
        self.isFirstSighting = isFirstSighting
        self.nickname = nickname
        self.zoneOverrideRaw = zoneOverrideRaw
        self.photoData = photoData
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
    }

    /// This friend's kind (catalog entry).
    var species: Species {
        CreatureCatalog.species(for: speciesID) ?? .mystery
    }

    /// The player's chosen zone for this friend, if any.
    var zoneOverride: Habitat? {
        get { zoneOverrideRaw.flatMap(Habitat.init(rawValue:)) }
        set { zoneOverrideRaw = newValue?.rawValue }
    }

    /// Where this friend currently lives in the Grove.
    var effectiveZone: Habitat { zoneOverride ?? species.zone }

    /// What to call this friend — their nickname if set, otherwise their kind.
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return species.name
    }
}
