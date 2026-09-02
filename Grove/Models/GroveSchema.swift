import SwiftData

/// Versioned schema for the on-device store. Wrapping the models in an explicit
/// version (rather than handing `ModelContainer` a bare type list) is what lets
/// us evolve `Catch` later without wiping anyone's Grove: a future change adds a
/// `GroveSchemaV2`, and a `MigrationStage` describing how V1 → V2 goes.
enum GroveSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Catch.self] }
}

/// The current schema — bump this alias when a new version lands.
typealias GroveCurrentSchema = GroveSchemaV1

/// How the store migrates across schema versions. Empty for now (only V1
/// exists); each future version appends a stage here.
enum GroveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GroveSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
