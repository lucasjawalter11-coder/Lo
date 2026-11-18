// Dev helper: screenshot a dumped menu. Usage: node tools/preview/gui-shot.mjs <gui.json> <out.png> [viewport-image.png]
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const [guiJson, out, img] = process.argv.slice(2);
const data = JSON.parse(fs.readFileSync(guiJson, 'utf8'));
const types = { '.html': 'text/html', '.json': 'application/json', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const file = url.startsWith('/@abs/') ? url.slice(5) : path.join(root, url);
  fs.readFile(file, (err, d) => { if (err) { res.writeHead(404).end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }); res.end(d); });
});
await new Promise((r) => server.listen(0, r));
const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: data.w, height: data.h } })).newPage();
const rel = (p) => '/@abs' + path.resolve(p);
await page.goto(`http://localhost:${server.address().port}/tools/preview/gui.html?gui=${encodeURIComponent(rel(guiJson))}${img ? '&img=' + encodeURIComponent(rel(img)) : ''}`);
await page.waitForFunction('window.ready === true', null, { timeout: 30000 });
await page.screenshot({ path: out });
await browser.close(); server.close();
console.log('wrote', out);
