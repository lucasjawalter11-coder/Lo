// Dev helper: render a scene dump to PNG files with headless Chromium.
// Usage: node tools/preview/shot.mjs --scene build/scene.json --out <dir> [--size 1280x720] [--sky dusk|night]
//          --shots "name:px,py,pz:lx,ly,lz[:fov] ; name2:..."
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const args = {};
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, '')] = argv[i + 1];
const [W, H] = (args.size || '1280x720').split('x').map(Number);
const outDir = path.resolve(args.out || 'build/shots');
fs.mkdirSync(outDir, { recursive: true });

const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!file.startsWith(root)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404).end('not found'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'] });
const page = await (await browser.newContext({ viewport: { width: W, height: H } })).newPage();
page.on('pageerror', (e) => console.log('[pageerror]', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.log('[console]', m.text()); });
const scenePath = '/' + path.relative(root, path.resolve(args.scene || 'build/scene.json')).split(path.sep).join('/');
await page.goto(`http://localhost:${port}/tools/preview/viewer.html?scene=${encodeURIComponent(scenePath)}&sky=${args.sky || 'dusk'}&fog=${args.fog || 600}&fogfar=${args.fogfar || 3200}`);
await page.waitForFunction('window.ready === true', null, { timeout: 120000 });
console.log('parts:', await page.evaluate('window.partCount'));

for (const spec of String(args.shots || 'default:0,120,220:0,0,0').split(';').map((s) => s.trim()).filter(Boolean)) {
  const [name, pos, look, fov] = spec.split(':');
  await page.evaluate((cam) => window.shoot(cam), { pos: pos.split(',').map(Number), look: look.split(',').map(Number), fov: fov ? Number(fov) : 60 });
  const file = path.join(outDir, `${name}.png`);
  await page.screenshot({ path: file });
  console.log('wrote', file);
}
await browser.close();
server.close();
