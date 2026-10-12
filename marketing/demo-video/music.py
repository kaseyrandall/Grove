"""Synthesizes the Grove demo soundtrack (music + SFX) to audio.wav.

Pure numpy: a gentle plucked-guitar/marimba score in F major at 100 BPM, a soft
pad and bass, light shaker, plus sound effects placed from cues.json (written
by render.mjs so they line up exactly with the on-screen taps and pops).
"""
import json, sys, wave
import numpy as np

SR = 44100
# usage: music.py cues.json out.wav [duration]   (45 = full cut, 15 = short cut)
DUR = float(sys.argv[3]) if len(sys.argv) > 3 else 45.0
SHORT = DUR < 30
N = int(SR * DUR)
rng = np.random.default_rng(3)
music = np.zeros((N, 2))
sfx = np.zeros((N, 2))

BPM = 100
BEAT = 60 / BPM
BAR = 4 * BEAT


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def place(buf, t, sig, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N or i + len(sig) <= 0:
        return
    sig = sig[: N - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    buf[i:i + len(sig), 0] += sig * gain * l * 1.414
    buf[i:i + len(sig), 1] += sig * gain * r * 1.414


def env(n, a=0.005, d=None, curve=4.0):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4))
    if d:
        e *= np.exp(-curve * t / d)
    return e


def pluck(f, dur=1.6, bright=0.5):
    """Karplus-Strong, vectorised block-by-block over the delay length."""
    p = max(2, int(SR / f))
    n = int(dur * SR)
    y = np.zeros(n + p + 1)
    y[:p] = rng.uniform(-1, 1, p) * (1 - bright) + np.sin(np.linspace(0, 2 * np.pi, p)) * bright
    k = 0.4985 + 0.0013 * min(1, f / 600)
    i = p
    while i < n + p:
        j = min(i + p, n + p)
        y[i:j] = k * (y[i - p:j - p] + y[i - p - 1:j - p - 1]) if i - p - 1 >= 0 else k * (y[i - p:j - p] + np.r_[0, y[i - p:j - p - 1]])
        i = j
    out = y[:n]
    return out / (np.abs(out).max() + 1e-9) * env(n, .002, dur, 3.0)


def bell(f, dur=1.2, partials=((1, 1), (2.0, .5), (3.01, .25), (4.2, .12))):
    t = np.arange(int(dur * SR)) / SR
    s = sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t * (3 + m * 1.5) / dur) for m, a in partials)
    return s * env(len(t), .003)


def marimba(f, dur=0.9):
    t = np.arange(int(dur * SR)) / SR
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + .35 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 14)
    return s * env(len(t), .002)


def pad_note(f, dur):
    t = np.arange(int(dur * SR)) / SR
    s = sum(a * np.sin(2 * np.pi * f * m * t + m) for m, a in ((1, 1), (2, .3), (3, .12)))
    s *= 1 + .15 * np.sin(2 * np.pi * 4.5 * t)  # gentle tremolo
    a = np.minimum(1, t / .6) * np.minimum(1, (dur - t) / .8)
    return s * a


def lowpass(x, a):
    # one-pole lowpass via exponential smoothing (cumulative trick, block-free)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(0, len(x), 1):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def noise_burst(dur, a=0.25, decay=None):
    n = int(dur * SR)
    x = rng.uniform(-1, 1, n)
    hp = x - lowpass(x, a)  # brighten
    return hp * env(n, .002, decay or dur, 5)


def sweep(f0, f1, dur, shape='sine'):
    t = np.arange(int(dur * SR)) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def whoosh(dur=0.5, up=True):
    n = int(dur * SR)
    x = rng.uniform(-1, 1, n)
    t = np.arange(n) / SR
    # moving lowpass cutoff
    y = np.empty(n)
    acc = 0.0
    for i in range(n):
        p = t[i] / dur
        a = 0.02 + 0.25 * (p if up else 1 - p)
        acc += a * (x[i] - acc)
        y[i] = acc
    shape = np.sin(np.pi * np.minimum(1, t / dur)) ** 2
    return y * shape * 2.2


# ---------------------------------------------------------------- score
# F major: I – V – vi – IV  (F, C, Dm, Bb)
CHORDS = [[53, 57, 60], [48, 52, 55], [50, 53, 57], [46, 50, 53]]
ROOTS = [41, 36, 38, 34]
SCALE = [65, 67, 69, 72, 74, 77, 79, 81]  # F pentatonic-ish (F G A C D F G A)

# 8-bar melody in eighth notes (index into SCALE, None = rest), call & answer
MEL = [
    [5, None, 4, 3, None, 2, 3, None], [4, None, 3, 1, None, 2, None, None],
    [2, 3, 4, None, 3, 2, 0, None], [1, None, 2, 3, None, 2, None, None],
    [5, None, 6, 5, 4, None, 3, None], [4, None, 3, 4, 6, None, 5, None],
    [7, None, 6, 5, None, 4, 3, None], [2, None, 3, 1, None, 0, None, None],
]

