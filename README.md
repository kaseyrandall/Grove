# 🌿 Popple

A super-cute, playful iOS game: **snap photos of the animals you find in the wild, collect them in your Dex, and earn sparks.** Think of it as a friendly, real-world Pokédex for critters.

Built 100% native — SwiftUI, SwiftData, and Apple's on-device Vision framework. No backend, no accounts, no cost. Your whole collection lives on your phone.

---

## ✨ The core loop

> **Spot a critter → Snap → "New critter! Clover the Rabbit — +50 sparks, first find!" → check your Dex → go find more.**

- **Live camera only.** Catches must be taken *in the moment* — there's no photo-library upload, so you can't collect screenshots or downloaded images. (A library picker exists in **DEBUG builds only** for Simulator testing; it's compiled out of release builds.)
- **On-device identification.** Photos are classified locally with Apple's Vision framework — instant, private, offline, free.
- **Always rewarding.** If Vision can't confidently name what it saw, you still catch a **Mystery Critter**, so a snap never feels wasted.
- **First-find bonus.** The first time you catch a species, sparks are doubled — the collection thrill.
- **Rarity tiers.** Common 🌿 → Uncommon 🍀 → Rare 💎 → Epic 🌟 → Legendary 👑, each worth more.
- **Daily streaks.** 🔥 Catch something each day to keep your streak alive (current + all-time best).
- **Achievements.** 🎖 16 badges with live progress bars, celebrated the instant you unlock them mid-catch.
- **Discovery map.** 🗺️ Every geotagged catch drops a rarity-colored pin where you found it.

## 📱 Screens

| Tab | What it does |
|-----|--------------|
| **Dex** | A grid of every critter. Caught ones fill in with your photo; the rest stay as `???` silhouettes — the set you want to complete. |
| **Map** | A MapKit map with a rarity-colored pin at every place you've made a catch. Tap a pin to open that critter. |
| **Catch** | Live camera + shutter — strictly capture-in-the-moment (a DEBUG-only library picker exists for Simulator testing). |
| **Journal** | Your streak, level, total sparks, species count, an achievements summary, and collection-by-rarity (with your rarest catch). |
| **Achievements** | (from **Journal**) A grid of 16 badges — unlocked ones in full color, locked ones dimmed with a live progress bar. |

## 🚀 Running it

1. Open `Popple.xcodeproj` in **Xcode 16 or newer**.
2. Select an iOS 17+ simulator or your own device, and hit **Run** (⌘R).
3. **Simulator:** there's no camera, so use the **DEBUG: Pick from Library** button on the Catch tab (DEBUG builds only). Drag any animal photo into the simulator first.
4. **Real device:** point the camera at an animal (or a pet!) and tap **Snap!**. You'll need to trust your developer certificate the first time.

> Requires iOS 17.0+ (SwiftData). Signing is set to **Automatic** — just pick your team in *Signing & Capabilities* to run on a device.

## 🧠 How identification works today

The MVP uses Apple's built-in `VNClassifyImageRequest`, which returns fairly **coarse** labels ("bird", "dog", "squirrel"...). The catalog in `CreatureCatalog.swift` maps those labels to cute named critters, preferring rarer matches. This is deliberately simple and 100% free — it's the fun-first foundation.

**The upgrade path is clean:** swap the guts of `AnimalClassifier.classify` for a trained Core ML species model or a cloud vision service, expand the catalog's `matchKeywords`, and nothing else in the app has to change.

## 🗂 Project structure

```
Popple/
├── PoppleApp.swift            # App entry + SwiftData container
├── Models/
│   ├── Rarity.swift           # Rarity tiers, points, colors
│   ├── Species.swift          # A collectible critter *type* (catalog data)
│   └── Catch.swift            # A photo you took (the only persisted model)
├── Catalog/
│   └── CreatureCatalog.swift  # The seed critters + label→critter matching
├── Game/
│   ├── Progression.swift      # Pure scoring & leveling math
│   ├── StreakEngine.swift     # Consecutive-day streak math
│   ├── PlayerStats.swift      # One derived snapshot of all player numbers
│   └── Achievement.swift      # Badge catalog + unlock evaluation
├── Services/
│   ├── AnimalClassifier.swift # Vision on-device classification
│   ├── CameraModel.swift      # AVFoundation capture
│   ├── CameraPreview.swift    # SwiftUI camera preview layer
│   └── LocationProvider.swift # Optional geotagging of catches
├── DesignSystem/
│   ├── Theme.swift            # Pastel palette, soft cards
│   └── Components.swift       # Buttons, badges, chips
└── Views/
    ├── RootView.swift         # Tab bar
    ├── Catch/                 # Camera + celebration (with achievement unlocks)
    ├── Dex/                   # Collection grid + detail
    ├── Map/                   # Discovery map of sightings
    ├── Achievements/          # Badge grid with progress
    └── Profile/               # "Journal" tab — streak, level, achievements & rarity stats
```

## 🛣 Roadmap (post-MVP)

- **Better ID** — Core ML species model or cloud vision for true species names.
- **Social** (planned) — friends, shared sightings, leaderboards. The data model is already structured so a sync/backend layer can bolt on without a rewrite.
- **Daily goals** — a rotating "catch a bird today" style quest on top of the streak system.
- **Real critter art** — replace the placeholder emoji with commissioned illustrations.
- **Anti-cheat** — camera-only capture already blocks library uploads. Next up (once leaderboards exist): liveness checks so you can't photograph a screen or printout.

---

*Snap. Collect. Adventure.* 🐾
