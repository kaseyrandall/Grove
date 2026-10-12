# Grove demo video

A 45-second vertical (1080×1920) demo/explainer, `grove-demo.mp4`. The app screens
are recreated in HTML/CSS from the real SwiftUI views (Theme palette, habitat
gradients, rarity tints, catalog data, copy) and animated on a deterministic
timeline, rendered frame by frame in headless Chromium, and scored with a
synthesized soundtrack. The wildlife is real: openly licensed fox footage plays in
the viewfinder, the frame you snap becomes the friend's photo, and every other
friend is a real iNaturalist photo. The end card carries Apple's official
"Download on the App Store" badge. **See [CREDITS.md](CREDITS.md)** — the CC BY
licenses require keeping the credit line on the end card (or in the post caption).

## Storyboard

| Time | Caption | On screen |
|------|---------|-----------|
| 0–3.4s | — | App icon, "Grove", tagline |
| 3.4–8.5s | Spot a friend out in the wild | Camera: real footage of a fox kit turning to look at you, tap to focus, **Snap!** |
| 8.7–12.8s | Snap it, then name it yourself | Mystery Friend + animal confetti → *Choose your friend* → search "fox" → pick Fox |
| 13–16.6s | First find? Double sparks ✨ | Fox · 💜 Seldom seen · Woods · **+120 sparks · 2× first find!** · 🎖 Lucky Day |
| 16.8–22.2s | Every friend comes home to your Grove | Done → the fox flies into the Woods card |
| 22.4–28.1s | Keep exploring. Watch it fill with life | Six more friends pop into their zones, ending with a 💛 Almost mythical eagle |
| 28.3–32.8s | Remember where you met 🗺️ | Discovery Map: 18 rarity-colored pins drop in |
| 33–38.4s | Keep your streak alive 🔥 | Journal: field guide, streak ticks to 12, level/sparks, collection by rarity |
| 38.5–45s | — | End card: icon, tagline, "Live camera only · You name every friend · No accounts", App Store badge, credits |

## Re-rendering

Needs Node + Playwright (Chromium), Python 3 + numpy, and ffmpeg.

```sh
cd marketing/demo-video
ln -s "$(npm root -g)" node_modules            # if playwright is installed globally
node render.mjs                                # → grove-demo-silent.mp4 + cues.json
python3 music.py cues.json audio.wav           # → soundtrack, SFX synced to cues
ffmpeg -y -i grove-demo-silent.mp4 -i audio.wav -c:v copy -c:a aac -b:a 192k -shortest grove-demo.mp4
```

Preview single frames without rendering the whole video:

```sh
node render.mjs --still 14.9 frame.png 27.5 frame2.png
```

## Editing

- **Copy / captions / end card:** `index.html` (`#captions`, `#outro`).
- **Timing:** everything is in `timeline.js`, in seconds. Each scene has its own
  `build*()` function; `cue(t, type)` drops a sound effect at the same moment.
- **Friends in the Grove / montage:** the `FRIENDS` table (`appearsAt` > 0 means
  it pops in during the video). **Map pins:** `PINS`.
- **Viewfinder footage:** `assets/fox-clip.mp4` (4 s, 30 fps, portrait). `render.mjs`
  extracts it to `assets/.frames/` on first run; delete that folder after swapping the clip.
  The snapped photo is `assets/fox-snap.jpg` (4:3) / `fox-snap-sq.jpg` (portrait).
- **Friend photos:** `assets/photos/<friend>.jpg` and `<friend>-sq.jpg`; update CREDITS.md and
  the credit line in `index.html` if you swap any.
- **Music:** `music.py`. The score is a I–V–vi–IV loop in F at 100 BPM.
