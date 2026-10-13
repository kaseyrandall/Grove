// Grove demo video — deterministic timeline.
// Every motion is a paused Web Animation (or a pure `hook(t)`), so the
// renderer can seek to any frame with `window.seek(seconds)`.

const LANDSCAPE = document.documentElement.classList.contains('landscape');
const SQUARE = document.documentElement.classList.contains('square');
const S = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--S')); // phone points → video pixels
const DURATION = 45;
const SNAP = 7.3;              // shutter moment (viewfinder freezes here)
const pending = [];             // image decodes the current frame must wait for
const $ = (s, root = document) => root.querySelector(s);
const hooks = [];
const floatAnims = [];
const CUES = [];                // sound-effect cues, read by the audio mixer
const cue = (t, type, extra = {}) => CUES.push({ t, type, ...extra });

// ---------- easing ----------
function springEase(z) {
  const w = 6.2 / z, wd = w * Math.sqrt(1 - z * z), pts = [];
  for (let i = 0; i <= 60; i++) {
    const t = i / 60;
    pts.push((1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + (z * w / wd) * Math.sin(wd * t))).toFixed(4));
  }
  pts[60] = '1';
  return `linear(${pts.join(',')})`;
}
const EASE = {
  out: 'cubic-bezier(.22,1,.36,1)', inout: 'cubic-bezier(.65,0,.35,1)', in: 'cubic-bezier(.55,0,1,.45)',
  lin: 'linear', spring: springEase(0.5), soft: springEase(0.72), bouncy: springEase(0.36),
};
const easeOut = x => 1 - Math.pow(1 - Math.min(1, Math.max(0, x)), 3);

function A(el, kf, t0, dur, ease = 'out', extra = {}) {
  const els = el instanceof Element ? [el] : Array.from(el);
  els.forEach(e => e.animate(kf, { delay: t0 * 1000, duration: Math.max(1, dur * 1000), fill: 'forwards', easing: EASE[ease] || ease, ...extra }));
}
const fadeIn = (el, t, d = .4, ease = 'out') => A(el, [{ opacity: 0 }, { opacity: 1 }], t, d, ease);
const fadeOut = (el, t, d = .4, ease = 'out') => A(el, [{ opacity: 1 }, { opacity: 0 }], t, d, ease);

