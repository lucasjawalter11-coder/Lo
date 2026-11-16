// Procedural 3D duelists: a jointed body, painted face, sculpted hair, academy outfit and Lumen weapon.
import * as THREE from './three.js';

export const JOINTS = [
  'hips', 'spine', 'chest', 'neck', 'head',
  'armL', 'elbowL', 'handL', 'armR', 'elbowR', 'handR',
  'legL', 'kneeL', 'footL', 'legR', 'kneeR', 'footR',
];

const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const hex = (c) => new THREE.Color(c);

// ------------------------------------------------------------ materials
function patchCharacterMaterial(mat, fx) {
  mat.onBeforeCompile = (shader) => {
    shader.uniforms.uRimColor = fx.rimColor;
    shader.uniforms.uRimPower = fx.rimPower;
    shader.uniforms.uFlash = fx.flash;
    shader.uniforms.uFlashColor = fx.flashColor;
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform vec3 uRimColor;\nuniform float uRimPower;\nuniform float uFlash;\nuniform vec3 uFlashColor;')
      .replace('#include <opaque_fragment>', `
{
  float rimF = pow(1.0 - saturate(dot(normalize(vViewPosition), normal)), 2.4);
  outgoingLight += uRimColor * rimF * uRimPower;
  outgoingLight = mix(outgoingLight, uFlashColor, uFlash);
}
#include <opaque_fragment>`);
  };
  mat.customProgramCacheKey = () => 'duelist';
  return mat;
}

function makeFaceTexture(L) {
  const K = 2, w = 1024, h = 512;                     // authored in a 1024 x 512 space, drawn at 2x
  const c = document.createElement('canvas'); c.width = w * K; c.height = h * K;
  const x = c.getContext('2d');
  x.scale(K, K);
  const css = (col, a = 1) => { const o = col.clone().convertLinearToSRGB(); return `rgba(${Math.round(o.r * 255)},${Math.round(o.g * 255)},${Math.round(o.b * 255)},${a})`; };
  const skin = hex(L.skin), hair = hex(L.hair);
  x.fillStyle = css(skin); x.fillRect(0, 0, w, h);
  const cx = w / 2, cy = 272;
  let g = x.createLinearGradient(0, 380, 0, 512);       // jaw + neck shadow
  g.addColorStop(0, 'rgba(110,40,50,0)'); g.addColorStop(1, 'rgba(110,40,50,0.4)');
  x.fillStyle = g; x.fillRect(0, 380, w, 132);
  for (const d of [-1, 1]) {                            // blush
    g = x.createRadialGradient(cx + d * 76, cy + 52, 2, cx + d * 76, cy + 52, 36);
    g.addColorStop(0, `rgba(255,80,90,${L.blush ?? 0.2})`); g.addColorStop(1, 'rgba(255,80,90,0)');
    x.fillStyle = g; x.fillRect(cx + d * 76 - 40, cy + 12, 80, 80);
  }
  const eye = hex(L.eye), brow = hair.clone().multiplyScalar(0.3);
  const lash = '#17111c';
  const ew = L.fem ? 35 : 33, eh = L.fem ? 34 : 25, ex0 = L.fem ? 60 : 62;
  for (const d of [-1, 1]) {
    const ex = cx + d * ex0, ey = cy;
    x.save();
    x.beginPath(); x.ellipse(ex, ey, ew, eh, 0, 0, Math.PI * 2); x.clip();
    x.fillStyle = '#f8f5f6'; x.fillRect(ex - 60, ey - 60, 120, 120);
    g = x.createLinearGradient(0, ey - eh, 0, ey - eh * 0.1);        // lid shadow
    g.addColorStop(0, 'rgba(40,30,70,0.6)'); g.addColorStop(1, 'rgba(40,30,70,0)');
    x.fillStyle = g; x.fillRect(ex - 60, ey - eh, 120, eh);
    const ix = ex - d * 3, ir = eh * 0.98, iw = Math.min(ew * 0.72, ir * 0.9);
    g = x.createLinearGradient(0, ey - ir, 0, ey + ir);
    g.addColorStop(0, css(eye.clone().multiplyScalar(0.12)));
    g.addColorStop(0.5, css(eye.clone().multiplyScalar(0.8)));
    g.addColorStop(1, css(eye.clone().lerp(hex(0xffffff), 0.6)));
    x.fillStyle = g; x.beginPath(); x.ellipse(ix, ey + 1, iw, ir, 0, 0, Math.PI * 2); x.fill();
    x.strokeStyle = css(eye.clone().multiplyScalar(0.08)); x.lineWidth = 3; x.stroke();
    x.fillStyle = '#0a0610'; x.beginPath(); x.ellipse(ix, ey + 2, iw * 0.42, ir * 0.5, 0, 0, Math.PI * 2); x.fill();
    g = x.createRadialGradient(ix, ey + ir * 0.7, 1, ix, ey + ir * 0.7, iw);   // glow at the bottom of the iris
    g.addColorStop(0, css(eye.clone().lerp(hex(0xffffff), 0.75), 0.9)); g.addColorStop(1, css(eye, 0));
    x.fillStyle = g; x.beginPath(); x.ellipse(ix, ey + 1, iw, ir, 0, 0, Math.PI * 2); x.fill();
    x.fillStyle = '#ffffff';
    x.beginPath(); x.ellipse(ix - 8, ey - ir * 0.42, 7.5, 9, -0.3, 0, Math.PI * 2); x.fill();
    x.beginPath(); x.arc(ix + 8, ey + ir * 0.42, 3.4, 0, Math.PI * 2); x.fill();
    x.restore();
    x.strokeStyle = lash; x.lineCap = 'round'; x.lineJoin = 'round'; x.lineWidth = L.fem ? 8.5 : 7.5;   // upper lash
    x.beginPath();
    x.moveTo(ex - d * (ew + 2), ey + 3);
    x.quadraticCurveTo(ex - d * ew * 0.3, ey - eh - 10, ex + d * (ew + 4), ey - eh * 0.3);
    x.stroke();
    if (L.fem) { x.lineWidth = 4.5; x.beginPath(); x.moveTo(ex + d * (ew + 3), ey - eh * 0.34); x.lineTo(ex + d * (ew + 14), ey - eh * 0.72); x.stroke(); }
    x.lineWidth = 2.4; x.strokeStyle = 'rgba(60,30,40,0.6)';
    x.beginPath(); x.moveTo(ex - d * ew * 0.7, ey + eh - 1); x.quadraticCurveTo(ex, ey + eh + 4, ex + d * ew * 0.85, ey + eh - 5); x.stroke();
    x.strokeStyle = css(brow); x.lineWidth = L.fem ? 5 : 8;                                         // brow
    const tilt = L.browTilt ?? 4;
    x.beginPath();
    x.moveTo(ex - d * 34, ey - eh - 17 + tilt);
    x.quadraticCurveTo(ex + d * 2, ey - eh - 27, ex + d * 38, ey - eh - 19 - tilt * 0.4);
    x.stroke();
  }
  x.strokeStyle = 'rgba(120,55,60,0.5)'; x.lineWidth = 3; x.lineCap = 'round';
  x.beginPath(); x.moveTo(cx + 3, cy + 52); x.lineTo(cx - 3, cy + 63); x.stroke();                  // nose
  x.strokeStyle = 'rgba(140,50,62,0.95)'; x.lineWidth = 3.6;
  x.beginPath(); x.moveTo(cx - 17, cy + 92); x.quadraticCurveTo(cx, cy + (L.smile ?? 99), cx + 17, cy + 91); x.stroke();  // mouth

  // painted scalp, sideburns and fringe so the sculpted locks sit on real hair, not a helmet
  const style = L.hairStyle, hl = style === 'slick' ? 128 : 150, sideX = 228, nape = 398;
  const fringe = {
    spiky: { tips: [34, 50, 74, 44, 66, 40, 30], sway: 8, valley: 6 },
    ponytail: { tips: [30, 46, 58, 62, 50, 34], sway: -16, valley: 8 },
    bob: { tips: [58, 60, 62, 60, 62, 60, 62, 60, 58], sway: 0, valley: 50 },
    slick: { tips: [4, 10, 24, 10, 4], sway: 0, valley: 0 },
  }[style];
  const path = () => {
    x.beginPath();
    x.moveTo(0, 0); x.lineTo(w, 0); x.lineTo(w, nape); x.lineTo(cx + sideX + 16, nape);
    x.quadraticCurveTo(cx + sideX - 6, nape - 40, cx + sideX, hl + 96);
    x.lineTo(cx + sideX, hl + fringe.valley);
    const n = fringe.tips.length, span = sideX * 2;
    for (let i = n - 1; i >= 0; i--) {
      const x1 = cx - sideX + ((i + 1) / n) * span, x0 = cx - sideX + (i / n) * span;
      x.lineTo(x1, hl + fringe.valley);
      x.quadraticCurveTo((x0 + x1) / 2 + fringe.sway + 10, hl + fringe.tips[i] * 0.7, (x0 + x1) / 2 + fringe.sway, hl + fringe.tips[i]);
      x.quadraticCurveTo(x0 + 6, hl + fringe.tips[i] * 0.5, x0, hl + fringe.valley);
    }
    x.lineTo(cx - sideX, hl + 96);
    x.quadraticCurveTo(cx - sideX + 6, nape - 40, cx - sideX - 16, nape);
    x.lineTo(0, nape); x.closePath();
  };
  x.save();
  x.shadowColor = 'rgba(40,10,30,0.5)'; x.shadowBlur = 10; x.shadowOffsetY = 5;
  path(); x.fillStyle = css(hair); x.fill();
  x.restore();
  x.save(); path(); x.clip();
  const rnd = seeded(31), light = hair.clone().lerp(hex(0xffffff), 0.25), shade = hair.clone().multiplyScalar(0.6);
  for (let i = 0; i < 260; i++) {
    const sx = rnd() * w, len = 60 + rnd() * 240, y0 = rnd() * 300;
    x.strokeStyle = css(rnd() < 0.5 ? light : shade, 0.22); x.lineWidth = 1 + rnd() * 2.5;
    x.beginPath(); x.moveTo(sx, y0); x.quadraticCurveTo(sx + (rnd() - 0.5) * 20, y0 + len / 2, sx + (rnd() - 0.5) * 26, y0 + len); x.stroke();
  }
  x.restore();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

function makeMaterials(L, accent, fx) {
  const std = (color, rough = 0.7, metal = 0, extra = {}) =>
    patchCharacterMaterial(new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: metal, ...extra }), fx);
  return {
    skin: std(L.skin, 0.52),
    face: std(0xffffff, 0.52, 0, { map: makeFaceTexture(L) }),
    hair: std(0xffffff, 0.38, 0.05, { vertexColors: true }),
    jacket: std(L.jacket, 0.6),
    skirt: std(L.skirt ?? L.jacket, 0.6, 0, { side: THREE.DoubleSide }),
    dark: std(L.dark, 0.55),
    pants: std(L.pants, 0.7),
    boots: std(L.boots, 0.38, 0.25),
    glove: std(L.glove ?? L.dark, 0.45, 0.1),
    metal: std(L.metal ?? 0x9aa4ba, 0.26, 0.95),
    trim: std(0x0a0a0a, 0.4, 0.2, { emissive: accent, emissiveIntensity: 2.6 }),
    glow: new THREE.MeshBasicMaterial({ color: hex(accent).multiplyScalar(3.2) }),
  };
}

