// Lints every Luau file in src/ with the Luau analyzer (nonstrict + lint), knowing Roblox's globals.
// Usage: node tools/lune/lint.mjs   (needs @luau-rs/luau: npm install --prefix tools/lune @luau-rs/luau)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const { Analysis } = await import(pathToFileURL(path.join(here, 'node_modules/@luau-rs/luau/dist/analysis.js')).href);

const GLOBALS = ['game', 'workspace', 'script', 'Instance', 'Enum', 'Vector3', 'Vector2', 'CFrame', 'Color3', 'UDim', 'UDim2',
  'TweenInfo', 'NumberRange', 'NumberSequence', 'NumberSequenceKeypoint', 'ColorSequence', 'ColorSequenceKeypoint', 'BrickColor',
  'Rect', 'Ray', 'RaycastParams', 'OverlapParams', 'Random', 'DateTime', 'Font', 'PhysicalProperties', 'task', 'tick', 'time',
  'warn', 'typeof', 'shared', 'utf8', 'buffer', 'vector', 'Axes', 'Faces', 'Region3'];

const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p); else if (p.endsWith('.luau')) files.push(p);
  }
})(path.join(root, 'src'));

const a = await Analysis.create({ mode: 'nocheck', lint: true, globals: GLOBALS });
let problems = 0;
for (const f of files) {
  const name = path.relative(root, f);
  a.setModule(name, fs.readFileSync(f, 'utf8').replace(/^--!nonstrict/, '--!nocheck'), 'script');
  for (const d of a.check(name).diagnostics) {
    if (d.code === 'LocalUnused' && /'_/.test(d.message)) continue;
    problems++;
    console.log(`${name}:${d.location.begin.line + 1}:${d.location.begin.column + 1} ${d.code}: ${d.message}`);
  }
}
console.log(`${files.length} files, ${problems} problems`);
process.exit(problems ? 1 : 0);