function rng(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const html = s => { const d = document.createElement('div'); d.innerHTML = s.trim(); return d.firstElementChild; };

// ---------- data ----------
const TINT = ['#9FE8C8', '#A9D8FF', '#C9B6FF', '#FFB3C7', '#FFD98A'];
const TINT_RGB = ['159,232,200', '169,216,255', '201,182,255', '255,179,199', '255,217,138'];
const FIELD = ['Common', 'Uncommon', 'Seldom seen', 'Rarely seen', 'Almost mythical'];
const HEART = ['💚', '💙', '💜', '💗', '💛'];
const BASE_SPARKS = [10, 25, 60, 120, 300];
const ZONES = {
  home:   { name: 'Home',     emoji: '🏠', g: ['#FFEFE6', '#FFDCC9'] },
  garden: { name: 'Garden',   emoji: '🏡', g: ['#EEF6DB', '#DCEDC2'] },
  pond:   { name: 'Pond',     emoji: '🌊', g: ['#DCF1FF', '#BFE6F7'] },
  coast:  { name: 'Coast',    emoji: '🏖️', g: ['#FFF0D4', '#B8E4EC'] },
  meadow: { name: 'Meadow',   emoji: '🌼', g: ['#F4F6D9', '#E6EFC2'] },
  woods:  { name: 'Woods',    emoji: '🌲', g: ['#DCF0DC', '#C2E4C2'] },
  sky:    { name: 'Treetops', emoji: '🌤️', g: ['#DDEFFF', '#C7E4FF'] },
  wilds:  { name: 'Wilds',    emoji: '🌴', g: ['#FCE9C9', '#F6D6A0'] },
};
const ZONE_ORDER = ['home', 'garden', 'pond', 'coast', 'meadow', 'woods', 'sky', 'wilds'];
// real wildlife photos (iNaturalist, CC BY / CC0 — see CREDITS.md); the fox is the frame you snapped
const photoSq = key => key === 'fox' ? 'assets/fox-snap-sq.jpg' : `assets/photos/${key}-sq.jpg`;
const zgrad = z => `linear-gradient(180deg, ${ZONES[z].g[0]}, ${ZONES[z].g[1]})`;

// screen-point center of an element inside the phone
function pt(el) {
  const r = el.getBoundingClientRect(), s = $('#screen').getBoundingClientRect();
  return { x: (r.left + r.width / 2 - s.left) / S, y: (r.top + r.height / 2 - s.top) / S };
}
function tap(x, y, t) {
  const d = html(`<div class="tapdot" style="left:${x}px;top:${y}px"></div>`);
  $('#taps').appendChild(d);
  A(d, [{ opacity: 0, transform: 'scale(.5)' }, { opacity: 1, transform: 'scale(1)' }], t - .14, .14, 'out');
  A(d, [{ opacity: 1, transform: 'scale(1)' }, { opacity: 0, transform: 'scale(1.35)' }], t + .02, .32, 'out');
  cue(t, 'tap');
}
function press(el, t) {
  A(el, [{ transform: 'scale(1)' }, { transform: 'scale(.93)' }], t - .06, .1, 'out');
  A(el, [{ transform: 'scale(.93)' }, { transform: 'scale(1)' }], t + .06, .4, 'spring');
}

// ============================================================
function build() {
  const R = rng(7);

  // ---------- floaters ----------
  const floatEm = ['🦊', '🐿️', '🦆', '🦉', '🐰', '🦋', '🐢', '🐝', '🐸', '🦔', '🐞', '🦅', '🐱', '🦝'];
  const spots = SQUARE
    ? [[40, 300], [960, 300], [40, 560], [970, 560], [60, 820], [950, 820], [200, 980], [840, 990], [120, 1000], [900, 140], [520, 1000], [60, 120], [720, 1000], [980, 120]]
    : LANDSCAPE
    ? [[50, 150], [1090, 110], [40, 520], [1100, 470], [60, 860], [1090, 840], [1760, 130], [1790, 470], [1770, 820], [880, 900], [560, 70], [300, 930], [1830, 960], [360, 60]]
    : [[60, 420], [930, 470], [40, 760], [960, 820], [70, 1120], [940, 1180], [30, 1460], [960, 1520], [80, 1780], [920, 1830], [210, 180], [840, 150], [500, 1790], [120, 300]];
  spots.forEach(([x, y], i) => {
    const f = html(`<div class="floater emoji" style="left:${x}px;top:${y}px;font-size:${54 + (i % 3) * 10}px">${floatEm[i]}</div>`);
    $('#floaters').appendChild(f);
    floatAnims.push(f.animate([{ transform: 'translateY(-16px) rotate(-7deg)' }, { transform: 'translateY(16px) rotate(7deg)' }],
      { duration: 2600 + (i % 4) * 500, delay: -i * 410, iterations: Infinity, direction: 'alternate', easing: EASE.inout }));
  });
  // keep the caption band clean once captions start
  A($('#floaters').children[10], [{ opacity: .5 }, { opacity: 0 }], 3.2, .5);
  A($('#floaters').children[11], [{ opacity: .5 }, { opacity: 0 }], 3.2, .5);
  A($('#floaters').children[13], [{ opacity: .5 }, { opacity: 0 }], 3.2, .5);
  A([$('#floaters').children[10], $('#floaters').children[11], $('#floaters').children[13]], [{ opacity: 0 }, { opacity: .5 }], 38.9, .8);
  // clear the floaters that would sit on the end card's tagline and credits
  A((SQUARE ? [2, 3, 4, 5, 6, 7, 8, 10, 12] : LANDSCAPE ? [4, 5, 9, 11, 12, 0, 1, 3] : [3, 8, 9, 12]).map(i => $('#floaters').children[i]), [{ opacity: .5 }, { opacity: 0 }], 38.6, .6);

  // ---------- intro ----------
  const [icon, word, tag] = $('#intro').children;
  A(icon, [{ opacity: 0, transform: 'scale(.4) rotate(-10deg)' }, { opacity: 1, transform: 'scale(1) rotate(0)' }], .25, 1.0, 'spring');
  cue(.25, 'pop');
  A(word, [{ opacity: 0, transform: 'translateY(40px)' }, { opacity: 1, transform: 'translateY(0)' }], .65, .7, 'soft');
  A(tag, [{ opacity: 0, transform: 'translateY(30px)' }, { opacity: 1, transform: 'translateY(0)' }], 1.05, .7, 'soft');
  A([icon, word, tag], [{ opacity: 1, transform: 'translateY(0)' }, { opacity: 0, transform: 'translateY(-80px)' }], 3.2, .5, 'in');

  // ---------- phone in/out ----------
  cue(3.45, 'whoosh');
  A($('#phoneWrap'), [{ transform: 'translateY(1700px)' }, { transform: 'translateY(0)' }], 3.45, 1.1, 'soft');
  cue(38.5, 'whoosh');
  A($('#phoneWrap'), [{ transform: 'translateY(0)', opacity: 1 }, { transform: 'translateY(1800px)', opacity: 1 }], 38.5, .8, 'in');

  // ---------- captions ----------
  const caps = [['c1', 4.3, 8.5], ['c2', 8.7, 12.8], ['c3', 13.0, 16.6], ['c4', 16.8, 22.2], ['c5', 22.4, 28.1], ['c6', 28.3, 32.8], ['c7', 33.0, 38.4]];
  caps.forEach(([id, a, b]) => {
    const el = $('#' + id);
    A(el, [{ opacity: 0, transform: 'translateY(30px) scale(.97)' }, { opacity: 1, transform: 'translateY(0) scale(1)' }], a, .55, 'soft');
    A(el, [{ opacity: 1, transform: 'translateY(0) scale(1)' }, { opacity: 0, transform: 'translateY(-20px) scale(1)' }], b, .3, 'in');
  });

  // ---------- status bar / home indicator colour ----------
  hooks.push(t => {
    const dark = t >= 7.45;
    $('#statusbar').style.color = dark ? '#4A4458' : '#fff';
    $('#homebar').style.background = dark ? '#4A4458' : '#fff';
  });

  buildCamera();
  buildResult(R);
  buildGrove();
  buildTabBar();
  buildMap();
  buildJournal();
  buildOutro();
}

// ============================================================ CAMERA
function buildCamera() {
  // Real footage (a fox kit, Alexis Lours, CC BY 4.0) plays in the viewfinder,
  // one pre-extracted frame per video frame so every render is deterministic.
  const cam = $('#camFrame');
  const FR = 120, frameAt = t => Math.max(0, Math.min(FR - 1, Math.floor((Math.min(t, SNAP) - 3.45) * 30)));
  hooks.push(t => {
    const src = `assets/.frames/f${String(frameAt(t) + 1).padStart(3, '0')}.jpg`;
    if (!cam.src.endsWith(src)) { cam.src = src; pending.push(cam.decode().catch(() => {})); }
  });
  // a slow push-in on the fox, like steadying the phone
  A($('#camScene'), [{ transform: 'scale(1)' }, { transform: 'scale(1.22)' }], 3.45, 3.85, 'inout');

  tap(156, 317, 6.0);
  const focus = $('#focus');
  A(focus, [{ opacity: 0, transform: 'scale(1.45)' }, { opacity: 1, transform: 'scale(1)' }], 6.02, .35, 'out');
  A(focus, [{ opacity: 1, transform: 'scale(1)' }, { opacity: .55, transform: 'scale(1)' }], 6.7, .4, 'out');
  A(focus, [{ opacity: .55 }, { opacity: 0 }], 7.35, .1, 'out');

  tap(195, 751, 7.2);
  press($('#shutter'), 7.2);
  cue(SNAP, 'shutter');
  A($('#flash'), [{ opacity: 0 }, { opacity: 1 }], 7.3, .08, 'lin');
  A($('#flash'), [{ opacity: 1 }, { opacity: 0 }], 7.5, .6, 'out');
  A($('#cam'), [{ opacity: 1 }, { opacity: 0 }], 7.44, .02, 'lin');
}

// ============================================================ RESULT + PICKER
function buildResult(R) {
  const res = $('#result');
  // appears under the flash
  A(res, [{ opacity: 0 }, { opacity: 1 }], 7.42, .02, 'lin');

  // photo (same painted scene, cropped 4:3 around the fox)
  $('#photoCrop').innerHTML = '<img src="assets/fox-snap.jpg" style="width:100%;height:100%;object-fit:cover;display:block">';
  A($('#photo'), [{ transform: 'scale(.6) rotate(-8deg)' }, { transform: 'scale(1) rotate(0)' }], 7.5, 1.0, 'spring');
  cue(7.55, 'confetti');

  // zone chips
  const zrow = $('#zrow');
  ZONE_ORDER.forEach(z => {
    zrow.appendChild(html(`<div class="zchip" data-z="${z}"><div class="sel" style="background:${zgrad(z)}"></div><span><span class="emoji">${ZONES[z].emoji}</span> ${ZONES[z].name}</span></div>`));
  });
  const rowW = zrow.scrollWidth;
  const center = z => { const c = $(`.zchip[data-z="${z}"]`); return Math.max(-(rowW - 390), Math.min(0, 195 - (c.offsetLeft + c.offsetWidth / 2))); };
  const tMeadow = center('meadow'), tWoods = center('woods');
  zrow.style.transform = `translateX(${tMeadow}px)`;
  $('.zchip[data-z="meadow"] .sel').style.opacity = 1;

  // confetti — a mystery snap rains random animals; once named, it rains that friend
  const animals = ['🦊', '🐿️', '🦆', '🦉', '🐰', '🦋', '🐢', '🐝', '🐸', '🦔', '🐞', '🐱', '🐶', '🦝', '🐭', '🦌', '🐌', '🦜'];
  const rain = (t0, pool, n) => {
    for (let i = 0; i < n; i++) {
      const e = pool[Math.floor(R() * pool.length)];
      const x = R() * 370, d = 2.3 + R() * 1.5, dl = t0 + R() * 1.1, rot = (R() - .5) * 540, drift = (R() - .5) * 70, size = 22 + R() * 14;
      const p = html(`<div class="cf emoji" style="left:${x}px;font-size:${size}px;opacity:0">${e}</div>`);
      $('#confetti').appendChild(p);
      A(p, [{ opacity: 1, transform: 'translate(0,0) rotate(0)' }, { opacity: 1, transform: `translate(${drift}px, 940px) rotate(${rot}deg)` }], dl, d, 'cubic-bezier(.3,.1,.7,1)');
    }
  };
  rain(7.5, animals, 34);

  // --- tap "Choose your friend" → picker ---
  const idbtn = $('#idbtn'), ib = pt(idbtn);
  tap(ib.x, ib.y, 9.9);
  press(idbtn, 9.9);
  const pk = $('#picker');
  cue(10.05, 'swish');
  A(pk, [{ transform: 'translateX(390px)' }, { transform: 'translateX(0)' }], 10.05, .5, 'out');
  A(res, [{ transform: 'translateX(0)' }, { transform: 'translateX(-110px)' }], 10.05, .5, 'out');

  // picker grid
  const all = [['Ant', '🐜', 0], ['Badger', '🦡', 2], ['Bat', '🦇', 1], ['Bear', '🐻', 3], ['Beaver', '🦫', 2], ['Bee', '🐝', 0], ['Bird', '🐦', 0], ['Boar', '🐗', 2], ['Butterfly', '🦋', 1], ['Camel', '🐫', 2], ['Cat', '🐱', 0], ['Chicken', '🐔', 0], ['Cow', '🐄', 1], ['Crab', '🦀', 1], ['Crocodile', '🐊', 3], ['Deer', '🦌', 3], ['Dog', '🐶', 0], ['Dolphin', '🐬', 3], ['Duck', '🦆', 1], ['Eagle', '🦅', 4], ['Elephant', '🐘', 3], ['Fish', '🐟', 0], ['Flamingo', '🦩', 3], ['Fox', '🦊', 2]];
  const tile = ([n, e, r]) => `<div class="tile"><div class="bd" style="box-shadow: inset 0 0 0 1.5px rgba(${TINT_RGB[r]},.35)"></div><div class="selbd"></div>
    <svg class="check" width="16" height="16" viewBox="0 0 16 16"><circle cx="8" cy="8" r="8" fill="#FF7EA6"/><path d="M4.5 8.2l2.3 2.3 4.7-4.7" stroke="#fff" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <div class="e emoji">${e}</div><div class="n">${n}</div></div>`;
  $('#gridAll').innerHTML = all.map(tile).join('');
  $('#gridFox').innerHTML = tile(['Fox', '🦊', 2]);

  tap(195, 118, 10.75);
  const st = $('#searchText');
  hooks.push(t => {
    if (t < 10.8) { st.innerHTML = '<span class="ph">Search animals</span>'; return; }
    const typed = t < 11.15 ? '' : t < 11.35 ? 'f' : t < 11.55 ? 'fo' : 'fox';
    const caretOn = (t > 11.1 && t < 11.7) || Math.floor(t * 2.4) % 2 === 0;
    st.innerHTML = `<span class="typed">${typed}</span><span class="caret" style="opacity:${caretOn ? 1 : 0}"></span>` + (typed ? '' : '<span class="ph" style="margin-left:-3px">Search animals</span>');
  });
  [11.15, 11.35, 11.55].forEach(t => cue(t, 'key'));
  fadeOut($('#gridAll'), 11.35, .18);
  A($('#gridFox'), [{ opacity: 0, transform: 'translateY(6px)' }, { opacity: 1, transform: 'translateY(0)' }], 11.4, .3, 'out');

  const foxTile = $('#gridFox .tile'), ft = pt(foxTile);
  tap(ft.x, ft.y, 12.2);
  press(foxTile, 12.2);
  fadeIn(foxTile.querySelectorAll('.selbd, .check'), 12.25, .15);
  cue(12.5, 'swish');
  A(pk, [{ transform: 'translateX(0)' }, { transform: 'translateX(390px)' }], 12.5, .45, 'out');
  A(res, [{ transform: 'translateX(-110px)' }, { transform: 'translateX(0)' }], 12.5, .45, 'out');

  // --- identified: it's a Fox! ---
  const T = 12.85;
  cue(T, 'reveal');
  const swapAll = sel => document.querySelectorAll(sel).forEach(sw => {
    fadeOut(sw.children[0], T, .2);
    fadeIn(sw.children[1], T + .05, .25);
  });
  swapAll('#result .swap');
  A($('#nameSwap'), [{ transform: 'scale(.7)' }, { transform: 'scale(1)' }], T, .7, 'bouncy');
  A($('#badgeWrap'), [{ height: '0px' }, { height: '26px' }], T + .1, .5, 'spring');
  A($('#photo .badge'), [{ transform: 'scale(.5)' }, { transform: 'scale(1)' }], T, .7, 'bouncy');
  fadeOut($('#ring1'), T, .3); fadeIn($('#ring2'), T, .3);
  fadeOut($('.zchip[data-z="meadow"] .sel'), T + .1, .25);
  fadeIn($('.zchip[data-z="woods"] .sel'), T + .2, .25);
  A(zrow, [{ transform: `translateX(${tMeadow}px)` }, { transform: `translateX(${tWoods}px)` }], T + .1, .5, 'out');
  rain(T, ['🦊', '🦊', '🦊', '✨', '🦊', '🎉', '🦊', '🦊', '⭐️', '🦊', '💫', '🦊'], 34);

  const sn = $('#sparkNum');
  hooks.push(t => { sn.textContent = Math.round(10 + 110 * easeOut((t - (T + .15)) / .75)); });
  A($('#firstFind'), [{ maxWidth: '0px', opacity: 0 }, { maxWidth: '170px', opacity: 1 }], T + .7, .5, 'out');
  cue(T + .8, 'sparkle');

  A($('#resContent'), [{ transform: 'translateY(0)' }, { transform: 'translateY(-72px)' }], 14.05, .7, 'inout');
  A($('#achCard'), [{ maxHeight: '0px', opacity: 0 }, { maxHeight: '90px', opacity: 1 }], 14.3, .7, 'spring');
  A($('#achCard'), [{ transform: 'scale(.8)' }, { transform: 'scale(1)' }], 14.3, .7, 'bouncy');
  cue(14.35, 'achievement');

  // --- Done ---
  const db = $('#doneBtn');
  tap(195, 730, 16.15);
  press(db, 16.15);
  cue(16.35, 'whoosh');
  A(res, [{ transform: 'translateY(0)' }, { transform: 'translateY(844px)' }], 16.35, .55, 'inout');
}

// ============================================================ GROVE
const SCROLL = 300;
const LAYOUT = { // masonry, final heights
  home:   { col: 0, rows: 1 }, pond: { col: 0, rows: 2 }, meadow: { col: 0, rows: 2 }, sky:   { col: 0, rows: 1 },
  garden: { col: 1, rows: 2 }, coast: { col: 1, rows: 1 }, woods: { col: 1, rows: 2 }, wilds: { col: 1, rows: 0 },
};
// [key, emoji, rarity, zone, appearsAt, nickname]
const FRIENDS = [
  ['cat', '🐱', 0, 'home', -9], ['dog', '🐶', 0, 'home', -8],
  ['squirrel', '🐿️', 0, 'garden', -7], ['robin', '🐦', 1, 'garden', -6], ['mouse', '🐭', 0, 'garden', -5.5],
  ['duck', '🦆', 1, 'pond', -5], ['turtle', '🐢', 1, 'pond', -4],
  ['butterfly', '🦋', 1, 'meadow', -3], ['bee', '🐝', 0, 'meadow', -2],
  ['raccoon', '🦝', 1, 'woods', -1.5], ['parrot', '🦜', 2, 'sky', -1],
  ['fox', '🦊', 2, 'woods', 19.25, 'Fox'],
  ['rabbit', '🐰', 1, 'meadow', 22.9, 'Clover the Rabbit'],
  ['frog', '🐸', 2, 'pond', 23.7, 'Sir Ribbit the Frog'],
  ['crab', '🦀', 1, 'coast', 24.5, 'Pinchy the Crab'],
  ['ladybug', '🐞', 0, 'meadow', 25.3, 'Dot the Ladybug'],
  ['owl', '🦉', 3, 'woods', 26.1, 'Professor Hoot'],
  ['eagle', '🦅', 4, 'sky', 27.1, 'Sky Queen the Eagle'],
];
const zoneRect = {};

function buildGrove() {
  const G = $('#grove');
  fadeIn(G, 16.3, .02, 'lin');
  A($('#chIc'), [{ transform: 'scale(.5)' }, { transform: 'scale(1)' }], 16.9, .7, 'bouncy');

  // zone cards
  const colY = [296, 296], colX = [16, 201];
  ZONE_ORDER.forEach(z => {
    const L = LAYOUT[z];
    const h = L.rows === 0 ? 120 : 124 + (L.rows - 1) * 66;
    const x = colX[L.col], y = colY[L.col];
    colY[L.col] += h + 12;
    zoneRect[z] = { x, y, h };
    const card = html(`<div class="zone" data-z="${z}" style="left:${x}px;top:${y}px;height:${h}px;background:${zgrad(z)}">
      <div class="zh"><span><span class="emoji">${ZONES[z].emoji}</span> ${ZONES[z].name}</span><span class="c">0</span></div>
      <div class="quiet">a quiet spot, waiting for its first visitor…</div>
      <div class="slots"></div></div>`);
    $('#zones').appendChild(card);
  });

  const slotXY = i => ({ x: (i % 2) * 76.5 + 6.25, y: 6 + Math.floor(i / 2) * 66 });

  // per-zone residency over time → slot moves
  ZONE_ORDER.forEach(z => {
    const card = $(`.zone[data-z="${z}"]`);
    const members = FRIENDS.filter(f => f[3] === z);
    const times = [...new Set(members.map(f => Math.max(0, f[4])))].sort((a, b) => a - b);
    const orderAt = t => members.filter(f => f[4] <= t || f[4] <= 0)
      .sort((a, b) => a[2] !== b[2] ? b[2] - a[2] : b[4] - a[4]);
    const countEl = card.querySelector('.c');
    hooks.push(t => { countEl.textContent = members.filter(f => f[4] <= t).length; });
    if (members.length && members.every(f => f[4] > 0)) fadeOut(card.querySelector('.quiet'), Math.min(...members.map(f => f[4])) - .1, .2);
    if (members.length) card.querySelector('.quiet').style.display = members.some(f => f[4] <= 0) ? 'none' : '';

    members.forEach((f, idx) => {
      const [key, emoji, rar] = f;
      const appear = f[4];
      const p = html(`<div class="portrait" data-k="${key}"><div class="popw"><div class="bob">
        <div class="pcircle"></div>
        <div class="pphoto" style="background-image:url(${photoSq(key)})"></div>
        <div class="pring" style="border-color:${TINT[rar]}"></div>
        <div class="pcorner emoji" style="box-shadow: 0 0 0 1.5px ${TINT[rar]}99, 0 1px 2px rgba(74,68,88,.15)">${emoji}</div></div></div></div>`);
      card.querySelector('.slots').appendChild(p);
      const bob = p.querySelector('.bob');
      bob.animate([{ transform: 'translateY(3px) rotate(-2.5deg)' }, { transform: 'translateY(-4px) rotate(2.5deg)' }],
        { duration: (2.0 + (idx % 3) * .35) * 1000, delay: -idx * 280, iterations: Infinity, direction: 'alternate', easing: EASE.inout });

      // slot over time
      let prev = null;
      const relevant = times.filter(t => t >= Math.max(0, appear));
      relevant.forEach(t => {
        const i = orderAt(t).indexOf(f);
        const s = slotXY(i);
        const tr = `translate(${s.x}px, ${s.y}px)`;
        if (prev === null) p.style.transform = tr;
        else if (prev !== tr) A(p, [{ transform: prev }, { transform: tr }], t, .55, 'spring');
        prev = tr;
      });
      if (appear > 0) {
        const pw = p.querySelector('.popw');
        pw.style.opacity = 0;
        if (key === 'fox') A(pw, [{ opacity: 1, transform: 'scale(.9)' }, { opacity: 1, transform: 'scale(1)' }], appear, .4, 'bouncy');
        else {
          A(pw, [{ opacity: 1, transform: 'scale(0)' }, { opacity: 1, transform: 'scale(1)' }], appear, .7, 'bouncy');
          cue(appear, rar === 4 ? 'legend' : 'pop');
        }
        const final = slotXY(orderAt(appear).indexOf(f));
        const cx = zoneRect[z].x + 14 + final.x + 28, cy = zoneRect[z].y + 42 + final.y + 28 - SCROLL;
        burst(cx, cy, appear, rar === 4);
        if (key !== 'fox') bubble(cx, cy - 44, appear + .1, `<b>${f[5]}</b> <i>+${BASE_SPARKS[rar] * 2} <span class="emoji">✨</span></i>`, rar);
      }
    });
  });

  hooks.push(t => { $('#friendCount').textContent = FRIENDS.filter(f => f[4] <= t).length; });

  // scroll down to the zones, inline title fades in
  A($('#groveScroll'), [{ transform: 'translateY(0)' }, { transform: `translateY(-${SCROLL}px)` }], 17.3, 1.0, 'inout');
  fadeIn($('#groveNav'), 17.65, .3);

  // the fox flies home from the camera into the Woods
  const w = zoneRect.woods, dest = { x: w.x + 14 + 6.25, y: w.y + 42 + 6 - SCROLL };
  const fly = html(`<div class="portrait" style="left:0;top:0;opacity:0;z-index:9"><div class="pcircle"></div><div class="pphoto" style="background-image:url(${photoSq('fox')})"></div><div class="pring" style="border-color:${TINT[2]}"></div><div class="pcorner emoji">🦊</div></div>`);
  $('#groveFx').appendChild(fly);
  cue(18.4, 'fly');
  A(fly, [
    { opacity: 0, transform: 'translate(167px, 150px) scale(2.6)' },
    { opacity: 1, transform: 'translate(167px, 170px) scale(2.5)', offset: .18 },
    { opacity: 1, transform: `translate(${(167 + dest.x) / 2 + 40}px, 210px) scale(1.7)`, offset: .55 },
    { opacity: 1, transform: `translate(${dest.x}px, ${dest.y}px) scale(1)` },
  ], 18.4, .85, 'cubic-bezier(.45,0,.3,1)');
  A(fly, [{ opacity: 1 }, { opacity: 0 }], 19.27, .05, 'lin');
  cue(19.25, 'land');
  burst(dest.x + 28, dest.y + 28, 19.25, false);
  bubble(dest.x + 28, dest.y - 18, 19.5, `Settled into your <i>Woods</i> <span class="emoji">🌲</span>`, 2, 2.2);
}

function burst(cx, cy, t, big) {
  const b = html(`<div class="burst" style="left:${cx}px;top:${cy}px"></div>`);
  const n = big ? 12 : 8;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + .3, r = big ? 62 : 44;
    const s = html(`<span class="emoji">${big ? (i % 2 ? '⭐' : '✨') : '✨'}</span>`);
    b.appendChild(s);
    A(s, [{ opacity: 1, transform: 'translate(0,0) scale(.4)' }, { opacity: 0, transform: `translate(${Math.cos(a) * r}px, ${Math.sin(a) * r}px) scale(1)` }], t, big ? .9 : .65, 'out');
  }
  $('#groveFx').appendChild(b);
}
function bubble(cx, cy, t, inner, rar, hold = 1.1) {
  const wrap = html(`<div style="position:absolute;left:${cx}px;top:${cy}px;width:0;height:0;z-index:8"></div>`);
  const legend = rar === 4;
  const b = html(`<div class="bubble" style="transform:translate(-50%,-50%); ${legend ? 'background:#FFD98A' : ''}">${legend ? '<span class="emoji">💛</span> Almost mythical! ' : ''}${inner}</div>`);
  wrap.appendChild(b);
  $('#groveFx').appendChild(wrap);
  // keep the bubble on-screen
  const half = b.offsetWidth / 2;
  const shift = Math.max(0, half + 10 - cx) - Math.max(0, cx + half + 10 - 390);
  A(b, [{ opacity: 0, transform: `translate(calc(-50% + ${shift}px), -30%) scale(.7)` }, { opacity: 1, transform: `translate(calc(-50% + ${shift}px), -50%) scale(1)` }], t, .4, 'bouncy');
  A(b, [{ opacity: 1, transform: `translate(calc(-50% + ${shift}px), -50%) scale(1)` }, { opacity: 0, transform: `translate(calc(-50% + ${shift}px), -140%) scale(1)` }], t + hold, .4, 'in');
}

