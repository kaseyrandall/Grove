# Grove demo video

A 45-second demo/explainer plus a 15-second ad cut, each in three shapes — all rendered
from the same timeline:

| | 45 s full | 15 s ad cut | Best for |
|---|---|---|---|
| 9:16 (1080×1920) | `grove-demo.mp4` | `grove-demo-15s.mp4` | Reels, TikTok, Shorts, Stories |
| 16:9 (1920×1080) | `grove-demo-16x9.mp4` | `grove-demo-16x9-15s.mp4` | YouTube, website, presentations |
| 1:1 (1080×1080) | `grove-demo-1x1.mp4` | `grove-demo-1x1-15s.mp4` | Instagram/Facebook feed, LinkedIn, X |

The app screens
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
| 0–3.4s | — | App icon, "Grove", "Snap a friend. Grow your grove." |
| 3.4–8.5s | Spot a friend out in the wild | Camera: real footage of a fox kit turning to look at you, tap to focus, **Snap!** |
| 8.7–12.8s | Snap it, then name it yourself | Mystery Friend + animal confetti → *Choose your friend* → search "fox" → pick Fox |
| 13–16.6s | First find? Double sparks ✨ | Fox · 💜 Seldom seen · Woods · **+120 sparks · 2× first find!** · 🎖 Lucky Day |
| 16.8–22.2s | Every friend comes home to your Grove | Done → the fox flies into the Woods card |
| 22.4–28.1s | Keep exploring. Watch it fill with life | Six more friends pop into their zones, ending with a 💛 Almost mythical eagle |
| 28.3–32.8s | Remember where you met 🗺️ | Discovery Map: 18 rarity-colored pins drop in |
| 33–38.4s | Keep your streak alive 🔥 | Journal: field guide, streak ticks to 12, level/sparks, collection by rarity |
| 38.5–45s | — | End card: icon, tagline, "60+ friends to find" + "No account, no ads, no tracking", App Store badge (+ QR code in 16:9), credits |

## 15-second cut

Six hard-cut segments of the full timeline (`SEGMENTS` in `timeline.js`) with their own,
punchier captions (`#s0`–`#s4` in `index.html`): spot the fox → snap → *Name it. Earn
sparks* (+120, 2× first find) → *It comes home to your Grove* → *Watch it fill with life*
(montage, mythical eagle) → map → end card with the App Store badge and a single value
prop, "No account · no ads · no tracking". The background keeps
running across cuts; sound effects inside each segment are carried over, with a swish at
each cut, and `music.py … 15` scores it to length.

## Re-rendering

Needs Node + Playwright (Chromium), Python 3 + numpy, and ffmpeg.

```sh
cd marketing/demo-video
ln -s "$(npm root -g)" node_modules            # if playwright is installed globally
node render.mjs                                # → grove-demo-silent.mp4 + cues.json
node render.mjs --landscape                    # → grove-demo-16x9-silent.mp4
python3 music.py cues.json audio.wav           # → soundtrack, SFX synced to cues (shared by both cuts)
ffmpeg -y -i grove-demo-silent.mp4 -i audio.wav -c:v copy -c:a aac -b:a 192k -shortest grove-demo.mp4
ffmpeg -y -i grove-demo-16x9-silent.mp4 -i audio.wav -c:v copy -c:a aac -b:a 192k -shortest grove-demo-16x9.mp4

# square: --square; 15-second cut: --short (combine with --landscape / --square)
node render.mjs --square                       # → grove-demo-1x1-silent.mp4
node render.mjs --short                        # → grove-demo-15s-silent.mp4 + cues-15s.json
python3 music.py cues-15s.json audio-15s.wav 15
ffmpeg -y -i grove-demo-15s-silent.mp4 -i audio-15s.wav -c:v copy -c:a aac -b:a 192k -shortest grove-demo-15s.mp4
```

Preview single frames without rendering the whole video:

```sh
node render.mjs --still 14.9 frame.png 27.5 frame2.png
node render.mjs --landscape --still 14.9 wide.png
```

## Editing

- **Copy / captions / end card:** `index.html` (`#captions`, `#outro`). The tagline and value
  props match grovegame.app: "Snap a friend. Grow your grove." · "60+ friends to find" ·
  "No account, no ads, no tracking" (the 15 s cut shows only the last, via `.chip.shortonly`).
- **QR code:** `assets/app-store-qr.svg` → `https://apps.apple.com/app/id6807932841` (redirects
  to the listing in every storefront). Shown on 16:9 end cards only. Regenerate with any QR
  tool (error correction M) if the link changes, and check it decodes from a rendered frame.
- **1:1 layout:** the `.square` CSS block in `index.html` + `SQUARE` floater positions.
- **16:9 layout:** the `.landscape` CSS block in `index.html` (phone on the right, captions
  left-aligned on the left, chips in a row on the end card) plus the `LANDSCAPE` floater
  positions in `timeline.js`. Everything else is shared.
- **Phone scale:** `--S` in `index.html` (applied with CSS `zoom`, not a transform — a
  transform made Chromium drop the rounded clip/bezel paint at the corners).
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
