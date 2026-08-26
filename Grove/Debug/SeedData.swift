#if DEBUG
import Foundation
import SwiftData

/// Developer-only sample data for the Grove, so you can see populated zones,
/// the Map, streaks, and Achievements without hand-catching everything.
///
/// Seeded catches are recognizable by having **no photo** (a real catch always
/// stores the photo you took), so the toggle can add or remove exactly the
/// sample set without touching anything you caught for real.
enum SeedData {

    /// Whether sample data is currently present.
    static func isPresent(in catches: [Catch]) -> Bool {
        catches.contains { $0.photoData == nil }
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
                photoData: nil, // marks this as seed data
                latitude: baseLat + Double(index % 5) * 0.004 - 0.008,
                longitude: baseLng + Double(index / 5) * 0.004 - 0.006
            )
            context.insert(record)
        }
        try? context.save()
    }

    /// Remove only the seeded (photo-less) catches.
    static func clear(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Catch>()) else { return }
        for record in all where record.photoData == nil {
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
