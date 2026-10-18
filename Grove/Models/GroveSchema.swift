import Foundation
import SwiftData

/// Versioned schema for the on-device store. Wrapping the models in an explicit
/// version (rather than handing `ModelContainer` a bare type list) is what lets
/// us evolve `Catch` without wiping anyone's Grove: each change adds a new
/// schema version and a `MigrationStage` describing how to get there.

/// Version 1.0 of the app. `Catch` here is a frozen copy of the model as it
/// shipped, so stores written by 1.0 are still recognised — never edit it.
enum GroveSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Catch.self] }

    @Model
    final class Catch {
        var speciesID: String
        var caughtAt: Date
        var sparksEarned: Int
        var isFirstSighting: Bool
        var nickname: String?
        var zoneOverrideRaw: String?
        @Attribute(.externalStorage) var photoData: Data?
        var latitude: Double?
        var longitude: Double?
        var placeName: String?

        init(speciesID: String, caughtAt: Date, sparksEarned: Int, isFirstSighting: Bool) {
            self.speciesID = speciesID
            self.caughtAt = caughtAt
            self.sparksEarned = sparksEarned
            self.isFirstSighting = isFirstSighting
        }
    }
}

/// Version 1.1: `Catch` gains the photo crop (`cropCenterX/Y`, `cropZoom`).
/// A frozen copy of the model as it shipped in 1.1 and 1.2 — never edit it.
enum GroveSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Catch.self] }

    @Model
    final class Catch {
        var speciesID: String = ""
        var caughtAt: Date = Date.now
        var sparksEarned: Int = 0
        var isFirstSighting: Bool = false
        var nickname: String?
        var zoneOverrideRaw: String?
        @Attribute(.externalStorage) var photoData: Data?
        var latitude: Double?
        var longitude: Double?
        var placeName: String?
        var cropCenterX: Double?
        var cropCenterY: Double?
        var cropZoom: Double?

        init(speciesID: String, caughtAt: Date, sparksEarned: Int, isFirstSighting: Bool) {
            self.speciesID = speciesID
            self.caughtAt = caughtAt
            self.sparksEarned = sparksEarned
            self.isFirstSighting = isFirstSighting
        }
    }
}

/// Version 1.3: `Catch` gains `favoritedAt` (pinned to the Profile).
/// A frozen copy of the model as it shipped in 1.3 and 1.4 — never edit it.
enum GroveSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] { [Catch.self] }

    @Model
    final class Catch {
        var speciesID: String = ""
        var caughtAt: Date = Date.now
        var sparksEarned: Int = 0
        var isFirstSighting: Bool = false
        var nickname: String?
        var zoneOverrideRaw: String?
        @Attribute(.externalStorage) var photoData: Data?
        var latitude: Double?
        var longitude: Double?
        var placeName: String?
        var cropCenterX: Double?
        var cropCenterY: Double?
        var cropZoom: Double?
        var favoritedAt: Date?

        init(speciesID: String, caughtAt: Date, sparksEarned: Int, isFirstSighting: Bool) {
            self.speciesID = speciesID
            self.caughtAt = caughtAt
            self.sparksEarned = sparksEarned
            self.isFirstSighting = isFirstSighting
        }
    }
}

/// Battlegrounds: `Catch` gains `battleID` (a stable id for team and history)
/// and `battleData` (the friend's battle progress, so it syncs with them).
enum GroveSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] { [Grove.Catch.self] }
}

/// The current schema — bump this alias when a new version lands.
typealias GroveCurrentSchema = GroveSchemaV4

/// How the store migrates across schema versions; each new version appends a
/// stage here.
enum GroveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GroveSchemaV1.self, GroveSchemaV2.self, GroveSchemaV3.self, GroveSchemaV4.self]
    }
    static var stages: [MigrationStage] {
        // Each step only adds optional fields, so the store migrates in place.
        [.lightweight(fromVersion: GroveSchemaV1.self, toVersion: GroveSchemaV2.self),
         .lightweight(fromVersion: GroveSchemaV2.self, toVersion: GroveSchemaV3.self),
         .lightweight(fromVersion: GroveSchemaV3.self, toVersion: GroveSchemaV4.self)]
    }
}
