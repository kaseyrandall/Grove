import Foundation

/// The master field guide of critters you can meet in Popple, plus the logic
/// that turns Vision's raw image labels into a matched critter.
///
/// The `matchKeywords` are tuned for Apple's built-in `VNClassifyImageRequest`,
/// which returns fairly coarse labels ("bird", "dog", "squirrel", ...). As we
/// move toward true species ID (a trained Core ML model or a cloud service),
/// this catalog grows and the keywords get more precise — but nothing else in
/// the app has to change.
enum CreatureCatalog {

    static let all: [Species] = [
        // MARK: The Garden — the everyday backyard crew
        Species(id: "pigeon", name: "Rock Pigeon", emoji: "🐦",
                rarity: .common, zone: .garden,
                blurb: "The friendly city local. Always around, always hungry.",
                habitatNote: "Sidewalks & park benches",
                matchKeywords: ["pigeon", "dove"]),
        Species(id: "sparrow", name: "House Sparrow", emoji: "🐤",
                rarity: .common, zone: .garden,
                blurb: "A tiny chirpy ball of feathers with a big personality.",
                habitatNote: "Hedges & bushes",
                matchKeywords: ["sparrow", "songbird", "finch", "bird"]),
        Species(id: "housecat", name: "House Cat", emoji: "🐱",
                rarity: .common, zone: .garden,
                blurb: "Technically wild if it's sitting on a fence judging you.",
                habitatNote: "Fences & windowsills",
                matchKeywords: ["cat", "kitten", "feline"]),
        Species(id: "dog", name: "Dog", emoji: "🐶",
                rarity: .common, zone: .garden,
                blurb: "A very good adventuring companion. 10/10.",
                habitatNote: "Everywhere, thankfully",
                matchKeywords: ["dog", "puppy", "canine", "retriever", "terrier"]),
        Species(id: "squirrel", name: "Grey Squirrel", emoji: "🐿️",
                rarity: .common, zone: .garden,
                blurb: "Chaotic. Fluffy. Currently plotting something with an acorn.",
                habitatNote: "Tree trunks & park benches",
                matchKeywords: ["squirrel", "chipmunk", "rodent"]),
        Species(id: "robin", name: "American Robin", emoji: "🐦",
                rarity: .uncommon, zone: .garden,
                blurb: "Orange-breasted and cheerful. A sign spring is winning.",
                habitatNote: "Garden lawns",
                matchKeywords: ["robin", "thrush"]),

        // MARK: The Pond — waterside regulars
        Species(id: "duck", name: "Mallard Duck", emoji: "🦆",
                rarity: .uncommon, zone: .pond,
                blurb: "Serene on the surface, paddling like mad underneath. Relatable.",
                habitatNote: "Ponds & lakesides",
                matchKeywords: ["duck", "mallard", "waterfowl", "goose"]),
        Species(id: "turtle", name: "Pond Turtle", emoji: "🐢",
                rarity: .uncommon, zone: .pond,
                blurb: "In no hurry whatsoever. An icon of taking it easy.",
                habitatNote: "Sunny logs by the water",
                matchKeywords: ["turtle", "tortoise", "terrapin"]),
        Species(id: "frog", name: "Green Frog", emoji: "🐸",
                rarity: .rare, zone: .pond,
                blurb: "Green, glossy, and extremely pleased with himself.",
                habitatNote: "Reedy pond edges",
                matchKeywords: ["frog", "toad"]),
        Species(id: "swan", name: "Swan", emoji: "🦢",
                rarity: .epic, zone: .pond,
                blurb: "Elegance on water, absolute menace up close.",
                habitatNote: "Still lakes",
                matchKeywords: ["swan"]),

        // MARK: The Meadow — open-field sweethearts
        Species(id: "rabbit", name: "Cottontail Rabbit", emoji: "🐰",
                rarity: .uncommon, zone: .meadow,
                blurb: "A shy sweetheart. Freezes adorably the moment you look.",
                habitatNote: "Meadows at dawn & dusk",
                matchKeywords: ["rabbit", "bunny", "hare"]),
        Species(id: "butterfly", name: "Butterfly", emoji: "🦋",
                rarity: .uncommon, zone: .meadow,
                blurb: "A living confetti flake. Impossible to photograph, worth it.",
                habitatNote: "Flower patches",
                matchKeywords: ["butterfly", "moth"]),

        // MARK: The Woods — a lucky day
        Species(id: "fox", name: "Red Fox", emoji: "🦊",
                rarity: .rare, zone: .woods,
                blurb: "A flash of orange and then gone. Did you even see it?",
                habitatNote: "Woodland edges at twilight",
                matchKeywords: ["fox"]),
        Species(id: "hedgehog", name: "Hedgehog", emoji: "🦔",
                rarity: .rare, zone: .woods,
                blurb: "A pocket-sized bundle of spikes and snuffles.",
                habitatNote: "Leaf piles after dark",
                matchKeywords: ["hedgehog", "porcupine"]),
        Species(id: "deer", name: "Deer", emoji: "🦌",
                rarity: .epic, zone: .woods,
                blurb: "Gentle, watchful, and gone the instant a twig snaps.",
                habitatNote: "Deep forest clearings",
                matchKeywords: ["deer", "fawn", "stag", "antelope"]),
        Species(id: "owl", name: "Owl", emoji: "🦉",
                rarity: .epic, zone: .woods,
                blurb: "Wise, silent, and staring directly into your soul.",
                habitatNote: "Old trees at night",
                matchKeywords: ["owl"]),
        Species(id: "deer-white", name: "White Deer", emoji: "🦌",
                rarity: .legendary, zone: .woods,
                blurb: "A pale ghost of the forest. Spotting one is pure luck.",
                habitatNote: "Misty mountain woods",
                matchKeywords: []),

        // MARK: The Treetops — up where the sky lives
        Species(id: "hummingbird", name: "Hummingbird", emoji: "🐦",
                rarity: .rare, zone: .sky,
                blurb: "A jewel that moves faster than your shutter. Good luck.",
                habitatNote: "Nectar feeders",
                matchKeywords: ["hummingbird"]),
        Species(id: "eagle", name: "Eagle", emoji: "🦅",
                rarity: .legendary, zone: .sky,
                blurb: "Rides the high winds like it owns the sky. It does.",
                habitatNote: "Mountain updrafts",
                matchKeywords: ["eagle", "hawk", "falcon", "raptor"]),
    ]

    /// Fast lookup by id.
    private static let byID: [String: Species] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func species(for id: String) -> Species? {
        if id == Species.mystery.id { return .mystery }
        return byID[id]
    }

    /// Species that belong to a given zone, in catalog order.
    static func species(in zone: Habitat) -> [Species] {
        all.filter { $0.zone == zone }
    }

    /// Given Vision's top labels (already lowercased), pick the best critter.
    /// Prefers rarer matches so a lucky "fox" beats a background "dog".
    /// Falls back to the Mystery Critter so every snap yields something.
    static func match(labels: [String]) -> Species {
        var best: Species?
        for species in all {
            let hit = species.matchKeywords.contains { keyword in
                labels.contains { $0.contains(keyword) }
            }
            if hit {
                if let current = best {
                    if species.rarity > current.rarity { best = species }
                } else {
                    best = species
                }
            }
        }
        return best ?? .mystery
    }
}
