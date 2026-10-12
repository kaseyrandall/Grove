// Renders index.html to video frames with headless Chromium, piping JPEGs into ffmpeg.
//   node render.mjs                 → grove-demo-silent.mp4 + cues.json
//   node render.mjs --still 12.5 a.png [20 b.png …]  → single preview frames
//   add --landscape for the 16:9 cut           → grove-demo-16x9-silent.mp4
import { chromium } from 'playwright';
import { writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const FPS = 30;
const LANDSCAPE = process.argv.includes('--landscape');      // 16:9 cut (1920×1080)
const args = process.argv.slice(2).filter(a => a !== '--landscape');
const [W, H] = LANDSCAPE ? [1920, 1080] : [1080, 1920];

// one JPEG per video frame of the viewfinder footage (regenerated, not committed)
const framesDir = path.join(here, 'assets', '.frames');
if (!existsSync(path.join(framesDir, 'f120.jpg'))) {
  mkdirSync(framesDir, { recursive: true });
  execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-i', path.join(here, 'assets', 'fox-clip.mp4'), '-q:v', '2', path.join(framesDir, 'f%03d.jpg')]);
}

const browser = await chromium.launch({ args: ['--font-render-hinting=none', '--disable-lcd-text'] });
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
page.on('pageerror', e => console.error('PAGE ERROR', e.message));
page.on('console', m => { if (m.type() === 'error') console.error('console:', m.text()); });
await page.goto('file://' + path.join(here, 'index.html') + (LANDSCAPE ? '?landscape' : ''));
await page.waitForFunction(() => window.READY === true, null, { timeout: 30000 });
await page.waitForLoadState('load');
await page.evaluate(() => Promise.all(Array.from(document.images).map(i => i.decode().catch(() => {}))));

if (args[0] === '--still') {
  // pairs: time file
  for (let i = 1; i < args.length; i += 2) {
    await page.evaluate(t => window.seek(t), Number(args[i]));
    await page.screenshot({ path: args[i + 1] });
    console.log('wrote', args[i + 1]);
  }
  await browser.close();
  process.exit(0);
}

const duration = await page.evaluate(() => window.DURATION);
writeFileSync(path.join(here, 'cues.json'), JSON.stringify(await page.evaluate(() => window.CUES), null, 1));

const out = path.join(here, LANDSCAPE ? 'grove-demo-16x9-silent.mp4' : 'grove-demo-silent.mp4');
const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
  '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });

const frames = Math.round(duration * FPS);
const t0 = Date.now();
for (let f = 0; f < frames; f++) {
  await page.evaluate(t => window.seek(t), f / FPS);
  const buf = await page.screenshot({ type: 'jpeg', quality: 95 });
  if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  if (f % 90 === 0) console.log(`frame ${f}/${frames}  (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
await browser.close();
console.log('wrote', out);