// ============================================================ TAB BAR
function buildTabBar() {
  const icons = {
    grove: '<path d="M16 2C8 2 3 7 3 13c0 2 .5 3.5 1.3 4.7L2 20l1.4 1.4 2.4-2.4C7 19.7 8.6 20 10 20c6 0 10-5 10-13V2z" fill="currentColor"/><path d="M5 18L13 10" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>',
    map: '<path d="M1 4.5l6-2.5 8 3 6-2.5v15.5l-6 2.5-8-3-6 2.5z" fill="currentColor"/><path d="M7 2v15.5M15 5v15.5" stroke="#fff" stroke-width="1.4"/>',
    journal: '<path d="M4 2h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H4z" fill="currentColor"/><path d="M7 2v18" stroke="#fff" stroke-width="1.5"/>',
    profile: '<circle cx="11" cy="11" r="10" fill="currentColor"/><circle cx="11" cy="8.5" r="3.6" fill="#fff"/><path d="M4.5 17.2c1.6-2.4 3.8-3.4 6.5-3.4s4.9 1 6.5 3.4" stroke="#fff" stroke-width="2.2" fill="none"/>',
  };
  const tabs = [['grove', 'Grove', 14.25], ['map', 'Map', 78.75], ['journal', 'Journal', 215.25], ['profile', 'Profile', 279.75]];
  const bar = $('#tabbar');
  tabs.forEach(([k, label, x]) => {
    const inner = `<svg width="22" height="22" viewBox="0 0 22 22">${icons[k]}</svg><span>${label}</span>`;
    bar.appendChild(html(`<div class="tab" data-k="${k}" style="left:${x}px">${inner}<div class="on">${inner}</div></div>`));
  });
  bar.appendChild(html(`<div id="catchBtn"><svg width="26" height="22" viewBox="0 0 24 20"><path d="M8 1h8l2 3h3a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h3z" fill="#fff"/><circle cx="12" cy="11" r="4.2" fill="#FF7EA6"/></svg></div>`));
  A(bar, [{ transform: 'translateY(140px)' }, { transform: 'translateY(0)' }], 16.55, .7, 'soft');
  const on = k => $(`.tab[data-k="${k}"] .on`);
  on('grove').style.opacity = 1;
  const switchTo = (from, to, t) => { fadeOut(on(from), t, .2); fadeIn(on(to), t, .2); };
  tap(78.75 + 16 + 32, 782, 28.25); switchTo('grove', 'map', 28.3);
  tap(215.25 + 16 + 32, 782, 32.85); switchTo('map', 'journal', 32.9);
}

