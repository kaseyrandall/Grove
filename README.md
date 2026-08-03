# 🌿 Grove

> *Grow a place full of the life you've met.*

A super-cute, playful iOS game: **photograph the animals you find in the wild, and they come home to your Grove** — a cozy little world that fills with life as you explore. Earn sparks, keep a streak, and build your own personal field guide.

Built 100% native — SwiftUI, SwiftData, and Apple's on-device Vision framework. No backend, no accounts, no cost. Your whole Grove lives on your phone.

---

## ✨ The core loop

> **Spot a friend → Snap → "A new friend found your Grove! Red Fox — +120 sparks, first find!" → it settles into your Woods → go find more.**

- **Friends come home.** Every animal you photograph moves into the habitat **zone** it belongs to — the Garden, Pond, Meadow, Woods, or Treetops. No flat grid, no `???` silhouettes; empty zones are just quiet spots waiting for a visitor.
- **A personal field guide.** Each friend has a guide page with your photos, its **real name**, the **nickname you give it**, a field note, and where/when you first met.
- **Live camera only.** Catches must be taken *in the moment* — no photo-library upload, so you can't collect screenshots or downloaded images. (A library picker exists in **DEBUG builds only** for Simulator testing; it's compiled out of release builds.)
- **On-device identification.** Photos are classified locally with Apple's Vision framework — instant, private, offline, free.
- **Always rewarding.** If Vision can't confidently name what it saw, you still meet a **Mystery Friend**, so a snap never feels wasted.
- **First-find bonus.** The first time a species visits, sparks are doubled — the collection thrill.
- **Gentle rarity.** Field-guide language, not loot: Common 💚 → Uncommon 💙 → Seldom seen 💜 → Rarely seen 💗 → Almost mythical 💛.
- **Daily streaks.** 🔥 Catch something each day to keep your streak alive (current + all-time best).
- **Achievements.** 🎖 Badges with live progress bars, celebrated the instant you unlock them mid-catch.
- **Discovery map.** 🗺️ Every geotagged catch drops a rarity-colored pin where you met that friend.

## 📱 Screens

| Tab | What it does |
|-----|--------------|
The bottom bar has four tabs — **Grove · Map** and **Journal · Profile** — split around a floating **Catch** button in the center.

| Screen | What it does |
|--------|--------------|
| **Grove** | Your cozy world, organized by habitat zone. Each friend you've met lives here as a photo portrait ringed in its rarity color; tap one to open its guide page. |
| **Map** | A MapKit map with a rarity-colored pin at every place you've made a catch. Tap a pin to open that friend. |
| **Catch** | The floating center button — live camera + shutter, strictly capture-in-the-moment (a DEBUG-only library picker exists for Simulator testing). |
| **Journal** | Your streak, level, total sparks, friends & zones counts, an achievements summary, and collection-by-rarity (with your rarest catch). |
| **Profile** | A bit about you, a link to **Settings & Preferences**, and (in DEBUG) the developer test tools — the sample-data toggle and Erase everything. |
| **Achievements** | (from **Journal**) A grid of badges — unlocked ones in full color, locked ones dimmed with a live progress bar. |
| **Guide page** | (tap a friend) Your photos, its real name, the nickname you gave it, its Grove zone, a field note, and your sighting history. |

## 🚀 Running it

1. Open `Grove.xcodeproj` in **Xcode 16 or newer**.
2. Select an iOS 17+ simulator or your own device, and hit **Run** (⌘R).
3. **Simulator:** there's no camera, so use the **DEBUG: Pick from Library** button on the Catch tab (DEBUG builds only). Drag any animal photo into the simulator first.
4. **Real device:** point the camera at an animal (or a pet!) and tap **Snap!**. You'll need to trust your developer certificate the first time.

> Requires iOS 17.0+ (SwiftData). Signing is set to **Automatic** — just pick your team in *Signing & Capabilities* to run on a device.

## 🧠 How identification works today

The MVP uses Apple's built-in `VNClassifyImageRequest`, which returns fairly **coarse** labels ("bird", "dog", "squirrel"...). The catalog in `CreatureCatalog.swift` maps those labels to real friends (each with a habitat zone), preferring rarer matches. This is deliberately simple and 100% free — it's the fun-first foundation.

**The upgrade path is clean:** swap the guts of `AnimalClassifier.classify` for a trained Core ML species model or a cloud vision service, expand the catalog's `matchKeywords`, and nothing else in the app has to change.

## 🗂 Project structure

```
Grove/
├── GroveApp.swift            # App entry + SwiftData container
├── Models/
│   ├── Rarity.swift           # Rarity tiers, sparks, field-guide language, colors
│   ├── Habitat.swift          # Grove zones (Garden/Pond/Meadow/Woods/Treetops)
│   ├── Species.swift          # A collectible friend *type* (catalog data)
│   └── Catch.swift            # A photo you took (nickname + geotag; the persisted model)
├── Catalog/
│   └── CreatureCatalog.swift  # The friends (real names + zones) + label→friend matching
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
    ├── Grove/                 # The Grove (habitat zones) + guide entry page
    ├── Map/                   # Discovery map of sightings
    ├── Achievements/          # Badge grid with progress
    └── Profile/               # "Journal" tab — streak, level, achievements & rarity stats
```

## 🛣 Roadmap (post-MVP)

- **Better ID** — Core ML species model or cloud vision for true species names.
- **Social** (planned) — friends, shared sightings, leaderboards. The data model is already structured so a sync/backend layer can bolt on without a rewrite.
- **Daily goals** — a rotating "catch a bird today" style quest on top of the streak system.
- **Real friend art** — replace the placeholder emoji with commissioned illustrations.
- **Anti-cheat** — camera-only capture already blocks library uploads. Next up (once leaderboards exist): liveness checks so you can't photograph a screen or printout.

---

*Grow a place full of the life you've met.* 🌳
