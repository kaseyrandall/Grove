import Foundation

/// How each kind of friend fights, picked to suit the animal: sharks and
/// eagles strike, bears and moose bruise, turtles and hedgehogs wall,
/// foxes, crows and the opossum (who plays dead) trick, mice and
/// hummingbirds skirmish. A kind missing from here (a new addition) falls
/// back to a stable pick from its id, so nothing breaks, but new friends
/// should be added here when they join the catalog.
enum SpeciesPlaystyles {
    static let byID: [String: Archetype] = [
        // Garden & Home
        "pigeon": .skirmisher, "bird": .skirmisher, "housecat": .striker, "dog": .bruiser,
        "squirrel": .skirmisher, "mouse": .skirmisher, "crow": .trickster, "robin": .skirmisher,
        "peacock": .trickster, "hamster": .skirmisher, "fly": .skirmisher, "dove": .allrounder,
        "worm": .wall, "beetle": .wall, "skunk": .trickster, "opossum": .trickster,
        "chipmunk": .skirmisher, "woodlouse": .wall,
        // Pond
        "fish": .skirmisher, "duck": .allrounder, "turtle": .wall, "frog": .skirmisher,
        "otter": .allrounder, "beaver": .wall, "swan": .bruiser, "goose": .bruiser,
        "mosquito": .skirmisher, "toad": .wall, "newt": .trickster, "heron": .striker,
        // Coast
        "crab": .wall, "seal": .wall, "flamingo": .allrounder, "penguin": .allrounder,
        "dolphin": .striker, "octopus": .trickster, "whale": .wall, "shrimp": .skirmisher,
        "lobster": .bruiser, "jellyfish": .trickster, "squid": .trickster, "shark": .striker,
        // Meadow
        "bee": .striker, "ladybug": .wall, "snail": .wall, "ant": .skirmisher,
        "grasshopper": .skirmisher, "butterfly": .trickster, "rabbit": .skirmisher,
        "sheep": .wall, "cow": .wall, "horse": .allrounder, "spider": .trickster,
        "chicken": .allrounder, "goat": .bruiser, "pig": .wall, "turkey": .allrounder,
        "donkey": .allrounder, "llama": .trickster, "moth": .trickster,
        // Woods
        "raccoon": .trickster, "bat": .skirmisher, "fox": .trickster, "hedgehog": .wall,
        "boar": .bruiser, "badger": .bruiser, "deer": .allrounder, "owl": .striker,
        "bear": .bruiser, "wolf": .striker, "moose": .bruiser, "salamander": .trickster,
        // Treetops
        "hummingbird": .skirmisher, "parrot": .trickster, "eagle": .striker, "woodpecker": .striker,
        // Wilds
        "lizard": .skirmisher, "monkey": .trickster, "sloth": .wall, "camel": .allrounder,
        "zebra": .allrounder, "snake": .striker, "tiger": .striker, "lion": .bruiser,
        "elephant": .wall, "giraffe": .allrounder, "crocodile": .bruiser, "rhino": .bruiser,
        "hippo": .bruiser, "gorilla": .bruiser, "kangaroo": .bruiser, "koala": .wall,
        "panda": .allrounder, "leopard": .striker, "scorpion": .striker, "bison": .bruiser,
        "polarbear": .bruiser,
        // Not yet identified: steady all-round, until you say who it is.
        "mystery-critter": .allrounder,
    ]
}