// ============================================================ MAP
const PINS = [ // x, y, emoji, rarity
  [150, 362, '🦊', 2], [96, 300, '🦉', 3], [204, 318, '🦝', 1], [262, 520, '🦆', 1], [318, 470, '🐸', 2],
  [70, 560, '🐢', 1], [300, 640, '🦀', 1], [205, 600, '🐰', 1], [120, 670, '🐞', 0], [330, 250, '🦜', 2],
  [262, 196, '🦅', 4], [60, 420, '🐱', 0], [176, 470, '🐶', 0], [330, 360, '🐿️', 0], [42, 690, '🐦', 1],
  [246, 700, '🦋', 1], [140, 210, '🐝', 0], [200, 420, '🐭', 0],
];
function buildMap() {
  const M = $('#map');
  fadeIn(M, 28.3, .25);
  cue(28.3, 'swish');
  $('#mapSvg').innerHTML = `
    <rect width="390" height="844" fill="#EFEADB"/>
    <path d="M-20 160 C 80 230, 60 330, 150 420 S 300 420, 410 330 L 410 -10 L -20 -10Z" fill="#E8E2CF"/>
    <ellipse cx="135" cy="345" rx="125" ry="95" fill="#CBE6BA" transform="rotate(-12 135 345)"/>
    <ellipse cx="120" cy="330" rx="40" ry="26" fill="#BFDDAA"/>
    <ellipse cx="300" cy="640" rx="90" ry="60" fill="#D3EAC2"/>
    <path d="M-30 520 C 60 470, 140 560, 230 520 S 360 420, 420 450" stroke="#B5DBF2" stroke-width="44" fill="none" stroke-linecap="round"/>
    <ellipse cx="320" cy="250" rx="45" ry="28" fill="#B5DBF2"/>
    <g stroke="#fff" stroke-linecap="round" fill="none">
      <path d="M-10 230 L 400 150" stroke-width="12"/>
      <path d="M260 -10 L 230 860" stroke-width="12"/>
      <path d="M-10 620 L 400 760" stroke-width="12"/>
      <path d="M40 -10 L 20 860" stroke-width="6"/>
      <path d="M-10 420 C 120 440, 260 400, 400 400" stroke-width="6"/>
      <path d="M150 600 L 160 860" stroke-width="6"/>
      <path d="M340 160 L 350 860" stroke-width="6"/>
      <path d="M-10 740 L 240 690" stroke-width="6"/>
    </g>
    <path d="M60 250 C 110 300, 150 280, 200 340" stroke="#E9DDB8" stroke-width="3" stroke-dasharray="4 5" fill="none"/>
    <text x="22" y="418" font-family="Nunito" font-weight="800" font-size="12" fill="#6B9A5B">Elm Park</text>
    <text x="96" y="540" font-family="Nunito" font-weight="800" font-size="11" fill="#5A8FB5" transform="rotate(-6 96 540)">Willow Creek</text>
    <text x="272" y="690" font-family="Nunito" font-weight="800" font-size="11" fill="#6B9A5B">Meadow Commons</text>`;
  const order = PINS.map((p, i) => i).sort((a, b) => PINS[a][1] - PINS[b][1]);
  order.forEach((i, k) => {
    const [x, y, e, r] = PINS[i];
    const pin = html(`<div class="pin" style="left:${x}px;top:${y}px"><div class="tail"></div><div class="head" style="background:${TINT[r]}"><span class="emoji">${e}</span></div></div>`);
    $('#pins').appendChild(pin);
    const t = 28.8 + k * .11;
    A(pin, [{ opacity: 0, transform: 'translateY(-70px) scale(.8)' }, { opacity: 1, transform: 'translateY(0) scale(1)' }], t, .55, 'bouncy');
    if (k % 2 === 0) cue(t + .2, 'drop');
  });
  hooks.push(t => { $('#pinCount').textContent = Math.max(0, Math.min(18, Math.floor((t - 28.8) / .11) + 1)); });

  const fx = PINS[0];
  tap(fx[0], fx[1] - 26, 30.95);
  const co = html(`<div class="callout softcard" style="left:0;top:${fx[1] - 124}px">
    <span class="e emoji">🦊</span><div><div class="t">Fox</div><div class="s"><span class="emoji">💜</span> Seldom seen · Elm Park · Today</div></div></div>`);
  $('#pins').appendChild(co);
  co.style.left = Math.max(12, fx[0] - co.offsetWidth / 2) + 'px';
  A(co, [{ opacity: 0, transform: 'translateY(10px) scale(.85)' }, { opacity: 1, transform: 'translateY(0) scale(1)' }], 31.05, .5, 'bouncy');
  cue(31.05, 'pop');
}

