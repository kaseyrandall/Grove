#if DEBUG
import Foundation
import SwiftData

/// Developer-only sample data for the Grove, so you can see populated zones,
/// the Map, streaks, and Achievements without hand-catching everything.
///
/// Each seeded catch carries a bundled **sample photo** (see `SamplePhotos/`),
/// so a seeded Grove looks exactly like a real player's — real thumbnails, not
/// emoji placeholders — which is what we want for App Store screenshots. Seed
/// records are recognized by that known photo (or by having no photo at all, if
/// the bundled image is somehow missing), so the toggle can add or remove
/// exactly the sample set without touching anything you caught for real.
enum SeedData {

    /// Whether sample data is currently present.
    static func isPresent(in catches: [Catch]) -> Bool {
        catches.contains { isSeed($0) }
    }

    /// A catch is sample data if it has no photo, or its photo is one of our
    /// bundled sample images. A real catch stores a photo the player took, which
    /// never matches either test.
    private static func isSeed(_ record: Catch) -> Bool {
        guard let data = record.photoData else { return true }
        return samplePhotoData.contains(data)
    }

    /// The bundled sample photos, loaded once and keyed for fast membership
    /// tests. Missing files are simply skipped (those species fall back to nil).
    private static let samplePhotoData: Set<Data> = {
        Set(samples.compactMap { photo(for: $0.0) })
    }()

    /// Loads `SamplePhotos/<speciesID>.jpg` from the app bundle, if present.
    private static func photo(for speciesID: String) -> Data? {
        guard let url = Bundle.main.url(forResource: speciesID, withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
    }

    /// (speciesID, daysAgo, optional nickname) — spread across zones, rarities,
    /// and recent days (including a live streak ending today).
    private static let samples: [(String, Int, String?)] = [
        ("bird",      0, nil),
        ("squirrel",  0, "Nibbles"),
        ("pigeon",    1, nil),
        ("duck",      1, "Puddles"),
        ("robin",     2, nil),
        ("rabbit",    2, nil),
        ("butterfly", 3, nil),
        ("fox",       4, "Ember"),
        ("turtle",    5, nil),
        ("deer",      8, "Willow"),
        ("owl",      12, nil),
    ]

    static func fill(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        // A base point (San Francisco) with a little scatter so map pins spread out.
        let baseLat = 37.7749, baseLng = -122.4194

        for (index, sample) in samples.enumerated() {
            guard let species = CreatureCatalog.species(for: sample.0) else { continue }
            let date = calendar.date(byAdding: .day, value: -sample.1, to: now) ?? now
            let record = Catch(
                speciesID: species.id,
                caughtAt: date,
                sparksEarned: Progression.sparks(for: species, isFirstSighting: true),
                isFirstSighting: true,
                nickname: sample.2,
                photoData: photo(for: species.id), // real sample thumbnail (see SamplePhotos/)
                latitude: baseLat + Double(index % 5) * 0.004 - 0.008,
                longitude: baseLng + Double(index / 5) * 0.004 - 0.006
            )
            context.insert(record)
        }
        try? context.save()
    }

    /// Remove only the seeded catches, leaving anything the player caught.
    static func clear(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Catch>()) else { return }
        for record in all where isSeed(record) {
            context.delete(record)
        }
        try? context.save()
    }

    /// Wipe everything — seeded and real — for a clean slate.
    static func eraseAll(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Catch>()) else { return }
        for record in all { context.delete(record) }
        try? context.save()
    }
}
#endif