// ------------------------------------------------------------ geometry helpers
const _geo = new Map();
const cached = (key, make) => { if (!_geo.has(key)) { const g = make(); g.userData.shared = true; _geo.set(key, g); } return _geo.get(key); };
const sphereGeo = () => cached('sphere', () => new THREE.SphereGeometry(1, 20, 14));
const limbGeo = (rt, rb, len) => cached(`limb:${rt}:${rb}:${len}`, () => {
  const g = new THREE.CylinderGeometry(rt, rb, len, 14, 1, true); g.translate(0, -len / 2, 0); return g;
});
const lathe = (pts, seg = 22) => new THREE.LatheGeometry(pts.map(([r, y]) => new THREE.Vector2(r, y)), seg);

function colorize(geo, colorFn) {
  const p = geo.attributes.position, col = new Float32Array(p.count * 3), c = new THREE.Color();
  for (let i = 0; i < p.count; i++) { colorFn(c, p.getX(i), p.getY(i), p.getZ(i)); col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b; }
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
  return geo;
}

/** A tapered, flattened, curved lock of hair. Base at origin, grows along +Y, bends toward +X. */
function lockGeo(len, width, thick, bend, base, tip) {
  const g = new THREE.ConeGeometry(1, len, 7, 5, false);
  g.translate(0, len / 2, 0);
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const t = p.getY(i) / len;
    const belly = 0.75 + 0.45 * Math.sin(Math.min(1, t * 1.6) * Math.PI * 0.5);
    p.setX(i, p.getX(i) * thick * 0.5 * belly + bend * t * t);
    p.setZ(i, p.getZ(i) * width * 0.5 * belly);
  }
  g.computeVertexNormals();
  const cb = hex(base), ct = hex(tip);
  return colorize(g, (c, x, y) => c.copy(cb).lerp(ct, Math.pow(Math.min(1, Math.max(0, y / len)), 1.4)));
}

