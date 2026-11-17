// Bundle the game into single-file pages:
//   dist/index.html       page content only (title, styles, markup, inline script) for hosts that supply their own <html> shell
//   dist/standalone.html  the same game as one complete HTML document you can open or host anywhere
import { build } from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'dist');

const result = await build({
  entryPoints: [path.join(root, 'src/main.js')],
  bundle: true, format: 'esm', minify: true, write: false, target: 'es2020', legalComments: 'none',
  external: ['https://*'],          // the engine stays on the CDN
});
const js = result.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');

const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const inline = `<script type="module">${js}</script>`;
const tag = '<script type="module" src="./src/main.js"></script>';
if (!html.includes(tag)) throw new Error('index.html no longer contains the module script tag the build expects');

const head = html.match(/<head>([\s\S]*?)<\/head>/)[1].split('\n').filter((l) => !/charset=|name="viewport"/.test(l)).join('\n').trim();
const body = html.match(/<body[^>]*>([\s\S]*?)<\/body>/)[1].replace(tag, () => inline).trim();

fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'index.html'), `${head}\n${body}\n`);
fs.writeFileSync(path.join(out, 'standalone.html'), html.replace(tag, () => inline));
const kb = (f) => `${(fs.statSync(path.join(out, f)).size / 1024).toFixed(0)} KB`;
console.log(`dist/index.html ${kb('index.html')}, dist/standalone.html ${kb('standalone.html')}`);
