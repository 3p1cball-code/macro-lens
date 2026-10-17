// Frame-genaues Rendern des Store-Videos (Headless-Brave via playwright-core).
//
//   node render.mjs de            -> out/frames_de/f00000.png … + out/plan_de.json
//   node render.mjs de --shots 3.2,12,20   -> nur Einzelbilder nach out/shot_de_<t>.png
//   node render.mjs de --plan     -> nur Audio-Plan
//
// Optionen: --fps 30  --from 0  --to <s>  --browser /usr/bin/brave-browser
import { chromium } from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..');           // Projektwurzel (fuer assets/fonts)
const args = process.argv.slice(2);
const lang = args[0] || 'de';
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const has = k => args.includes('--' + k);
const FPS = parseFloat(opt('fps', '30'));

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.ttf': 'font/ttf', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = path.join(ROOT, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const browser = await chromium.launch({ executablePath: opt('browser', '/usr/bin/brave-browser'), args: ['--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none'] });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
page.on('pageerror', e => { console.error('PAGE ERROR', e.message); });
await page.goto(`http://127.0.0.1:${port}/store/video/index.html?auto=0&lang=${lang}`);
const dur = await page.evaluate(l => window.init(l), lang);
const outDir = path.join(HERE, 'out');
fs.mkdirSync(outDir, { recursive: true });
const plan = await page.evaluate(() => window.plan());
fs.writeFileSync(path.join(outDir, `plan_${lang}.json`), JSON.stringify(plan, null, 1));
console.log(`${lang}: ${dur.toFixed(2)} s`);

const stage = await page.$('#stage');
if (has('shots')) {
  const fn = has('raw') ? 'renderRaw' : 'render';
  for (const t of opt('shots', '0').split(',').map(Number)) {
    await page.evaluate(([fn, t]) => window[fn](t), [fn, t]);
    await stage.screenshot({ path: path.join(outDir, `shot_${lang}_${t.toFixed(2)}.png`) });
  }
} else if (!has('plan')) {
  const dir = path.join(outDir, `frames_${lang}`);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  const from = Math.round(parseFloat(opt('from', '0')) * FPS);
  const to = Math.round(parseFloat(opt('to', String(dur))) * FPS);
  const t0 = Date.now();
  for (let f = from; f < to; f++) {
    await page.evaluate(t => window.render(t), f / FPS);
    await stage.screenshot({ path: path.join(dir, `f${String(f - from).padStart(5, '0')}.png`) });
    if (f % 150 === 0) console.log(`  frame ${f}/${to}  ${((Date.now() - t0) / 1000).toFixed(0)} s`);
  }
}
await browser.close();
server.close();