// ------------------------------------------------------------ weapons
function buildWeapon(type, accent, M) {
  const group = new THREE.Group();
  const acc = hex(accent);
  const coreMat = new THREE.MeshBasicMaterial({ color: acc.clone().lerp(hex(0xffffff), 0.6).multiplyScalar(4.5) });
  const auraMat = new THREE.MeshBasicMaterial({ color: acc.clone().multiplyScalar(2.0), transparent: true, opacity: 0.4, blending: THREE.AdditiveBlending, depthWrite: false });
  const metal = M.metal, dark = M.dark;
  const mesh = (geo, mat, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, parent = group) => {
    const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.rotation.set(rx, ry, rz); m.castShadow = mat !== auraMat && mat !== coreMat; parent.add(m); return m;
  };
  const energy = new THREE.Group(); group.add(energy);   // scaled along Z to ignite / extinguish
  const base = new THREE.Object3D(), tip = new THREE.Object3D(), muzzle = new THREE.Object3D();
  group.add(base, tip, muzzle);
  let gripL = null, reach = 1.2;

  if (type === 'saber') {
    mesh(new THREE.CylinderGeometry(0.021, 0.024, 0.24, 10), metal, 0, 0, 0.0, Math.PI / 2);
    mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.03, 10), dark, 0, 0, -0.125, Math.PI / 2);
    mesh(new THREE.BoxGeometry(0.11, 0.028, 0.035), metal, 0, 0, 0.13);
    mesh(new THREE.BoxGeometry(0.04, 0.05, 0.02), M.trim, 0, 0, 0.145);
    const blade = new THREE.BoxGeometry(0.014, 0.04, 1.08); blade.translate(0, 0, 0.54);
    const aura = new THREE.BoxGeometry(0.034, 0.078, 1.12); aura.translate(0, 0, 0.56);
    energy.position.z = 0.15;
    mesh(blade, coreMat, 0, 0, 0, 0, 0, 0, energy);
    mesh(aura, auraMat, 0, 0, 0, 0, 0, 0, energy);
    base.position.z = 0.2; tip.position.z = 1.24; muzzle.position.z = 1.0; reach = 1.25;
  } else if (type === 'spear') {
    mesh(new THREE.CylinderGeometry(0.017, 0.017, 1.75, 8), metal, 0, 0, 0.1, Math.PI / 2);
    mesh(new THREE.CylinderGeometry(0.026, 0.026, 0.3, 8), dark, 0, 0, 0.0, Math.PI / 2);
    mesh(new THREE.CylinderGeometry(0.026, 0.026, 0.24, 8), dark, 0, 0, 0.5, Math.PI / 2);
    mesh(new THREE.OctahedronGeometry(0.05, 0), M.trim, 0, 0, -0.8);
    mesh(new THREE.CylinderGeometry(0.045, 0.02, 0.1, 6), metal, 0, 0, 0.98, Math.PI / 2);
    for (const sx of [-1, 1]) mesh(new THREE.BoxGeometry(0.012, 0.03, 0.16), metal, sx * 0.05, 0, 1.03, 0, sx * 0.5, 0);
    const head = new THREE.OctahedronGeometry(1, 0); head.scale(0.018, 0.075, 0.3); head.translate(0, 0, 0.3);
    const aura = new THREE.OctahedronGeometry(1, 0); aura.scale(0.045, 0.14, 0.38); aura.translate(0, 0, 0.3);
    energy.position.z = 1.02;
    mesh(head, coreMat, 0, 0, 0, 0, 0, 0, energy);
    mesh(aura, auraMat, 0, 0, 0, 0, 0, 0, energy);
    gripL = new THREE.Object3D(); gripL.position.set(0, 0, 0.5); group.add(gripL);
    base.position.z = 0.95; tip.position.z = 1.64; muzzle.position.z = 1.6; reach = 1.7;
  } else if (type === 'hammer') {
    mesh(new THREE.CylinderGeometry(0.024, 0.024, 1.5, 8), metal, 0, 0, 0.32, Math.PI / 2);
    mesh(new THREE.CylinderGeometry(0.032, 0.032, 0.3, 8), dark, 0, 0, 0.0, Math.PI / 2);
    mesh(new THREE.CylinderGeometry(0.032, 0.032, 0.24, 8), dark, 0, 0, -0.32, Math.PI / 2);
    mesh(new THREE.SphereGeometry(0.045, 8, 6), M.trim, 0, 0, -0.45);
    const hz = 1.05;
    mesh(new THREE.BoxGeometry(0.2, 0.44, 0.24), dark, 0, 0, hz);
    mesh(new THREE.BoxGeometry(0.24, 0.1, 0.28), metal, 0, 0.19, hz);
    mesh(new THREE.BoxGeometry(0.24, 0.1, 0.28), metal, 0, -0.19, hz);
    mesh(new THREE.BoxGeometry(0.215, 0.16, 0.255), M.trim, 0, 0, hz);
    energy.position.z = hz;
    mesh(new THREE.BoxGeometry(0.17, 0.035, 0.2), coreMat, 0, 0.245, 0, 0, 0, 0, energy);
    mesh(new THREE.BoxGeometry(0.17, 0.035, 0.2), coreMat, 0, -0.245, 0, 0, 0, 0, energy);
    gripL = new THREE.Object3D(); gripL.position.set(0, 0, -0.3); group.add(gripL);
    base.position.z = 0.8; tip.position.z = 1.2; muzzle.position.z = 1.05; reach = 1.35;
  } else if (type === 'pistol') {
    mesh(new THREE.BoxGeometry(0.034, 0.06, 0.2), dark, 0, 0.012, 0.07);
    mesh(new THREE.BoxGeometry(0.03, 0.1, 0.045), dark, 0, -0.04, -0.01, 0.25);
    mesh(new THREE.BoxGeometry(0.038, 0.022, 0.21), metal, 0, 0.05, 0.075);
    mesh(new THREE.BoxGeometry(0.04, 0.012, 0.13), M.trim, 0, 0.012, 0.09);
    mesh(new THREE.CylinderGeometry(0.011, 0.011, 0.03, 8), coreMat, 0, 0.02, 0.18, Math.PI / 2, 0, 0, energy);
    base.position.z = 0.05; tip.position.z = 0.2; muzzle.position.set(0, 0.02, 0.21); reach = 0.3;
  }
  return { type, group, energy, base, tip, muzzle, gripL, reach, coreMat, auraMat };
}

