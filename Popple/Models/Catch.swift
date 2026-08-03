import Foundation
import SwiftData

/// A single photo the player took of a friend — one entry in their journal.
/// This is the only thing we persist; player stats (sparks, level, dex progress)
/// are derived from the full set of `Catch` records.
@Model
final class Catch {
    /// Stable id of the matched `Species` (see `CreatureCatalog`).
    var speciesID: String
    var caughtAt: Date
    var sparksEarned: Int
    /// True if this was the first time the player ever caught this species.
    var isFirstSighting: Bool

    /// A personal nickname the player gave this friend. Set on the first
    /// sighting; the earliest catch's nickname acts as the species' nickname.
    var nickname: String?

    /// The player's photo. `.externalStorage` keeps large blobs out of the
    /// main store file for performance.
    @Attribute(.externalStorage) var photoData: Data?

    /// Where it was spotted, if location was available.
    var latitude: Double?
    var longitude: Double?

    init(
        speciesID: String,
        caughtAt: Date = .now,
        sparksEarned: Int,
        isFirstSighting: Bool,
        nickname: String? = nil,
        photoData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.speciesID = speciesID
        self.caughtAt = caughtAt
        self.sparksEarned = sparksEarned
        self.isFirstSighting = isFirstSighting
        self.nickname = nickname
        self.photoData = photoData
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Resolves the catalog entry for this catch.
    var species: Species {
        CreatureCatalog.species(for: speciesID) ?? .mystery
    }
}
