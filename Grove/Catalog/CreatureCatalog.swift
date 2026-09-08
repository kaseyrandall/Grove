import Foundation

/// The master field guide of friends you can meet in Grove, plus the logic
/// that turns Vision's raw image labels into a matched friend.
///
/// The `matchKeywords` are tuned for Apple's built-in `VNClassifyImageRequest`,
/// which returns fairly coarse labels ("bird", "dog", "squirrel", ...). As we
/// move toward true species ID (a trained Core ML model or a cloud service),
/// this catalog grows and the keywords get more precise — but nothing else in
/// the app has to change.
enum CreatureCatalog {

    static let all: [Species] = [
        // MARK: The Garden — the everyday backyard crew
        Species(id: "pigeon", name: "Pigeon", emoji: "🐦",
                rarity: .common, zone: .garden,
                blurb: "The friendly city local. Always around, always hungry.",
                habitatNote: "Sidewalks & park benches",
                matchKeywords: ["pigeon", "dove"]),
        // The catch-all for little birds no one can quite name — sparrows,
        // finches, wrens and friends. Pigeon stays its own thing; the showy
        // birds (owl, eagle, peacock…) keep their own slots too.
        Species(id: "bird", name: "Bird", emoji: "🐦",
                rarity: .common, zone: .garden,
                blurb: "A little flit of feathers, too quick to name, and that's half the charm.",
                habitatNote: "Hedges, wires & rooftops",
                matchKeywords: ["sparrow", "finch", "wren", "songbird", "small bird", "bird"]),
        Species(id: "housecat", name: "Cat", emoji: "🐱",
                rarity: .common, zone: .home,
                blurb: "Technically wild if it's sitting on a fence judging you.",
                habitatNote: "Fences & windowsills",
                matchKeywords: ["cat", "kitten", "feline"]),
        Species(id: "dog", name: "Dog", emoji: "🐶",
                rarity: .common, zone: .home,
                blurb: "A very good adventuring companion. 10/10.",
                habitatNote: "Everywhere, thankfully",
                matchKeywords: ["dog", "puppy", "canine", "retriever", "terrier"]),
        Species(id: "squirrel", name: "Squirrel", emoji: "🐿️",
                rarity: .common, zone: .garden,
                blurb: "Chaotic. Fluffy. Currently plotting something with an acorn.",
                habitatNote: "Tree trunks & park benches",
                matchKeywords: ["squirrel", "chipmunk", "rodent"]),
        Species(id: "mouse", name: "Mouse", emoji: "🐭",
                rarity: .common, zone: .garden,
                blurb: "Small, speedy, and gone before you finish saying \"aww\".",
                habitatNote: "Sheds & wood piles",
                matchKeywords: ["mouse"]),
        Species(id: "crow", name: "Crow", emoji: "🐦‍⬛",
                rarity: .common, zone: .garden,
                blurb: "Suspiciously clever. Definitely remembers your face.",
                habitatNote: "Rooftops & wires",
                matchKeywords: ["crow", "raven"]),
        Species(id: "chicken", name: "Chicken", emoji: "🐔",
                rarity: .common, zone: .garden,
                blurb: "Struts like it owns the place. It does.",
                habitatNote: "Coops & farmyards",
                matchKeywords: ["chicken", "hen", "rooster", "poultry"]),
        Species(id: "robin", name: "Robin", emoji: "🐦",
                rarity: .uncommon, zone: .garden,
                blurb: "Orange-breasted and cheerful. A sign spring is winning.",
                habitatNote: "Garden lawns",
                matchKeywords: ["robin", "thrush"]),
        Species(id: "goat", name: "Goat", emoji: "🐐",
                rarity: .uncommon, zone: .garden,
                blurb: "Will eat anything. Yes, that too. Especially that.",
                habitatNote: "Hillsides & farms",
                matchKeywords: ["goat"]),
        Species(id: "pig", name: "Pig", emoji: "🐷",
                rarity: .uncommon, zone: .garden,
                blurb: "Smarter than your dog and twice as stubborn.",
                habitatNote: "Muddy farmyards",
                matchKeywords: ["pig", "hog", "swine"]),

        // MARK: The Pond — freshwater regulars
        Species(id: "fish", name: "Fish", emoji: "🐟",
                rarity: .common, zone: .pond,
                blurb: "Blub. A classic. Never not vibing.",
                habitatNote: "Ponds & streams",
                matchKeywords: ["fish", "goldfish", "carp", "koi", "trout", "salmon", "minnow"]),
        Species(id: "duck", name: "Duck", emoji: "🦆",
                rarity: .uncommon, zone: .pond,
                blurb: "Serene on the surface, paddling like mad underneath. Relatable.",
                habitatNote: "Ponds & lakesides",
                matchKeywords: ["duck", "duckling", "mallard", "waterfowl", "goose", "gosling"]),
        Species(id: "turtle", name: "Turtle", emoji: "🐢",
                rarity: .uncommon, zone: .pond,
                blurb: "In no hurry whatsoever. An icon of taking it easy.",
                habitatNote: "Sunny logs by the water",
                matchKeywords: ["turtle", "tortoise", "terrapin"]),
        Species(id: "frog", name: "Frog", emoji: "🐸",
                rarity: .rare, zone: .pond,
                blurb: "Green, glossy, and extremely pleased with himself.",
                habitatNote: "Reedy pond edges",
                matchKeywords: ["frog", "toad"]),
        Species(id: "otter", name: "Otter", emoji: "🦦",
                rarity: .rare, zone: .pond,
                blurb: "Holds hands while napping. The bar is on the floor, sir.",
                habitatNote: "Riverbanks",
                matchKeywords: ["otter"]),
        Species(id: "beaver", name: "Beaver", emoji: "🦫",
                rarity: .rare, zone: .pond,
                blurb: "Nature's engineer. Never off the clock.",
                habitatNote: "Wooded streams",
                matchKeywords: ["beaver"]),
        Species(id: "swan", name: "Swan", emoji: "🦢",
                rarity: .epic, zone: .pond,
                blurb: "Elegance on water, absolute menace up close.",
                habitatNote: "Still lakes",
                matchKeywords: ["swan"]),

        // MARK: The Coast — where the land meets the sea
        Species(id: "crab", name: "Crab", emoji: "🦀",
                rarity: .uncommon, zone: .coast,
                blurb: "Walks its own way. Respect the pinch.",
                habitatNote: "Rock pools & shorelines",
                matchKeywords: ["crab", "crayfish", "lobster"]),
        Species(id: "seal", name: "Seal", emoji: "🦭",
                rarity: .rare, zone: .coast,
                blurb: "A wet potato with the sweetest eyes. Perfect.",
                habitatNote: "Rocky coasts",
                matchKeywords: ["seal", "sea lion", "walrus"]),
        Species(id: "flamingo", name: "Flamingo", emoji: "🦩",
                rarity: .epic, zone: .coast,
                blurb: "Pink, poised, and standing on one leg out of spite.",
                habitatNote: "Shallow lagoons",
                matchKeywords: ["flamingo"]),
        Species(id: "penguin", name: "Penguin", emoji: "🐧",
                rarity: .epic, zone: .coast,
                blurb: "Dressed for a gala it will never attend.",
                habitatNote: "Cold shores",
                matchKeywords: ["penguin"]),
        Species(id: "dolphin", name: "Dolphin", emoji: "🐬",
                rarity: .epic, zone: .coast,
                blurb: "Smiling, brilliant, and clearly up to something.",
                habitatNote: "Open water",
                matchKeywords: ["dolphin", "porpoise"]),
        Species(id: "octopus", name: "Octopus", emoji: "🐙",
                rarity: .epic, zone: .coast,
                blurb: "Eight arms, three hearts, zero bones, infinite mystery.",
                habitatNote: "Reefs & tide pools",
                matchKeywords: ["octopus", "squid"]),
        Species(id: "whale", name: "Whale", emoji: "🐳",
                rarity: .legendary, zone: .coast,
                blurb: "The gentlest giant in the whole wide ocean. A once-in-a-lifetime hello.",
                habitatNote: "Deep open sea",
                matchKeywords: ["whale", "orca", "humpback", "narwhal"]),

        // MARK: The Meadow — field, farm & tiny things
        Species(id: "bee", name: "Bee", emoji: "🐝",
                rarity: .common, zone: .meadow,
                blurb: "Busy, fuzzy, and single-handedly keeping the world fed.",
                habitatNote: "Flower beds",
                matchKeywords: ["bee", "honeybee", "wasp", "hornet"]),
        Species(id: "ladybug", name: "Ladybug", emoji: "🐞",
                rarity: .common, zone: .meadow,
                blurb: "A tiny lucky charm with legs.",
                habitatNote: "Leaves & stems",
                matchKeywords: ["ladybug", "ladybird", "beetle"]),
        Species(id: "snail", name: "Snail", emoji: "🐌",
                rarity: .common, zone: .meadow,
                blurb: "Carries its whole home on its back. Iconic.",
                habitatNote: "Damp mornings",
                matchKeywords: ["snail", "slug"]),
        Species(id: "ant", name: "Ant", emoji: "🐜",
                rarity: .common, zone: .meadow,
                blurb: "Can lift 50× its weight and still shows up on time.",
                habitatNote: "Cracks in the path",
                matchKeywords: ["ant"]),
        Species(id: "grasshopper", name: "Grasshopper", emoji: "🦗",
                rarity: .common, zone: .meadow,
                blurb: "Boings away the instant you get close. Every time.",
                habitatNote: "Tall grass",
                matchKeywords: ["grasshopper", "cricket", "locust"]),
        Species(id: "butterfly", name: "Butterfly", emoji: "🦋",
                rarity: .uncommon, zone: .meadow,
                blurb: "A living confetti flake. Impossible to photograph, worth it.",
                habitatNote: "Flower patches",
                matchKeywords: ["butterfly", "moth"]),
        Species(id: "rabbit", name: "Rabbit", emoji: "🐰",
                rarity: .uncommon, zone: .meadow,
                blurb: "A shy sweetheart. Freezes adorably the moment you look.",
                habitatNote: "Meadows at dawn & dusk",
                matchKeywords: ["rabbit", "bunny", "hare"]),
        Species(id: "sheep", name: "Sheep", emoji: "🐑",
                rarity: .uncommon, zone: .meadow,
                blurb: "A cloud that says baa. Cozy incarnate.",
                habitatNote: "Rolling pastures",
                matchKeywords: ["sheep", "lamb", "ewe", "ram"]),
        Species(id: "cow", name: "Cow", emoji: "🐄",
                rarity: .uncommon, zone: .meadow,
                blurb: "Gentle, enormous, and very into snacks. Same.",
                habitatNote: "Open pastures",
                matchKeywords: ["cow", "cattle", "calf", "ox"]),
        Species(id: "horse", name: "Horse", emoji: "🐴",
                rarity: .uncommon, zone: .meadow,
                blurb: "All heart, all legs, all drama.",
                habitatNote: "Fields & paddocks",
                matchKeywords: ["horse", "pony", "foal", "mare"]),
        Species(id: "spider", name: "Spider", emoji: "🕷️",
                rarity: .uncommon, zone: .meadow,
                blurb: "Free pest control that you're absolutely terrified of.",
                habitatNote: "Web corners",
                matchKeywords: ["spider", "tarantula", "arachnid"]),

        // MARK: The Woods — a lucky day in the trees
        Species(id: "raccoon", name: "Raccoon", emoji: "🦝",
                rarity: .uncommon, zone: .woods,
                blurb: "A tiny masked bandit with excellent taste in trash.",
                habitatNote: "Bins after dark",
                matchKeywords: ["raccoon"]),
        Species(id: "bat", name: "Bat", emoji: "🦇",
                rarity: .uncommon, zone: .woods,
                blurb: "Spooky little sky puppy. Eats your mosquitoes for free.",
                habitatNote: "Dusk skies & caves",
                matchKeywords: ["bat"]),
        Species(id: "fox", name: "Fox", emoji: "🦊",
                rarity: .rare, zone: .woods,
                blurb: "A flash of orange and then gone. Did you even see it?",
                habitatNote: "Woodland edges at twilight",
                matchKeywords: ["fox"]),
        Species(id: "hedgehog", name: "Hedgehog", emoji: "🦔",
                rarity: .rare, zone: .woods,
                blurb: "A pocket-sized bundle of spikes and snuffles.",
                habitatNote: "Leaf piles after dark",
                matchKeywords: ["hedgehog", "porcupine"]),
        Species(id: "boar", name: "Boar", emoji: "🐗",
                rarity: .rare, zone: .woods,
                blurb: "Built like a tank, tempered like a toddler.",
                habitatNote: "Deep undergrowth",
                matchKeywords: ["boar", "warthog"]),
        Species(id: "badger", name: "Badger", emoji: "🦡",
                rarity: .rare, zone: .woods,
                blurb: "Grumpy, stripey, and minding its own business. Do the same.",
                habitatNote: "Setts in the bank",
                matchKeywords: ["badger"]),
        Species(id: "deer", name: "Deer", emoji: "🦌",
                rarity: .epic, zone: .woods,
                blurb: "Gentle, watchful, and gone the instant a twig snaps.",
                habitatNote: "Deep forest clearings",
                matchKeywords: ["deer", "fawn", "stag", "antelope", "elk", "moose"]),
        Species(id: "owl", name: "Owl", emoji: "🦉",
                rarity: .epic, zone: .woods,
                blurb: "Wise, silent, and staring directly into your soul.",
                habitatNote: "Old trees at night",
                matchKeywords: ["owl"]),
        Species(id: "bear", name: "Bear", emoji: "🐻",
                rarity: .epic, zone: .woods,
                blurb: "A mountain of fluff you should absolutely not hug.",
                habitatNote: "Forests & rivers",
                matchKeywords: ["bear", "cub"]),
        Species(id: "wolf", name: "Wolf", emoji: "🐺",
                rarity: .epic, zone: .woods,
                blurb: "A dog's cooler, scarier ancestor. Runs with family.",
                habitatNote: "Remote wilderness",
                matchKeywords: ["wolf", "coyote"]),

        // MARK: The Treetops — up where the sky lives
        Species(id: "hummingbird", name: "Hummingbird", emoji: "🐦",
                rarity: .rare, zone: .sky,
                blurb: "A jewel that moves faster than your shutter. Good luck.",
                habitatNote: "Nectar feeders",
                matchKeywords: ["hummingbird"]),
        Species(id: "parrot", name: "Parrot", emoji: "🦜",
                rarity: .rare, zone: .sky,
                blurb: "Dressed in every color and happy to tell you about it.",
                habitatNote: "Tropical canopies",
                matchKeywords: ["parrot", "macaw", "cockatoo", "parakeet"]),
        Species(id: "peacock", name: "Peacock", emoji: "🦚",
                rarity: .epic, zone: .sky,
                blurb: "The most extra bird alive, and it knows it.",
                habitatNote: "Gardens & estates",
                matchKeywords: ["peacock", "peafowl"]),
        Species(id: "eagle", name: "Eagle", emoji: "🦅",
                rarity: .legendary, zone: .sky,
                blurb: "Rides the high winds like it owns the sky. It does.",
                habitatNote: "Mountain updrafts",
                matchKeywords: ["eagle", "hawk", "falcon", "raptor", "osprey"]),

        // MARK: The Wilds — the far-flung and legendary
        Species(id: "lizard", name: "Lizard", emoji: "🦎",
                rarity: .uncommon, zone: .wilds,
                blurb: "Sun-warmed and utterly unbothered.",
                habitatNote: "Warm rocks",
                matchKeywords: ["lizard", "gecko", "iguana", "chameleon"]),
        Species(id: "monkey", name: "Monkey", emoji: "🐒",
                rarity: .rare, zone: .wilds,
                blurb: "Chaos with opposable thumbs. Hide your snacks.",
                habitatNote: "Jungle canopies",
                matchKeywords: ["monkey", "macaque", "baboon"]),
        Species(id: "sloth", name: "Sloth", emoji: "🦥",
                rarity: .rare, zone: .wilds,
                blurb: "Living life at exactly one speed: no.",
                habitatNote: "Rainforest branches",
                matchKeywords: ["sloth"]),
        Species(id: "camel", name: "Camel", emoji: "🐫",
                rarity: .rare, zone: .wilds,
                blurb: "Crosses deserts on vibes and a full tank.",
                habitatNote: "Sandy dunes",
                matchKeywords: ["camel", "dromedary"]),
        Species(id: "zebra", name: "Zebra", emoji: "🦓",
                rarity: .rare, zone: .wilds,
                blurb: "A horse that committed to a look. Iconic.",
                habitatNote: "Open savanna",
                matchKeywords: ["zebra"]),
        Species(id: "snake", name: "Snake", emoji: "🐍",
                rarity: .rare, zone: .wilds,
                blurb: "All noodle, no legs, big drama. A python if you're lucky.",
                habitatNote: "Warm undergrowth",
                matchKeywords: ["snake", "python", "serpent", "cobra", "viper", "boa"]),
        Species(id: "tiger", name: "Tiger", emoji: "🐅",
                rarity: .epic, zone: .wilds,
                blurb: "The biggest cat there is, and every bit as majestic.",
                habitatNote: "Dense jungle",
                matchKeywords: ["tiger"]),
        Species(id: "lion", name: "Lion", emoji: "🦁",
                rarity: .epic, zone: .wilds,
                blurb: "Naps 20 hours a day and still runs the whole savanna.",
                habitatNote: "Grassy plains",
                matchKeywords: ["lion"]),
        Species(id: "elephant", name: "Elephant", emoji: "🐘",
                rarity: .epic, zone: .wilds,
                blurb: "Gentle, enormous, and never, ever forgets you.",
                habitatNote: "Savanna & rivers",
                matchKeywords: ["elephant"]),
        Species(id: "giraffe", name: "Giraffe", emoji: "🦒",
                rarity: .epic, zone: .wilds,
                blurb: "Head in the clouds, heart of gold.",
                habitatNote: "Acacia woodlands",
                matchKeywords: ["giraffe"]),
        Species(id: "crocodile", name: "Crocodile", emoji: "🐊",
                rarity: .epic, zone: .wilds,
                blurb: "A log with teeth and zero patience. Give it space.",
                habitatNote: "Muddy riverbanks",
                matchKeywords: ["crocodile", "alligator", "gator"]),
        Species(id: "rhino", name: "Rhino", emoji: "🦏",
                rarity: .epic, zone: .wilds,
                blurb: "Armored, ancient, and gloriously grumpy.",
                habitatNote: "Grassland & scrub",
                matchKeywords: ["rhino", "rhinoceros"]),
        Species(id: "hippo", name: "Hippo", emoji: "🦛",
                rarity: .epic, zone: .wilds,
                blurb: "Looks cuddly, is chaos. Surprisingly fast. Beware.",
                habitatNote: "Wide rivers",
                matchKeywords: ["hippo", "hippopotamus"]),
        Species(id: "gorilla", name: "Gorilla", emoji: "🦍",
                rarity: .epic, zone: .wilds,
                blurb: "Gentle giant, thoughtful eyes, incredible strength.",
                habitatNote: "Mountain forests",
                matchKeywords: ["gorilla", "ape", "orangutan", "chimpanzee"]),
        Species(id: "kangaroo", name: "Kangaroo", emoji: "🦘",
                rarity: .epic, zone: .wilds,
                blurb: "Boings across a continent with a pocket full of baby.",
                habitatNote: "Outback plains",
                matchKeywords: ["kangaroo", "wallaby"]),
        Species(id: "koala", name: "Koala", emoji: "🐨",
                rarity: .epic, zone: .wilds,
                blurb: "Sleeps 22 hours a day hugging a tree. The dream.",
                habitatNote: "Eucalyptus trees",
                matchKeywords: ["koala"]),
        Species(id: "panda", name: "Panda", emoji: "🐼",
                rarity: .legendary, zone: .wilds,
                blurb: "Rare, round, and impossibly precious. A true treasure.",
                habitatNote: "Bamboo forests",
                matchKeywords: ["panda"]),
        Species(id: "leopard", name: "Leopard", emoji: "🐆",
                rarity: .legendary, zone: .wilds,
                blurb: "A shadow with spots. If you saw it, it let you.",
                habitatNote: "Rocky hills at night",
                matchKeywords: ["leopard", "cheetah", "jaguar", "panther"]),
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

    /// The whole guide sorted by name — the browse order for pickers.
    static let alphabetical: [Species] = all.sorted { $0.name < $1.name }

    /// Whether a `matchKeywords` entry appears in Vision's labels on a *word
    /// boundary*. Vision labels are lowercased single tokens or short phrases
    /// ("small bird", "sea lion"), so a plain substring test is dangerous: the
    /// keyword "ant" hides inside "plant" (in nearly every outdoor photo) and
    /// "ape" inside "landscape", which used to summon a confident Ant or
    /// Gorilla from the background. Matching whole words kills those false hits.
    /// Multi-word keywords stay a bounded substring test — distinctive enough.
    private static func keyword(_ keyword: String, matches labels: [String]) -> Bool {
        if keyword.contains(" ") {
            return labels.contains { $0.contains(keyword) }
        }
        let target = Substring(keyword)
        return labels.contains { label in
            label.split(whereSeparator: { !$0.isLetter }).contains(target)
        }
    }

    /// Vision's coarse animal-family words. Used only to answer "did the photo
    /// contain *an* animal, even one not in our guide?" — so we can gently turn
    /// away a picture of lunch instead of minting a Mystery Friend for it.
    private static let animalIndicators: [String] = [
        "animal", "wildlife", "pet", "mammal", "bird", "fish", "insect",
        "reptile", "amphibian", "arachnid", "invertebrate", "crustacean",
        "mollusk", "rodent", "primate", "feline", "canine", "marsupial",
        "carnivore", "herbivore", "ungulate", "waterfowl", "songbird",
        "seabird", "raptor", "livestock", "cattle", "poultry",
    ]

    /// Whether Vision's labels suggest the photo actually holds an animal.
    /// `nil` means "can't tell" — no labels came back (the Simulator returns
    /// none, and a failed request is empty too), so callers must not reject on
    /// `nil`. A catalog keyword hit is a definite yes; otherwise we look for
    /// Vision's broad family words. Lets the Catch flow decline a clearly
    /// non-animal photo rather than inventing a friend for it.
    static func looksLikeAnimal(labels: [String]) -> Bool? {
        guard !labels.isEmpty else { return nil }
        if !keywordMatches(labels: labels, limit: 1).isEmpty { return true }
        return animalIndicators.contains { keyword($0, matches: labels) }
    }

    /// Exact-keyword shortlist: every species whose `matchKeywords` overlap the
    /// labels, ranked by number of hits then rarity. This is the same signal
    /// `match` uses, so it only fires when Vision named something we know.
    static func keywordMatches(labels: [String], limit: Int = 6) -> [Species] {
        guard !labels.isEmpty else { return [] }
        let scored: [(species: Species, hits: Int)] = all.compactMap { species in
            let hits = species.matchKeywords.reduce(0) { count, kw in
                count + (keyword(kw, matches: labels) ? 1 : 0)
            }
            return hits > 0 ? (species, hits) : nil
        }
        return scored
            .sorted { $0.hits != $1.hits ? $0.hits > $1.hits : $0.species.rarity > $1.species.rarity }
            .prefix(limit)
            .map(\.species)
    }

    /// Best-guess shortlist for the identify UI. Starts from exact keyword
    /// matches, then — crucially for a Mystery Friend, which exists *because*
    /// exact matching failed — falls back to Vision's coarse group labels
    /// ("bird", "rodent", "insect"…) mapped to likely catalog residents. The
    /// map below is curated and meant to be tuned against real Vision output.
    static func smartSuggestions(labels: [String], limit: Int = 6) -> [Species] {
        guard !labels.isEmpty else { return [] }
        var picks = keywordMatches(labels: labels, limit: limit)
        guard picks.count < limit else { return Array(picks.prefix(limit)) }

        var seen = Set(picks.map(\.id))
        for label in labels {
            for group in categoryGroups where group.tokens.contains(where: { label.contains($0) }) {
                for id in group.ids where !seen.contains(id) {
                    if let species = byID[id] {
                        picks.append(species)
                        seen.insert(id)
                    }
                    if picks.count >= limit { return Array(picks.prefix(limit)) }
                }
            }
        }
        return Array(picks.prefix(limit))
    }

    /// Coarse Vision groups → a handful of likely catalog friends. Ordered
    /// specific → generic so a precise label ("duck") wins over a broad one
    /// ("bird") before the catch-all ("animal") ever applies. Matching is a
    /// substring test against each Vision label, so keep tokens distinctive.
    private static let categoryGroups: [(tokens: [String], ids: [String])] = [
        (["duck", "mallard", "waterfowl", "goose"],           ["duck", "swan"]),
        (["seabird", "gull", "pelican", "albatross"],         ["swan", "duck"]),
        (["songbird", "finch", "sparrow", "robin", "wren"],   ["bird", "robin"]),
        (["raptor", "hawk", "eagle", "falcon", "owl"],        ["eagle", "owl"]),
        (["parrot", "macaw", "cockatoo"],                     ["parrot"]),
        (["bird", "fowl", "poultry"],                         ["bird", "pigeon", "crow", "robin", "duck", "chicken"]),
        (["kitten", "feline"],                                ["housecat"]),
        (["puppy", "canine", "retriever", "terrier"],         ["dog"]),
        (["squirrel", "chipmunk", "rodent", "mouse"],         ["squirrel", "mouse"]),
        (["rabbit", "hare", "bunny"],                         ["rabbit"]),
        (["deer", "fawn", "elk", "moose"],                    ["deer"]),
        (["butterfly", "moth"],                               ["butterfly"]),
        (["bee", "wasp", "hornet"],                           ["bee"]),
        (["beetle", "ladybug", "ladybird"],                   ["ladybug"]),
        (["insect", "cricket", "grasshopper"],                ["bee", "butterfly", "ladybug", "ant", "grasshopper"]),
        (["spider", "arachnid", "tarantula"],                 ["spider"]),
        (["snake", "serpent", "python", "cobra"],             ["snake"]),
        (["lizard", "gecko", "iguana", "reptile"],            ["lizard"]),
        (["turtle", "tortoise"],                              ["turtle"]),
        (["frog", "toad", "amphibian"],                       ["frog"]),
        (["goldfish", "carp"],                                ["fish"]),
        (["whale", "orca", "humpback", "narwhal"],            ["whale", "dolphin"]),
        (["dolphin", "porpoise"],                             ["dolphin", "whale"]),
        (["crab", "lobster", "crayfish"],                     ["crab"]),
        (["mammal", "wildlife", "animal"],                    ["squirrel", "rabbit", "fox", "dog", "housecat", "deer"]),
    ]

    /// Given Vision's top labels (already lowercased), pick the best friend.
    /// Uses the same word-boundary scoring as the shortlist: most keyword hits
    /// win, ties broken toward the rarer species so a lucky "fox" beats a
    /// background "dog". When nothing genuinely matches — an out-of-catalog
    /// animal, or a photo of no animal at all — we return the Mystery Friend
    /// rather than a confident wrong guess.
    static func match(labels: [String]) -> Species {
        keywordMatches(labels: labels, limit: 1).first ?? .mystery
    }
}