// ------------------------------------------------------------ hair
function buildHair(head, L, M, R, danglers) {
  const base = L.hair, tipC = L.hairTip ?? L.hair;
  const hair = new THREE.Group();
  hair.position.set(0, R * 0.92, 0.004);
  head.add(hair);
  const yS = 1.07;
  const addMesh = (geo, parent = hair) => { const m = new THREE.Mesh(geo, M.hair); m.castShadow = true; parent.add(m); return m; };
  const tint = (geo, mode = 'cap') => colorize(geo, (c, x, y) => {
    c.set(base);
    if (mode === 'shell') c.lerp(hex(tipC), THREE.MathUtils.clamp((-y / R - 0.1) * 0.9, 0, 1));
  });
  const style = L.hairStyle;
  const capTheta = { spiky: 0.33, ponytail: 0.32, bob: 0.34, slick: 0.26 }[style] * Math.PI;
  const cap = tint(new THREE.SphereGeometry(R * 1.035, 26, 12, 0, Math.PI * 2, 0, capTheta));
  cap.scale(1, yS, 1.02);
  addMesh(cap);
  const backTheta = { spiky: 0.72, ponytail: 0.74, bob: 0.82, slick: 0.6 }[style] * Math.PI;
  const backWidth = { spiky: 4.3, ponytail: 4.25, bob: 4.5, slick: 4.0 }[style];
  const back = tint(new THREE.SphereGeometry(R * (style === 'bob' ? 1.12 : 1.045), 26, 14, -Math.PI / 2 - backWidth / 2, backWidth, 0, backTheta), 'shell');
  back.scale(1, yS, 1.03);
  const backMesh = addMesh(back);
  backMesh.material = M.hairDouble;

  const onHead = (az, el, r = 1.03) => V3(Math.sin(az) * Math.cos(el) * R * r, Math.sin(el) * R * r * yS, Math.cos(az) * Math.cos(el) * R * r);
  const X = V3(), Y = V3(), Z = V3(), mtx = new THREE.Matrix4();
  /** Place a lock: starts at `pos`, grows along `dir`, bends toward `bendDir`. */
  const lock = (pos, dir, bendDir, len, width, thick, bend, parent = hair, tip = tipC) => {
    Y.copy(dir).normalize();
    X.copy(bendDir).addScaledVector(Y, -bendDir.dot(Y));
    if (X.lengthSq() < 1e-6) X.set(1, 0, 0).addScaledVector(Y, -Y.x);
    X.normalize(); Z.crossVectors(X, Y);
    const m = addMesh(lockGeo(len, width, thick, bend, base, tip), parent);
    mtx.makeBasis(X, Y, Z);
    m.quaternion.setFromRotationMatrix(mtx);
    m.position.copy(pos);
    return m;
  };
  const inward = (p) => V3(-p.x, -p.y * 0.3, -p.z);

  if (style === 'spiky') {
    const bangs = [[-0.95, 0.105, 0.3], [-0.5, 0.12, 0.1], [-0.08, 0.15, -0.12], [0.36, 0.125, -0.25], [0.82, 0.11, -0.35], [1.25, 0.12, -0.2], [-1.3, 0.12, 0.2]];
    for (const [az, len, sway] of bangs) {
      const p = onHead(az, 0.6);
      lock(p, V3(Math.sin(az) * 0.5 + sway, -1, Math.cos(az) * 0.55), inward(p), len, 0.062, 0.022, 0.012);
    }
    const rnd = seeded(11);
    for (let i = 0; i < 22; i++) {
      const az = 0.5 + rnd() * 5.3, el = 0.25 + rnd() * 1.1;
      const p = onHead(az, el, 0.98);
      const d = p.clone().normalize().multiplyScalar(0.8).add(V3(rnd() * 0.3 - 0.15, 0.1 + rnd() * 0.25, -0.55));
      lock(p, d, V3(0, -1, 0), 0.075 + rnd() * 0.055, 0.075, 0.036, 0.022);
    }
  } else if (style === 'ponytail') {
    const bangs = [[-0.85, 0.12, 0.42], [-0.42, 0.125, 0.38], [0.0, 0.12, 0.3], [0.42, 0.105, 0.22], [0.86, 0.11, 0.1]];
    for (const [az, len, sway] of bangs) {
      const p = onHead(az, 0.6);
      lock(p, V3(Math.sin(az) * 0.5 + sway, -1, Math.cos(az) * 0.5), inward(p), len, 0.07, 0.02, 0.012);
    }
    for (const sgn of [-1, 1]) {
      const p = onHead(sgn * 1.2, 0.34);
      lock(p, V3(sgn * 0.1, -1, 0.12), inward(p), 0.25, 0.062, 0.026, 0.014);
    }
    // high ponytail on a two-link chain so it can whip around
    const tieP = V3(0, R * 0.78, -R * 0.82);
    const tie = new THREE.Mesh(new THREE.TorusGeometry(0.027, 0.011, 6, 12), M.trim);
    tie.position.copy(tieP); tie.rotation.x = 0.9; hair.add(tie);
    const l1 = new THREE.Group(); l1.position.copy(tieP); l1.rotation.x = 0.55; hair.add(l1);
    const seg1 = addMesh(lockGeoStraight(0.3, 0.1, 0.07, 0.07, 0.085, base, base), l1); seg1.rotation.x = Math.PI;
    const l2 = new THREE.Group(); l2.position.set(0, -0.28, 0); l1.add(l2);
    const seg2 = addMesh(lockGeo(0.42, 0.11, 0.065, 0.03, base, tipC), l2); seg2.rotation.set(Math.PI, -Math.PI / 2, 0);
    danglers.push({ obj: l1, rest: l1.rotation.clone(), k: 0.11, max: 1.1, stiff: 60, damp: 7 });
    danglers.push({ obj: l2, rest: l2.rotation.clone(), k: 0.16, max: 1.2, stiff: 42, damp: 5 });
  } else if (style === 'bob') {
    const bangs = [[-0.92, 0.1], [-0.6, 0.105], [-0.3, 0.1], [0.0, 0.095], [0.3, 0.1], [0.6, 0.105], [0.92, 0.1]];
    for (const [az, len] of bangs) {
      const p = onHead(az, 0.6);
      lock(p, V3(Math.sin(az) * 0.5, -1, Math.cos(az) * 0.5), inward(p), len, 0.066, 0.02, 0.014);
    }
    for (const sgn of [-1, 1]) {
      const p = onHead(sgn * 1.25, 0.36);
      lock(p, V3(sgn * 0.1, -1, 0.14), inward(p), 0.2, 0.07, 0.03, 0.02);
    }
    const p = onHead(0.3, 1.35, 1.0);
    lock(p, V3(0.25, 1, 0.5), V3(0.3, -1, 1), 0.12, 0.018, 0.012, 0.05);     // ahoge
  } else if (style === 'slick') {
    for (let i = 0; i < 9; i++) {
      const az = -0.8 + (i / 8) * 1.6, p = onHead(az, 0.82, 1.0);
      lock(p, V3(Math.sin(az) * 0.4, 0.55, -0.9), V3(0, -1, 0), 0.13, 0.07, 0.035, 0.03);
    }
    for (let i = 0; i < 7; i++) {
      const az = 2.0 + (i / 6) * 2.3, p = onHead(az, 0.75, 1.0);
      lock(p, V3(Math.sin(az) * 0.5, 0.2, -0.8), V3(0, -1, 0), 0.09, 0.07, 0.035, 0.02);
    }
    const p = onHead(0.35, 0.66);
    lock(p, V3(0.5, -0.9, 0.6), inward(p), 0.13, 0.04, 0.02, 0.012, hair, L.accentHair ?? tipC);
    const p2 = onHead(0.1, 0.7);
    lock(p2, V3(0.2, 0.4, 0.5), V3(0, -1, 0.2), 0.08, 0.05, 0.025, 0.03, hair, L.accentHair ?? tipC);
  }
  return hair;
}