// ============================================================ JOURNAL
function buildJournal() {
  fadeIn($('#journal'), 32.9, .25);
  cue(32.9, 'swish');
  ['#j1', '#j2', '#j3', '#j4'].forEach((s, i) =>
    A($(s), [{ opacity: 0, transform: 'translateY(24px)' }, { opacity: 1, transform: 'translateY(0)' }], 33.0 + i * .12, .6, 'soft'));
  A($('#fgBar'), [{ width: '0%' }, { width: '26.5%' }], 33.4, .9, 'out');
  A($('#lvBar'), [{ width: '0%' }, { width: '64%' }], 33.7, 1.3, 'out');
  hooks.push(t => { $('#totalSparks').textContent = Math.round(1670 * easeOut((t - 33.5) / 1.5)).toLocaleString('en-US'); });
  hooks.push(t => { $('#streakNum').textContent = t < 34.7 ? 11 : 12; });
  A($('#flame'), [{ transform: 'scale(1)' }, { transform: 'scale(1.45) rotate(-8deg)' }], 34.5, .2, 'out');
  A($('#flame'), [{ transform: 'scale(1.45) rotate(-8deg)' }, { transform: 'scale(1) rotate(0)' }], 34.7, .7, 'bouncy');
  A($('#streakNum'), [{ transform: 'scale(1)' }, { transform: 'scale(1)' }], 0, 1);
  cue(34.7, 'streak');

  const rows = [[0, 6, 14], [1, 7, 15], [2, 3, 15], [3, 1, 20], [4, 1, 4]];
  rows.forEach(([r, have, total], i) => {
    const row = html(`<div class="rrow"><span class="emoji">${HEART[r]}</span><span>${FIELD[r]}</span><div class="bar"><div style="background:${TINT[r]}"></div></div><span class="cnt">${have}/${total}</span></div>`);
    $('#rrows').appendChild(row);
    A(row.querySelector('.bar > div'), [{ width: '0%' }, { width: `${(have / total) * 100}%` }], 33.9 + i * .1, .8, 'out');
  });
}

