import Foundation
import SwiftData

/// A single friend the player met — one photo, one individual. Its *kind* is a
/// catalog `Species` (Cat, Fox…) that gives it art, rarity, and lore, but each
/// catch is its own friend you can name, place, and release. Player stats
/// (sparks, level, counts) are all derived from the set of `Catch` records.
///
/// Every stored property is optional or has a default here (not just in
/// `init`): iCloud sync requires it. Defaults don't change the store's schema.
@Model
final class Catch {
    /// Stable id of the matched `Species` — this friend's *kind*.
    var speciesID: String = Species.mystery.id
    var caughtAt: Date = Date.now
    var sparksEarned: Int = 0
    /// True if this was the first friend of its kind the player met (spark bonus).
    var isFirstSighting: Bool = false

    /// A personal nickname the player gave this individual friend.
    var nickname: String?

    /// A `Habitat.rawValue` once the player has chosen where this friend lives
    /// (any zone: a fox can live at Home). nil means they haven't chosen, so it
    /// falls back to its kind's usual zone. Changing the animal never moves a
    /// friend whose zone was chosen.
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

    /// How the player framed the photo for its cards: the point of the photo
    /// kept in the middle (0…1 across and down) and how far it's zoomed in.
    /// All nil means "not cropped" — cards centre the photo. The photo itself
    /// is never cut; see `framing`.
    var cropCenterX: Double?
    var cropCenterY: Double?
    var cropZoom: Double?

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

    /// The zone the player chose for this friend, if they have.
    var zoneOverride: Habitat? {
        get { zoneOverrideRaw.flatMap(Habitat.init(rawValue:)) }
        set { zoneOverrideRaw = newValue?.rawValue }
    }

    /// Where this friend currently lives in the Grove.
    var effectiveZone: Habitat { zoneOverride ?? species.zone }

    /// The player's crop for this friend's cards, if they've set one.
    var framing: PhotoFraming? {
        get {
            guard let x = cropCenterX, let y = cropCenterY, let zoom = cropZoom else { return nil }
            return PhotoFraming(centerX: x, centerY: y, zoom: zoom)
        }
        set {
            cropCenterX = newValue?.centerX
            cropCenterY = newValue?.centerY
            cropZoom = newValue?.zoom
        }
    }

    /// "Met at Cathedral Hill" when the place is known, otherwise "Where you met".
    var meetingPlaceLabel: String {
        if let placeName, !placeName.isEmpty { return "Met at \(placeName)" }
        return "Where you met"
    }

    /// What to call this friend — their nickname if set, otherwise their kind.
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return species.name
    }
}
