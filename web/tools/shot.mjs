// Dev helper: load the game in headless Chromium and capture screenshots.
// Usage: node tools/shot.mjs --out shot.png [--url /index.html] [--size 1280x720] [--wait 1500] [--eval "code"] [--shots n --gap ms]
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require('/opt/node-tools/node_modules/playwright')); }

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = Object.fromEntries(process.argv.slice(2).join(' ').split('--').filter(Boolean).map((s) => {
  const i = s.indexOf(' '); return i < 0 ? [s.trim(), true] : [s.slice(0, i), s.slice(i + 1).trim()];
}));
const [W, H] = (args.size || '1280x720').split('x').map(Number);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };

const server = http.createServer((req, res) => {
  let file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404).end('nf'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }); res.end(data);
  });
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'] });
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: Number(args.dpr || 1), hasTouch: !!args.touch, isMobile: !!args.touch });
const page = await ctx.newPage();
page.on('console', (m) => { const t = m.text(); if (!/GPU stall|GL Driver Message/.test(t)) console.log(`[${m.type()}]`, t); });
page.on('pageerror', (e) => console.log('[pageerror]', e.stack || e.message));
// The sandbox cannot reach the CDN: serve the engine from node_modules instead.
await page.route('https://cdn.jsdelivr.net/npm/three@0.170.0/**', (route) => {
  const rel = new URL(route.request().url()).pathname.replace('/npm/three@0.170.0/', '');
  route.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(path.join(root, 'node_modules/three', rel)) });
});
await page.route(/fonts\.(googleapis|gstatic)\.com/, (route) => route.abort());

await page.goto(`http://localhost:${port}${args.url || '/index.html'}`);
await page.waitForFunction(() => window.__game && window.__game.ready, null, { timeout: 60000 }).catch((e) => console.log('ready wait failed', e.message));
if (args.eval) { const r = await page.evaluate(args.eval); if (r !== undefined) console.log('eval ->', JSON.stringify(r)); }
await page.waitForTimeout(Number(args.wait || 1200));
const n = Number(args.shots || 1);
const out = args.out || 'shot.png';
for (let i = 0; i < n; i++) {
  if (args.each) await page.evaluate(`(function(i){ ${args.each} })(${i})`);
  if (args.gap) await page.waitForTimeout(Number(args.gap));
  await page.screenshot({ path: n > 1 ? out.replace(/\.png$/, `-${i}.png`) : out });
}
if (args.after) { const r = await page.evaluate(args.after); console.log('after ->', JSON.stringify(r)); }
await browser.close();
server.close();