// ============================================================ OUTRO
function buildOutro() {
  const [icon, word, tag, chips, foot, credits] = $('#outro').children;
  A(icon, [{ opacity: 0, transform: 'scale(.4) rotate(-10deg)' }, { opacity: 1, transform: 'scale(1) rotate(0)' }], 39.0, 1.0, 'spring');
  cue(39.0, 'pop');
  A(word, [{ opacity: 0, transform: 'translateY(40px)' }, { opacity: 1, transform: 'translateY(0)' }], 39.35, .7, 'soft');
  A(tag, [{ opacity: 0, transform: 'translateY(30px)' }, { opacity: 1, transform: 'translateY(0)' }], 39.7, .7, 'soft');
  chips.style.opacity = 1;
  A(chips, [{ opacity: 0 }, { opacity: 1 }], 0, .01);
  Array.from(chips.children).filter(c => getComputedStyle(c).display !== 'none').forEach((c, i) => {
    A(c, [{ opacity: 0, transform: 'translateY(26px) scale(.9)' }, { opacity: 1, transform: 'translateY(0) scale(1)' }], 40.3 + i * .3, .6, 'bouncy');
    cue(40.3 + i * .3, 'tick');
  });
  A(foot, [{ opacity: 0, transform: 'translateY(26px) scale(.9)' }, { opacity: 1, transform: 'translateY(0) scale(1)' }], 41.3, .7, 'bouncy');
  cue(41.3, 'pop');
  A(credits, [{ opacity: 0 }, { opacity: 1 }], 42.0, .8, 'out');
}