function lockGeoStraight(len, width, thick, bend, bulge, base, tip) {
  const g = new THREE.CylinderGeometry(0.5, 0.42, len, 8, 3, false);
  g.translate(0, len / 2, 0);
  g.scale(thick * 1.4, 1, width);
  const cb = hex(base), ct = hex(tip);
  return colorize(g, (c, x, y) => c.copy(cb).lerp(ct, y / len * 0.3));
}

function seeded(seed) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

// ------------------------------------------------------------ the rig
export class Rig {
  constructor(def) {
    this.def = def;
    const L = def.look;
    const bulk = L.bulk ?? 1, fem = !!L.fem;
    this.scale = L.height / 1.72;
    this.fx = {
      rimColor: { value: hex(def.accent).lerp(hex(0xffffff), 0.35) }, rimPower: { value: 0.3 },
      flash: { value: 0 }, flashColor: { value: hex(0xffffff) },
    };
    const M = this.materials = makeMaterials(L, def.accent, this.fx);
    M.hairDouble = M.hair.clone(); M.hairDouble.side = THREE.DoubleSide; patchCharacterMaterial(M.hairDouble, this.fx);
    M.jacketDouble = M.jacket.clone(); M.jacketDouble.side = THREE.DoubleSide; patchCharacterMaterial(M.jacketDouble, this.fx);
    M.darkDouble = M.dark.clone(); M.darkDouble.side = THREE.DoubleSide; patchCharacterMaterial(M.darkDouble, this.fx);

    this.root = new THREE.Group();
    this.body = new THREE.Group();
    this.body.scale.setScalar(this.scale);
    this.root.add(this.body);
    this.joints = {};
    this.danglers = [];

    const D = this.dims = {
      hipsY: 0.955, legSep: fem ? 0.082 : 0.09 * (0.9 + bulk * 0.1), thigh: 0.44, shin: 0.42, ankle: 0.095,
      spine: 0.16, chest: 0.27, shoulderW: fem ? 0.162 : 0.185 * bulk, shoulderY: 0.205,
      upperArm: 0.275, foreArm: 0.25, neck: 0.06, headR: 0.127,
    };
    const J = (name, parent, x, y, z) => { const o = new THREE.Group(); o.name = name; o.position.set(x, y, z); parent.add(o); this.joints[name] = o; return o; };
    const hips = J('hips', this.body, 0, D.hipsY, 0);
    const spine = J('spine', hips, 0, 0.02, 0);
    const chest = J('chest', spine, 0, D.spine, 0);
    const neck = J('neck', chest, 0, D.chest, 0);
    const head = J('head', neck, 0, D.neck, 0);
    const armL = J('armL', chest, D.shoulderW, D.shoulderY, 0), elbowL = J('elbowL', armL, 0, -D.upperArm, 0), handL = J('handL', elbowL, 0, -D.foreArm, 0);
    const armR = J('armR', chest, -D.shoulderW, D.shoulderY, 0), elbowR = J('elbowR', armR, 0, -D.upperArm, 0), handR = J('handR', elbowR, 0, -D.foreArm, 0);
    const legL = J('legL', hips, D.legSep, -0.02, 0), kneeL = J('kneeL', legL, 0, -D.thigh, 0), footL = J('footL', kneeL, 0, -D.shin, 0);
    const legR = J('legR', hips, -D.legSep, -0.02, 0), kneeR = J('kneeR', legR, 0, -D.thigh, 0), footR = J('footR', kneeR, 0, -D.shin, 0);
    this.jointList = JOINTS.map((n) => this.joints[n]);

    const add = (parent, geo, mat, x = 0, y = 0, z = 0, sx = 1, sy = 1, sz = 1, rx = 0, ry = 0, rz = 0) => {
      const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.rotation.set(rx, ry, rz); m.castShadow = true; parent.add(m); return m;
    };
    const S = sphereGeo();
    const limbW = fem ? 0.88 : bulk * (bulk > 1 ? 1.12 : 1);

    // ---- torso
    const waistR = fem ? 0.098 : 0.112 * bulk, chestR = fem ? 0.15 : 0.166 * bulk, hipR = fem ? 0.148 : 0.142 * bulk;
    add(hips, S, M.pants, 0, -0.03, 0, hipR, 0.115, 0.1 * (fem ? 1 : bulk));
    const waist = lathe([[hipR * 1.05, -0.075], [hipR * 0.98, -0.03], [waistR * 1.04, 0.03], [waistR, 0.09], [waistR * 1.06, 0.19]]);
    add(spine, waist, M.jacketDouble, 0, 0, 0, 1, 1, 0.8);
    const chestG = lathe([[waistR * 1.04, -0.03], [chestR * 0.93, 0.05], [chestR, 0.125], [chestR * 1.0, 0.185], [chestR * 0.8, 0.238], [0.062, 0.262], [0.048, 0.28]]);
    add(chest, chestG, M.jacket, 0, 0, fem ? 0.008 : 0, 1, 1, fem ? 0.7 : 0.66);
    // neck + head
    add(neck, limbGeo(0.04 * (fem ? 0.86 : bulk), 0.046 * (fem ? 0.86 : bulk), 0.11), M.skin, 0, 0.085, 0);
    const R = D.headR;
    const headG = new THREE.SphereGeometry(R, 32, 24, -Math.PI / 2, Math.PI * 2);
    {
      const p = headG.attributes.position;
      for (let i = 0; i < p.count; i++) {
        let x = p.getX(i), y = p.getY(i), z = p.getZ(i);
        if (y < 0) { const t = -y / R; x *= 1 - (fem ? 0.46 : 0.38) * t * t; z *= 1 - 0.26 * t * t; if (z > 0) z += 0.016 * t; y *= 1.04; }
        if (z > 0) z *= 0.95;
        p.setXYZ(i, x, y * 1.07, z);
      }
      headG.computeVertexNormals();
    }
    this.headMesh = add(head, headG, M.face, 0, R * 0.92, 0.004);
    for (const sgn of [-1, 1]) add(head, S, M.skin, sgn * R * 0.97, R * 0.86, -0.004, 0.012, 0.03, 0.02);  // ears
    buildHair(head, L, M, R, this.danglers);

    // ---- arms
    const sleeve = L.sleeves === 'none' ? M.skin : M.jacket;
    const foreMat = L.sleeves === 'long' ? M.jacket : M.skin;
    const uaT = 0.06 * limbW, uaB = 0.05 * limbW, faT = 0.05 * limbW, faB = 0.038 * limbW;
    for (const [arm, elbow, hand, sgn] of [[armL, elbowL, handL, 1], [armR, elbowR, handR, -1]]) {
      { const sr = uaT * (L.sleeves === 'none' ? 1.0 : 1.1); add(arm, S, L.sleeves === 'none' ? M.skin : M.jacket, 0, 0, 0, sr, sr, sr); }
      add(arm, limbGeo(uaT, uaB, D.upperArm), sleeve);
      add(elbow, S, sleeve === M.skin ? M.skin : foreMat, 0, 0, 0, uaB * 1.02, uaB * 1.02, uaB * 1.02);
      add(elbow, limbGeo(faT, faB, D.foreArm), foreMat);
      add(hand, S, M.glove, 0, -0.045, 0, 0.036 * limbW, 0.052, 0.03 * limbW);
      if (L.sleeves === 'long') {
        add(elbow, limbGeo(faB * 1.3, faB * 1.36, 0.05), M.dark, 0, -D.foreArm + 0.055, 0);                 // cuff
        add(elbow, limbGeo(faB * 1.38, faB * 1.38, 0.012), M.trim, 0, -D.foreArm + 0.062, 0);
      }
      if (L.gauntlets) {
        add(elbow, limbGeo(faT * 1.75, faB * 1.9, D.foreArm * 0.82), M.metal, 0, -0.04, 0);
        add(elbow, limbGeo(faT * 1.85, faT * 1.85, 0.03), M.trim, 0, -0.07, 0);
        add(elbow, new THREE.BoxGeometry(0.03, 0.15, 0.02), M.trim, sgn * faT * 1.75, -0.15, 0);
        add(hand, S, M.metal, 0, -0.05, 0, 0.052, 0.06, 0.046);
      }
      if (L.armband && sgn === 1) add(arm, limbGeo(uaT * 1.12, uaT * 1.08, 0.05), M.trim, 0, -0.07, 0);
    }

    // ---- legs
    const thT = 0.09 * limbW, thB = 0.064 * limbW, shT = 0.064 * limbW, shB = 0.045 * limbW;
    const legMat = L.legs === 'tights' ? M.dark : M.pants;
    const bootTop = L.bootHeight ?? 0.24;
    for (const [leg, knee, foot] of [[legL, kneeL, footL], [legR, kneeR, footR]]) {
      add(leg, S, legMat, 0, 0, 0, thT * 1.02, thT * 1.02, thT * 1.02);
      add(leg, limbGeo(thT, thB, D.thigh), legMat);
      add(knee, S, legMat, 0, 0, 0, thB * 1.03, thB * 1.03, thB * 1.03);
      add(knee, limbGeo(shT, shB, D.shin), legMat);
      const bt = D.shin - bootTop;
      const rTop = THREE.MathUtils.lerp(shT, shB, bt / D.shin) * 1.2;
      add(knee, limbGeo(rTop, shB * 1.32, bootTop + 0.02), M.boots, 0, -bt, 0);
      add(knee, limbGeo(rTop * 1.06, rTop * 1.06, 0.016), M.trim, 0, -bt + 0.004, 0);
      add(foot, S, M.boots, 0, -0.012, 0.0, shB * 1.34, 0.05, shB * 1.4);
      const shoe = add(foot, new THREE.CapsuleGeometry(0.046 * (fem ? 0.9 : bulk), 0.125, 6, 10), M.boots, 0, -0.052, 0.062, 1, 1, 0.82, Math.PI / 2, 0, 0);
      shoe.scale.set(1.0, 1, 0.82);
      add(foot, new THREE.BoxGeometry(0.085 * (fem ? 0.9 : bulk), 0.014, 0.23), L.glowSoles ? M.trim : M.dark, 0, -0.088, 0.06);
      if (L.kneeGuards) add(knee, S, M.metal, 0, -0.01, 0.028, thB * 0.85, thB * 1.05, thB * 0.6);
    }

    this._buildOutfit(L, M, add, S, { waistR, chestR, hipR, bulk, fem });

    // ---- weapons
    this.weapon = buildWeapon(def.weapon, def.accent, M);
    this.weapon.group.position.set(0, -0.05, 0);
    handR.add(this.weapon.group);
    this.weapons = [this.weapon];
    if (def.weapon === 'pistol') {
      this.weaponL = buildWeapon('pistol', def.accent, M);
      this.weaponL.group.position.set(0, -0.05, 0);
      handL.add(this.weaponL.group);
      this.weapons.push(this.weaponL);
    }
    this.twoHanded = !!this.weapon.gripL;

    // soft contact shadow
    const blob = new THREE.Mesh(new THREE.CircleGeometry(0.62, 24), Rig.blobMaterial());
    blob.rotation.x = -Math.PI / 2; blob.position.y = 0.012; blob.layers.set(1); blob.renderOrder = 1;
    this.root.add(blob);
    this.blob = blob;

    this.restHips = hips.position.clone();
    this._ik = { T: V3(), dir: V3(), h: V3(), e: V3(), ep: V3(), pp: V3(), axis: V3(), pole: V3(), q1: new THREE.Quaternion(), q2: new THREE.Quaternion(), cross: V3() };
    this._tmp = V3();
    this.localVel = V3();
  }

