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
enum GroveSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Grove.Catch.self] }
}

/// The current schema — bump this alias when a new version lands.
typealias GroveCurrentSchema = GroveSchemaV2

/// How the store migrates across schema versions; each new version appends a
/// stage here.
enum GroveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GroveSchemaV1.self, GroveSchemaV2.self] }
    static var stages: [MigrationStage] {
        // V1 → V2 only adds optional fields, so the store migrates in place.
        [.lightweight(fromVersion: GroveSchemaV1.self, toVersion: GroveSchemaV2.self)]
    }
}