// ============================================================ seek
window.seek = t => {
  for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; }
  hooks.forEach(h => h(t));
  return Promise.all(pending.splice(0));
};

// ============================================================ 15-second cut
// Six hard-cut segments of the master timeline, [masterStart, masterEnd], with
// their own captions (#s0–#s4). The background keeps running on short-cut time
// so nothing behind the phone jumps at the cuts.
const SEGMENTS = [[4.9, 8.6], [12.8, 15.6], [18.3, 20.2], [25.6, 27.6], [29.6, 31.2], [40.4, 43.4]];  // the sparks shot runs long enough to read "2× first find!"
const SHORT_DURATION = SEGMENTS.reduce((d, [a, b]) => d + b - a, 0);
function shortToMaster(t) {
  let acc = 0;
  for (const [a, b] of SEGMENTS) { if (t < acc + (b - a) || b === SEGMENTS.at(-1)[1]) return Math.min(b, a + t - acc); acc += b - a; }
}
function shortCaptions(t) {
  let acc = 0;
  SEGMENTS.slice(0, 5).forEach(([a, b], i) => {
    const t0 = acc, t1 = acc + (b - a), el = $('#s' + i);
    const inP = i === 0 ? 1 : easeOut((t - t0) / .35), outP = i === 4 ? Math.min(1, Math.max(0, (t - t1 + .25) / .25)) : (t >= t1 ? 1 : 0);
    const on = t >= t0 && t < t1 + (i === 4 ? 0 : 0);
    el.style.opacity = on ? Math.max(0, inP - outP) : 0;
    el.style.transform = `translateY(${(1 - inP) * 24}px)`;
    acc = t1;
  });
}
window.seekShort = t => {
  const done = window.seek(shortToMaster(t));
  floatAnims.forEach(a => { a.currentTime = t * 1000; });
  shortCaptions(t);
  return done;
};
window.SHORT = { duration: SHORT_DURATION, segments: SEGMENTS };
window.DURATION = DURATION;
window.CUES = CUES;

document.fonts.load('900 20px Nunito').then(() => document.fonts.ready).then(() => {
  build();
  window.seek(0);
  window.READY = true;
});