  static blobMaterial() {
    if (!Rig._blob) {
      const c = document.createElement('canvas'); c.width = c.height = 128;
      const x = c.getContext('2d'), g = x.createRadialGradient(64, 64, 4, 64, 64, 64);
      g.addColorStop(0, 'rgba(0,0,0,0.75)'); g.addColorStop(0.5, 'rgba(0,0,0,0.38)'); g.addColorStop(1, 'rgba(0,0,0,0)');
      x.fillStyle = g; x.fillRect(0, 0, 128, 128);
      Rig._blob = new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(c), transparent: true, depthWrite: false, color: 0x000000, fog: false });
    }
    return Rig._blob;
  }

  _buildOutfit(L, M, add, S, B) {
    const { hips, spine, chest, neck, head, armL, armR } = this.joints;
    const { waistR, chestR, hipR, fem } = B;
    const zS = fem ? 0.7 : 0.66;
    const frontZ = (r) => r * zS;
    // collar + belt + chest sigil: every academy uniform has them
    const collar = lathe([[0.058, -0.012], [0.07, 0.0], [0.072, 0.04], [0.066, 0.05]], 16);
    add(neck, collar, M.darkDouble, 0, 0.0, 0, 1, 1, 0.92);
    add(neck, new THREE.TorusGeometry(0.069, 0.006, 5, 20), M.trim, 0, 0.047, 0, 1, 0.92, 1, Math.PI / 2);
    add(spine, new THREE.TorusGeometry(waistR * 1.08, 0.019, 6, 24), M.dark, 0, 0.01, 0, 1, 0.76, 1, Math.PI / 2);
    add(spine, new THREE.BoxGeometry(0.05, 0.04, 0.02), M.metal, 0, 0.01, waistR * 0.8);
    add(spine, new THREE.BoxGeometry(0.024, 0.02, 0.022), M.trim, 0, 0.01, waistR * 0.81);
    const sig = new THREE.Mesh(new THREE.CylinderGeometry(0.026, 0.026, 0.012, 6), M.glow);
    sig.position.set(chestR * 0.46, 0.15, frontZ(chestR) * 0.9); sig.rotation.set(Math.PI / 2 - 0.2, 0, 0.25);
    chest.add(sig);
    this.sigil = sig;
    const sigRing = add(chest, new THREE.TorusGeometry(0.034, 0.005, 5, 6), M.metal, sig.position.x, sig.position.y, sig.position.z - 0.002);
    sigRing.rotation.set(-0.2, 0.25, 0);
    // placket: a light line down the jacket front
    add(chest, new THREE.BoxGeometry(0.012, 0.2, 0.01), M.trim, 0, 0.09, frontZ(chestR) * 0.985, 1, 1, 1, -0.06);

    const tail = (parent, x, z, w, len, yaw, mat, k, tilt = 0.12) => {
      const pivot = new THREE.Group();
      pivot.position.set(x, 0.0, z); pivot.rotation.y = yaw;
      parent.add(pivot);
      const swing = new THREE.Group(); swing.rotation.x = -tilt; pivot.add(swing);
      const g = new THREE.BoxGeometry(w, len, 0.012, 1, 4, 1); g.translate(0, -len / 2, 0);
      const p = g.attributes.position;
      for (let i = 0; i < p.count; i++) { const t = -p.getY(i) / len; p.setX(i, p.getX(i) * (1 + t * 0.35)); }
      g.computeVertexNormals();
      const m = new THREE.Mesh(g, mat); m.castShadow = true; swing.add(m);
      const hem = new THREE.Mesh(new THREE.BoxGeometry(w * 1.35, 0.014, 0.016), M.trim); hem.position.y = -len + 0.012; swing.add(hem);
      this.danglers.push({ obj: swing, rest: swing.rotation.clone(), k, max: 1.3, stiff: 46, damp: 5.5, yaw });
      return swing;
    };

    if (L.outfit === 'coat') {
      // long duelist's coat: split tails that trail behind
      const r = waistR * 1.02;
      tail(spine, -0.07, -r * 0.72, 0.13, 0.62, Math.PI + 0.25, M.jacketDouble, 0.14, 0.1);
      tail(spine, 0.07, -r * 0.72, 0.13, 0.62, Math.PI - 0.25, M.jacketDouble, 0.14, 0.1);
      tail(spine, -r * 0.98, -0.01, 0.12, 0.56, -Math.PI / 2 - 0.5, M.jacketDouble, 0.12, 0.08);
      tail(spine, r * 0.98, -0.01, 0.12, 0.56, Math.PI / 2 + 0.5, M.jacketDouble, 0.12, 0.08);
      for (const sgn of [-1, 1]) {
        add(chest, new THREE.BoxGeometry(0.1, 0.022, 0.085), M.dark, sgn * chestR * 0.92, 0.232, 0, 1, 1, 1, 0, 0, -sgn * 0.3);  // epaulettes
        add(chest, new THREE.BoxGeometry(0.104, 0.008, 0.089), M.trim, sgn * chestR * 0.92, 0.246, 0, 1, 1, 1, 0, 0, -sgn * 0.3);
        add(chest, new THREE.BoxGeometry(0.035, 0.17, 0.01), M.dark, sgn * 0.045, 0.14, frontZ(chestR) * 0.97, 1, 1, 1, -0.08, 0, sgn * 0.22);  // lapels
      }
    } else if (L.outfit === 'skirt') {
      // split battle skirt: panels that swing free of the legs, shorts underneath
      add(hips, lathe([[hipR * 0.9, 0.05], [hipR * 1.06, -0.02], [hipR * 1.08, -0.12]], 18), M.darkDouble, 0, 0, 0, 1, 1, 0.8);
      const rs = hipR * 1.0;
      for (const [ang, wdt, len] of [[Math.PI, 0.17, 0.4], [Math.PI - 0.95, 0.15, 0.37], [Math.PI + 0.95, 0.15, 0.37], [Math.PI / 2 - 0.25, 0.13, 0.31], [-Math.PI / 2 + 0.25, 0.13, 0.31]]) {
        tail(hips, Math.sin(ang) * rs, Math.cos(ang) * rs * 0.74, wdt, len, ang, M.skirt, 0.13, 0.26).parent.position.y = 0.0;
      }
      for (const sgn of [-1, 1]) add(chest, new THREE.BoxGeometry(0.085, 0.018, 0.075), M.jacket, sgn * chestR * 0.95, 0.228, 0, 1, 1, 1, 0, 0, -sgn * 0.32);
      // short capelet over the shoulders, in two swinging halves
      const r = chestR * 0.9;
      tail(chest, -0.065, -r * 0.6, 0.14, 0.3, Math.PI + 0.3, M.darkDouble, 0.12, 0.18).parent.position.y = 0.2;
      tail(chest, 0.065, -r * 0.6, 0.14, 0.3, Math.PI - 0.3, M.darkDouble, 0.12, 0.18).parent.position.y = 0.2;
      // ribbon tie
      add(chest, new THREE.BoxGeometry(0.07, 0.03, 0.012), M.trim, 0, 0.215, frontZ(chestR) * 0.86, 1, 1, 1, -0.3);
    } else if (L.outfit === 'hoodie') {
      // slouched hood and a cropped tech jacket
      const hood = new THREE.SphereGeometry(0.105, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.62);
      add(chest, hood, M.jacketDouble, 0, 0.245, -0.075, 1.15, 0.8, 0.95, -1.95);
      add(spine, lathe([[waistR * 1.2, 0.1], [waistR * 1.28, 0.16], [waistR * 1.18, 0.2]], 18), M.darkDouble, 0, 0, 0, 1, 1, 0.78); // jacket hem
      add(hips, lathe([[hipR * 0.9, 0.05], [hipR * 1.08, -0.02], [hipR * 1.1, -0.13]], 18), M.darkDouble, 0, 0, 0, 1, 1, 0.82);   // shorts
      for (const sgn of [-1, 1]) add(hips, new THREE.BoxGeometry(0.02, 0.1, 0.07), M.trim, sgn * hipR * 1.08, -0.07, 0);
      // headset + visor pushed up on the forehead
      const R = this.dims.headR, hy = R * 0.92;
      add(head, new THREE.TorusGeometry(R * 1.09, 0.011, 6, 20, Math.PI), M.dark, 0, hy + 0.01, -0.005, 1, 1.07, 1);
      for (const sgn of [-1, 1]) {
        add(head, new THREE.CylinderGeometry(0.036, 0.036, 0.022, 14), M.dark, sgn * R * 1.08, hy - 0.004, -0.005, 1, 1, 1, 0, 0, Math.PI / 2);
        add(head, new THREE.CylinderGeometry(0.02, 0.02, 0.026, 12), M.glow, sgn * R * 1.085, hy - 0.004, -0.005, 1, 1, 1, 0, 0, Math.PI / 2);
      }
      const visor = new THREE.Mesh(new THREE.CylinderGeometry(R * 1.1, R * 1.1, 0.034, 20, 1, true, -0.85, 1.7), M.glow);
      visor.position.set(0, hy + R * 0.66, 0.012); visor.rotation.x = -0.35;
      head.add(visor);
    } else if (L.outfit === 'armor') {
      // plated vest, one pauldron, and a waist cloth
      add(chest, lathe([[chestR * 0.99, 0.03], [chestR * 1.07, 0.11], [chestR * 1.06, 0.19], [chestR * 0.86, 0.236]], 18), M.dark, 0, 0, 0, 1, 1, zS * 1.07);
      for (const sgn of [-1, 1]) add(chest, new THREE.BoxGeometry(0.012, 0.15, 0.012), M.trim, sgn * 0.085, 0.12, frontZ(chestR) * 1.05, 1, 1, 1, -0.05, 0, sgn * 0.3);
      const pauldron = new THREE.SphereGeometry(0.098, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.55);
      add(armR, pauldron, M.metal, -0.012, 0.012, 0, 1.1, 0.95, 1.15, 0, 0, 0.35);
      const r = waistR;
      tail(spine, 0, -r * 0.74, 0.17, 0.42, Math.PI, M.darkDouble, 0.13, 0.1);
      tail(spine, -r * 0.9, 0.02, 0.1, 0.36, -Math.PI / 2 - 0.4, M.darkDouble, 0.12, 0.08);
      tail(spine, r * 0.9, 0.02, 0.1, 0.36, Math.PI / 2 + 0.4, M.darkDouble, 0.12, 0.08);
    }
  }

  /** Apply a pose (see anim.js for the layout) and resolve grounding + off-hand IK. */
  applyPose(pose) {
    const jl = this.jointList, n = jl.length;
    for (let i = 0; i < n; i++) jl[i].rotation.set(pose[i * 3], pose[i * 3 + 1], pose[i * 3 + 2]);
    const o = n * 3;
    const hips = this.joints.hips;
    const px = pose[o], py = pose[o + 1], pz = pose[o + 2], twoHand = pose[o + 3], ground = pose[o + 4];
    hips.position.set(this.restHips.x + px, this.restHips.y, this.restHips.z + pz);
    // plant the lowest foot on the floor
    this.root.updateMatrixWorld(true);
    const s = this.scale, rootY = this.root.position.y;
    let autoY = this.restHips.y;
    if (ground > 0.001) {
      const fl = this.joints.footL.matrixWorld.elements[13], fr = this.joints.footR.matrixWorld.elements[13];
      const low = (Math.min(fl, fr) - rootY) / s;
      autoY = this.restHips.y - (low - this.dims.ankle);
    }
    hips.position.y = THREE.MathUtils.lerp(this.restHips.y, autoY, ground) + py;
    if (this.twoHanded && twoHand > 0.001) {
      hips.updateMatrixWorld(true);
      this._solveOffHand(twoHand);
    }
  }

  _solveOffHand(weight) {
    const k = this._ik, { chest, armL, elbowL } = this.joints;
    const a = this.dims.upperArm, b = this.dims.foreArm;
    this.weapon.gripL.getWorldPosition(k.T);
    chest.worldToLocal(k.T);
    k.dir.copy(k.T).sub(armL.position);
    let d = k.dir.length();
    d = THREE.MathUtils.clamp(d, 0.1, a + b - 0.004);
    k.dir.normalize();
    const cosE = THREE.MathUtils.clamp((a * a + b * b - d * d) / (2 * a * b), -1, 1);
    const bend = -(Math.PI - Math.acos(cosE));
    k.h.set(0, -a - b * Math.cos(bend), -b * Math.sin(bend)).normalize();
    k.q1.setFromUnitVectors(k.h, k.dir);
    // swivel so the elbow drops down and out
    k.e.set(0, -a, 0).applyQuaternion(k.q1);
    k.pole.set(0.75, -0.6, -0.25);
    k.ep.copy(k.e).addScaledVector(k.dir, -k.e.dot(k.dir));
    k.pp.copy(k.pole).addScaledVector(k.dir, -k.pole.dot(k.dir));
    if (k.ep.lengthSq() > 1e-8 && k.pp.lengthSq() > 1e-8) {
      k.cross.crossVectors(k.ep, k.pp);
      const ang = Math.atan2(k.dir.dot(k.cross), k.ep.dot(k.pp));
      k.q2.setFromAxisAngle(k.dir, ang);
      k.q1.premultiply(k.q2);
    }
    if (weight >= 0.999) {
      armL.quaternion.copy(k.q1);
      elbowL.rotation.set(bend, 0, 0);
    } else {
      armL.quaternion.slerp(k.q1, weight);
      elbowL.rotation.set(THREE.MathUtils.lerp(elbowL.rotation.x, bend, weight), elbowL.rotation.y * (1 - weight), elbowL.rotation.z * (1 - weight));
    }
  }

  /** Cloth / hair follow-through. `vel` is world velocity, `facing` the body yaw. */
  updateSecondary(dt, vel, facing, t) {
    const c = Math.cos(-facing), s = Math.sin(-facing);
    const lx = vel.x * c + vel.z * s, lz = -vel.x * s + vel.z * c;
    this.localVel.set(lx, vel.y, lz);
    for (const d of this.danglers) {
      // express local velocity in the dangler's own yaw frame
      const yaw = d.yaw ?? 0;
      const cy = Math.cos(yaw), sy = Math.sin(yaw);
      const vx = lx * cy - lz * sy, vz = lx * sy + lz * cy;
      const sway = Math.sin(t * 1.7 + (d.yaw ?? 0) * 3.1) * 0.035;
      const tx = THREE.MathUtils.clamp(d.rest.x + vz * d.k - Math.max(0, vel.y) * 0.05 + sway, d.rest.x - d.max, d.rest.x + d.max);
      const tz = THREE.MathUtils.clamp(d.rest.z - vx * d.k, d.rest.z - d.max, d.rest.z + d.max);
      d.vx = (d.vx ?? 0) + ((tx - d.obj.rotation.x) * d.stiff - (d.vx ?? 0) * d.damp) * dt;
      d.vz = (d.vz ?? 0) + ((tz - d.obj.rotation.z) * d.stiff - (d.vz ?? 0) * d.damp) * dt;
      d.obj.rotation.x += d.vx * dt;
      d.obj.rotation.z += d.vz * dt;
    }
  }

  setIgnite(v) {
    for (const w of this.weapons) { w.energy.scale.z = Math.max(0.001, v); w.energy.visible = v > 0.01; }
  }

  setGhost(alpha) { this.root.visible = alpha > 0.01; }
}
