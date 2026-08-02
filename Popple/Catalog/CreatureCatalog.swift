import Foundation

/// The master list of critters you can collect in Popple, plus the logic that
/// turns Vision's raw image labels into a matched critter.
///
/// The `matchKeywords` are tuned for Apple's built-in `VNClassifyImageRequest`,
/// which returns fairly coarse labels ("bird", "dog", "squirrel", ...). As we
/// move toward true species ID (a trained Core ML model or a cloud service),
/// this catalog grows and the keywords get more precise — but nothing else in
/// the app has to change.
enum CreatureCatalog {

    static let all: [Species] = [
        // MARK: Common — the everyday backyard crew
        Species(id: "pigeon", name: "Pidge", emoji: "🐦",
                rarity: .common,
                blurb: "The friendly city local. Always around, always hungry.",
                habitat: "Sidewalks & parks",
                matchKeywords: ["pigeon", "dove"]),
        Species(id: "sparrow", name: "Chippy", emoji: "🐤",
                rarity: .common,
                blurb: "A tiny chirpy ball of feathers with a big personality.",
                habitat: "Hedges & bushes",
                matchKeywords: ["sparrow", "songbird", "finch", "bird"]),
        Species(id: "housecat", name: "Whiskers", emoji: "🐱",
                rarity: .common,
                blurb: "Technically wild if it's sitting on a fence judging you.",
                habitat: "Fences & windowsills",
                matchKeywords: ["cat", "kitten", "feline"]),
        Species(id: "dog", name: "Pupper", emoji: "🐶",
                rarity: .common,
                blurb: "A very good adventuring companion. 10/10.",
                habitat: "Everywhere, thankfully",
                matchKeywords: ["dog", "puppy", "canine", "retriever", "terrier"]),
        Species(id: "squirrel", name: "Nibbles", emoji: "🐿️",
                rarity: .common,
                blurb: "Chaotic. Fluffy. Currently plotting something with an acorn.",
                habitat: "Tree trunks & park benches",
                matchKeywords: ["squirrel", "chipmunk", "rodent"]),

        // MARK: Uncommon — takes a little looking
        Species(id: "duck", name: "Puddles", emoji: "🦆",
                rarity: .uncommon,
                blurb: "Serene on the surface, paddling like mad underneath. Relatable.",
                habitat: "Ponds & lakesides",
                matchKeywords: ["duck", "mallard", "waterfowl", "goose"]),
        Species(id: "rabbit", name: "Clover", emoji: "🐰",
                rarity: .uncommon,
                blurb: "A shy sweetheart. Freezes adorably the moment you look.",
                habitat: "Meadows at dawn & dusk",
                matchKeywords: ["rabbit", "bunny", "hare"]),
        Species(id: "butterfly", name: "Flutter", emoji: "🦋",
                rarity: .uncommon,
                blurb: "A living confetti flake. Impossible to photograph, worth it.",
                habitat: "Flower patches",
                matchKeywords: ["butterfly", "moth"]),
        Species(id: "robin", name: "Berry", emoji: "🐦",
                rarity: .uncommon,
                blurb: "Orange-breasted and cheerful. A sign spring is winning.",
                habitat: "Garden lawns",
                matchKeywords: ["robin", "thrush"]),
        Species(id: "turtle", name: "Shellby", emoji: "🐢",
                rarity: .uncommon,
                blurb: "In no hurry whatsoever. An icon of taking it easy.",
                habitat: "Sunny logs by the water",
                matchKeywords: ["turtle", "tortoise", "terrapin"]),

        // MARK: Rare — a lucky day
        Species(id: "fox", name: "Ember", emoji: "🦊",
                rarity: .rare,
                blurb: "A flash of orange and then gone. Did you even see it?",
                habitat: "Woodland edges at twilight",
                matchKeywords: ["fox"]),
        Species(id: "hedgehog", name: "Prickle", emoji: "🦔",
                rarity: .rare,
                blurb: "A pocket-sized bundle of spikes and snuffles.",
                habitat: "Leaf piles after dark",
                matchKeywords: ["hedgehog", "porcupine"]),
        Species(id: "frog", name: "Sir Hops", emoji: "🐸",
                rarity: .rare,
                blurb: "Green, glossy, and extremely pleased with himself.",
                habitat: "Reedy pond edges",
                matchKeywords: ["frog", "toad"]),
        Species(id: "hummingbird", name: "Zippy", emoji: "🐦",
                rarity: .rare,
                blurb: "A jewel that moves faster than your shutter. Good luck.",
                habitat: "Nectar feeders",
                matchKeywords: ["hummingbird"]),

        // MARK: Epic — you'll be telling people about this
        Species(id: "deer", name: "Willow", emoji: "🦌",
                rarity: .epic,
                blurb: "Gentle, watchful, and gone the instant a twig snaps.",
                habitat: "Deep forest clearings",
                matchKeywords: ["deer", "fawn", "stag", "antelope"]),
        Species(id: "owl", name: "Professor Hoot", emoji: "🦉",
                rarity: .epic,
                blurb: "Wise, silent, and staring directly into your soul.",
                habitat: "Old trees at night",
                matchKeywords: ["owl"]),
        Species(id: "swan", name: "Grace", emoji: "🦢",
                rarity: .epic,
                blurb: "Elegance on water, absolute menace up close.",
                habitat: "Still lakes",
                matchKeywords: ["swan"]),

        // MARK: Legendary — the stuff of stories
        Species(id: "deer-white", name: "Aurora", emoji: "🦌",
                rarity: .legendary,
                blurb: "A pale ghost of the forest. Spotting one is pure luck.",
                habitat: "Misty mountain woods",
                matchKeywords: []),
        Species(id: "eagle", name: "Sovereign", emoji: "🦅",
                rarity: .legendary,
                blurb: "Rides the high winds like it owns the sky. It does.",
                habitat: "Mountain updrafts",
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
