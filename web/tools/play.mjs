// Dev helper: drive the game headlessly by stepping simulated time, capturing screenshots along the way.
// Usage: node tools/play.mjs --url "/index.html?demo=duel" --out dir/prefix --script "step:4;shot;key:KeyJ;step:0.3;shot"
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require('/opt/node-tools/node_modules/playwright')); }
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = Object.fromEntries(process.argv.slice(2).join(' ').split(' --').map((s) => s.replace(/^--/, '')).filter(Boolean).map((s) => { const i = s.indexOf(' '); return i < 0 ? [s.trim(), true] : [s.slice(0, i), s.slice(i + 1).trim()]; }));
const [W, H] = (args.size || '1280x720').split('x').map(Number);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  let file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  fs.readFile(file, (err, data) => { if (err) { res.writeHead(404).end('nf'); return; } res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }); res.end(data); });
});
await new Promise((r) => server.listen(0, r));
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, hasTouch: !!args.touch, isMobile: !!args.touch });
const page = await ctx.newPage();
const errors = [];
page.on('console', (m) => { const t = m.text(); if (m.type() === 'error' || m.type() === 'warning') { if (!/GPU stall|fonts\.g|ERR_FAILED|net::/.test(t)) { errors.push(t); console.log(`[${m.type()}]`, t.slice(0, 600)); } } else if (args.verbose) console.log('[log]', t); });
page.on('pageerror', (e) => { errors.push(e.message); console.log('[pageerror]', (e.stack || e.message).slice(0, 900)); });
await page.route('https://cdn.jsdelivr.net/npm/three@0.170.0/**', (route) => {
  const rel = new URL(route.request().url()).pathname.replace('/npm/three@0.170.0/', '');
  route.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(path.join(root, 'node_modules/three', rel)) });
});
await page.route(/fonts\.(googleapis|gstatic)\.com/, (route) => route.abort());
await page.goto(`http://localhost:${server.address().port}${args.url || '/index.html'}`);
await page.waitForFunction(() => window.__game && window.__game.ready, null, { timeout: 90000 }).catch((e) => console.log('ready wait failed:', e.message.split('\n')[0]));
await page.evaluate(() => { if (window.__game) window.__game.manual = true; });
let shot = 0;
const out = args.out || 'play';
for (const cmd of String(args.script || 'shot').split(' | ').map((s) => s.trim()).filter(Boolean)) {
  const [op, ...rest] = cmd.split(':'); const arg = rest.join(':');
  if (op === 'step') {
    await page.evaluate(async (sec) => { const g = window.__game; const n = Math.ceil(sec / 0.0333); for (let i = 0; i < n; i++) { g.step(0.0333); await new Promise((r) => setTimeout(r, 0)); } }, Number(arg));
  } else if (op === 'shot') { await page.evaluate(() => window.__game.draw(0)); await page.screenshot({ path: `${out}-${arg || shot}.png`, timeout: 60000 }).catch((e) => console.log('SHOT FAILED', arg, e.message.split('\n')[0])); shot++; }
  else if (op === 'key') await page.keyboard.press(arg);
  else if (op === 'down') await page.keyboard.down(arg);
  else if (op === 'up') await page.keyboard.up(arg);
  else if (op === 'click') await page.click(arg).catch((e) => console.log('click failed', arg, e.message.split('\n')[0]));
  else if (op === 'eval') { const r = await page.evaluate(arg).catch((e) => `EVAL ERROR ${e.message}`); if (r !== undefined) console.log('eval ->', JSON.stringify(r)); }
  else if (op === 'wait') await page.waitForTimeout(Number(arg));
}
console.log(errors.length ? `${errors.length} error(s)` : 'no errors');
await browser.close(); server.close();