START = 0.0 if SHORT else 3.45      # band kicks in with the phone
END_MUSIC = DUR - (2.6 if SHORT else 4.0)   # final chord rings under the end card
bar_t = START
bar = 0
while bar_t < END_MUSIC - 0.01:
    ci = bar % 4
    # pad
    for m in CHORDS[ci]:
        place(music, bar_t, pad_note(hz(m), BAR + .4), .045, pan=(m - 52) / 30)
    # bass on 1 and 3
    for b in (0, 2):
        place(music, bar_t + b * BEAT, marimba(hz(ROOTS[ci]), 1.2), .22)
    # strummed chord pluck on 1, "and of 2", 4
    for b in (0, 1.5, 3):
        for k, m in enumerate(CHORDS[ci]):
            place(music, bar_t + b * BEAT + k * .018, pluck(hz(m + 12), 1.3, .3), .07, pan=-.3)
    # melody (enters bar 2)
    if bar >= (0 if SHORT else 1):
        for k, idx in enumerate(MEL[bar % 8]):
            if idx is not None:
                place(music, bar_t + k * BEAT / 2, pluck(hz(SCALE[idx]), 1.4, .6), .16, pan=.25)
                place(music, bar_t + k * BEAT / 2, marimba(hz(SCALE[idx] + 12), .5), .03, pan=.25)
    # shaker on the off-beats
    if bar >= (0 if SHORT else 1):
        for k in range(8):
            g = .035 if k % 2 else .015
            place(music, bar_t + k * BEAT / 2, noise_burst(.07, .6, .04), g, pan=.4)
    bar += 1
    bar_t += BAR

# intro: a soft rising arpeggio under the logo (full cut only)
if not SHORT:
    for k, m in enumerate([65, 69, 72, 77, 81]):
        place(music, .25 + k * .22, bell(hz(m), 1.8), .09, pan=-.4 + k * .2)
    for m in CHORDS[0]:
        place(music, 0.0, pad_note(hz(m), 3.8), .04)

# outro: final F chord ringing out + sparkle
for k, m in enumerate([53, 57, 60, 65, 69, 72, 77]):
    place(music, END_MUSIC - BAR + 0 + k * .03, pluck(hz(m), 4.0, .4), .09, pan=-.5 + k * .15)
for m in [53, 57, 60]:
    place(music, END_MUSIC - BAR, pad_note(hz(m), 6.5), .05)
for k, m in enumerate([77, 81, 84, 89]):
    place(music, (DUR - 3.0 if SHORT else 39.0) + k * .12, bell(hz(m), 2.0), .06, pan=.2)

# ---------------------------------------------------------------- sfx
cues = json.load(open(sys.argv[1] if len(sys.argv) > 1 else 'cues.json'))
for c in cues:
    t, ty = c['t'], c['type']
    if ty == 'tap':
        place(sfx, t, bell(2400, .05, ((1, 1),)), .05)
    elif ty == 'key':
        place(sfx, t, noise_burst(.03, .7, .02), .08)
    elif ty == 'pop':
        place(sfx, t, sweep(380, 980, .09) * env(int(.09 * SR), .002, .09, 3), .22)
        place(sfx, t + .03, bell(hz(84 + rng.integers(0, 3) * 2), .5), .05)
    elif ty == 'whoosh':
        place(sfx, t, whoosh(.6), .22)
    elif ty == 'swish':
        place(sfx, t, whoosh(.3), .14)
    elif ty == 'peek':
        place(sfx, t + .1, sweep(300, 720, .16) * env(int(.16 * SR), .005, .16, 2), .14)
    elif ty == 'shutter':
        place(sfx, t, noise_burst(.05, .5, .03), .55)
        place(sfx, t + .07, noise_burst(.06, .4, .04), .45)
        place(sfx, t, sweep(180, 90, .06) * env(int(.06 * SR), .001, .06, 3), .3)
    elif ty in ('confetti', 'reveal'):
        notes = [72, 77, 81, 84] if ty == 'confetti' else [77, 81, 84, 89]
        for k, m in enumerate(notes):
            place(sfx, t + k * .07, bell(hz(m), 1.2), .1, pan=-.3 + k * .2)
        place(sfx, t, noise_burst(.25, .3, .2), .05)
    elif ty == 'sparkle':
        for k in range(7):
            place(sfx, t + k * .045, bell(hz(91 + [0, 3, 5, 7, 10, 12, 15][k]), .5), .05, pan=-.6 + k * .2)
    elif ty == 'achievement':
        for k, m in enumerate([77, 81, 84]):
            place(sfx, t + k * .11, bell(hz(m), 1.4), .12)
        place(sfx, t + .33, bell(hz(89), 1.8), .1)
    elif ty == 'fly':
        place(sfx, t, whoosh(.8, up=True), .2)
    elif ty == 'land':
        place(sfx, t, marimba(hz(53), .5), .25)
        place(sfx, t + .02, bell(hz(84), 1.0), .1)
        place(sfx, t + .1, bell(hz(89), 1.0), .07)
    elif ty == 'legend':
        for k, m in enumerate([77, 81, 84, 89, 93]):
            place(sfx, t + k * .06, bell(hz(m), 2.2), .1, pan=-.5 + k * .25)
        place(sfx, t, sweep(380, 980, .09) * env(int(.09 * SR), .002, .09, 3), .2)
    elif ty == 'drop':
        place(sfx, t, marimba(hz(SCALE[int(rng.integers(0, 6))] + 12), .3), .07, pan=float(rng.uniform(-.5, .5)))
    elif ty == 'streak':
        place(sfx, t - .2, whoosh(.4), .15)
        for k, m in enumerate([81, 84, 89]):
            place(sfx, t + k * .08, bell(hz(m), 1.0), .1)
    elif ty == 'tick':
        place(sfx, t, marimba(hz(84), .4), .1)

# ---------------------------------------------------------------- mix
t = np.arange(N) / SR
fade = np.clip((DUR - t) / 2.5, 0, 1)[:, None]          # final fade
duck = np.ones(N)                                         # (no ducking needed; sfx are light)
mix = music * .9 + sfx
mix *= fade
mix *= np.clip(t / .05, 0, 1)[:, None]
peak = np.abs(mix).max()
mix = np.tanh(mix / peak * 1.2) / np.tanh(1.2) * 0.89  # gentle soft-clip + normalize
pcm = (mix * 32767).astype('<i2')
with wave.open(sys.argv[2] if len(sys.argv) > 2 else 'audio.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('wrote audio, peak was', round(float(peak), 3))
