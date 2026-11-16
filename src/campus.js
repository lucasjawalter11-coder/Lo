// The academy courtyard: a walkable hub with the Register board, training hall, the Crown Gate
// and the seat-holders you can walk up to and challenge.
import * as THREE from './three.js';
import { Rig } from './character.js';
import { Animator } from './anim.js';
import { angDiff } from './combat.js';
import { ROMAN } from './rpg.js';

const TAU = Math.PI * 2;
export const CAMPUS_RADIUS = 15.2;

function seeded(seed) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

function plazaMaps(size) {
  const mk = () => { const c = document.createElement('canvas'); c.width = c.height = size; return c; };
  const albedo = mk(), emissive = mk();
  const a = albedo.getContext('2d'), e = emissive.getContext('2d');
  const c = size / 2, R = size / 2, rnd = seeded(4);
  a.fillStyle = '#4a5166'; a.fillRect(0, 0, size, size);
  e.fillStyle = '#000'; e.fillRect(0, 0, size, size);
  // rings of pavers
  const rings = 22;
  for (let i = 0; i < rings; i++) {
    const r0 = (i / rings) * R, r1 = ((i + 1) / rings) * R, n = Math.max(6, Math.round(6 + i * 5.2)), off = rnd() * TAU;
    for (let j = 0; j < n; j++) {
      const a0 = off + (j / n) * TAU, a1 = off + ((j + 1) / n) * TAU, tone = 70 + rnd() * 36;
      a.beginPath(); a.arc(c, c, r1, a0, a1); a.arc(c, c, r0, a1, a0, true); a.closePath();
      a.fillStyle = `rgb(${tone - 6},${tone},${tone + 20})`; a.fill();
      a.strokeStyle = 'rgba(20,24,36,0.9)'; a.lineWidth = size / 700; a.stroke();
    }
  }
  const ring = (ctx, r, w, style) => { ctx.beginPath(); ctx.arc(c, c, r * R, 0, TAU); ctx.lineWidth = w * R; ctx.strokeStyle = style; ctx.stroke(); };
  ring(a, 0.3, 0.02, '#8d96ad'); ring(a, 0.62, 0.012, '#8d96ad'); ring(a, 0.92, 0.025, '#2a3042');
  // inlaid light lines (tinted by the academy colour through the material's emissive)
  e.shadowColor = '#fff'; e.shadowBlur = size / 200;
  ring(e, 0.3, 0.004, '#fff'); ring(e, 0.62, 0.003, '#fff'); ring(e, 0.905, 0.004, '#fff');
  for (let i = 0; i < 8; i++) {
    const ang = (i / 8) * TAU + TAU / 16;
    e.beginPath(); e.moveTo(c + Math.cos(ang) * 0.31 * R, c + Math.sin(ang) * 0.31 * R); e.lineTo(c + Math.cos(ang) * 0.61 * R, c + Math.sin(ang) * 0.61 * R);
    e.lineWidth = 0.003 * R; e.strokeStyle = '#fff'; e.stroke();
  }
  // crest: a four-point compass star
  const star = (ctx, rOut, rIn, rot, fill, stroke) => {
    ctx.beginPath();
    for (let i = 0; i < 8; i++) { const rr = (i & 1 ? rIn : rOut) * R, ang = rot + (i / 8) * TAU; const px = c + Math.cos(ang) * rr, py = c + Math.sin(ang) * rr; if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py); }
    ctx.closePath();
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 0.004 * R; ctx.stroke(); }
  };
  star(a, 0.27, 0.07, -Math.PI / 2, '#9aa3ba');
  star(a, 0.18, 0.05, -Math.PI / 2 + Math.PI / 4, '#6d7690');
  star(e, 0.27, 0.07, -Math.PI / 2, null, '#fff');
  e.beginPath(); e.arc(c, c, 0.03 * R, 0, TAU); e.fillStyle = '#fff'; e.fill();
  return { albedo, emissive };
}

const tex = (canvas, srgb = true) => { const t = new THREE.CanvasTexture(canvas); t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace; t.anisotropy = 8; return t; };

export class Campus {
  constructor(scene) {
    this.group = new THREE.Group();
    this.group.visible = false;
    scene.add(this.group);
    this.time = 0;
    this.accent = new THREE.Color(0x39c9ff);
    this.accentMats = [];      // MeshBasic glow materials that follow the academy colour
    this.obstacles = [];       // { x, z, r } circles the player cannot walk through
    this.spots = {};           // named places: register, training, gate, proctor, npc slots
    this._build();
  }

  _glow(intensity = 2.4) { const m = new THREE.MeshBasicMaterial({ color: 0xffffff }); m.userData.k = intensity; this.accentMats.push(m); return m; }

  _build() {
    const g = this.group;
    const add = (geo, mat, x = 0, y = 0, z = 0, parent = g) => { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = true; m.receiveShadow = true; parent.add(m); return m; };
    const stone = new THREE.MeshStandardMaterial({ color: 0x8f98b3, roughness: 0.66, metalness: 0.05 });
    const stoneDark = new THREE.MeshStandardMaterial({ color: 0x59617a, roughness: 0.7, metalness: 0.1 });
    const slate = new THREE.MeshStandardMaterial({ color: 0x1b2032, roughness: 0.45, metalness: 0.6 });
    const metal = new THREE.MeshStandardMaterial({ color: 0x8e98b0, roughness: 0.3, metalness: 0.9 });
    const warm = new THREE.MeshBasicMaterial({ color: new THREE.Color(1.0, 0.8, 0.5).multiplyScalar(1.25) });
    const glass = new THREE.MeshStandardMaterial({ color: 0x0c1322, roughness: 0.08, metalness: 0.9 });

    // ---- plaza
    const maps = plazaMaps(2048);
    this.plazaMat = new THREE.MeshStandardMaterial({ map: tex(maps.albedo), emissiveMap: tex(maps.emissive), emissive: 0xffffff, emissiveIntensity: 1.2, roughness: 0.78, metalness: 0.05 });
    const plaza = new THREE.Mesh(new THREE.CircleGeometry(22, 96), this.plazaMat);
    plaza.rotation.x = -Math.PI / 2; plaza.receiveShadow = true;
    g.add(plaza);
    add(new THREE.CylinderGeometry(22.3, 19, 5, 64, 1, true), slate, 0, -2.5, 0).castShadow = false;
    const rail = add(new THREE.TorusGeometry(21.4, 0.06, 6, 120), metal, 0, 1.05, 0); rail.rotation.x = Math.PI / 2;
    const railGlow = add(new THREE.TorusGeometry(21.4, 0.03, 5, 120), this._glow(1.8), 0, 0.2, 0); railGlow.rotation.x = Math.PI / 2; railGlow.castShadow = false;
    for (let i = 0; i < 40; i++) {
      const a = (i / 40) * TAU;
      if (Math.abs(angDiff(a, -Math.PI / 2)) < 0.75) continue;                 // open toward the academy steps
      add(new THREE.BoxGeometry(0.08, 1.05, 0.08), metal, Math.cos(a) * 21.4, 0.52, Math.sin(a) * 21.4);
    }

    // ---- the academy hall
    const hall = new THREE.Group(); hall.position.set(0, 0, -30); g.add(hall);
    add(new THREE.BoxGeometry(26, 13, 10), stone, 0, 6.5, 0, hall);
    add(new THREE.BoxGeometry(27.5, 0.7, 11.5), slate, 0, 13.3, 0, hall);
    add(new THREE.BoxGeometry(10, 5.5, 7), stone, 0, 16.3, 0, hall);
    add(new THREE.BoxGeometry(11, 0.5, 8), slate, 0, 19.2, 0, hall);
    add(new THREE.BoxGeometry(5.2, 16, 5.2), stone, 0, 27, 0, hall);                       // tower
    const spire = add(new THREE.ConeGeometry(3.9, 7, 4), slate, 0, 38.5, 0, hall); spire.rotation.y = Math.PI / 4;
    add(new THREE.SphereGeometry(0.45, 12, 8), this._glow(5), 0, 42.6, 0, hall).castShadow = false;
    const clock = add(new THREE.TorusGeometry(1.7, 0.1, 8, 40), this._glow(2.6), 0, 29.5, 2.65, hall); clock.castShadow = false;
    add(new THREE.CircleGeometry(1.6, 32), glass, 0, 29.5, 2.62, hall);
    this.clockHand = add(new THREE.BoxGeometry(0.08, 1.3, 0.04), this._glow(3), 0, 29.5, 2.68, hall); this.clockHand.geometry.translate(0, 0.6, 0); this.clockHand.castShadow = false;
    for (let i = -4; i <= 4; i++) {                                                         // tall lit windows
      if (i === 0) continue;
      add(new THREE.BoxGeometry(0.9, 7.2, 0.2), warm, i * 2.7, 7.4, 5.02, hall).castShadow = false;
      add(new THREE.BoxGeometry(1.3, 7.8, 0.3), slate, i * 2.7, 7.4, 4.95, hall);
    }
    for (let i = -1; i <= 1; i++) add(new THREE.BoxGeometry(1.4, 2.6, 0.2), warm, i * 2.6, 16.6, 3.52, hall).castShadow = false;
    add(new THREE.BoxGeometry(4.6, 6, 0.6), glass, 0, 3, 5.0, hall);                        // doors
    const frame = add(new THREE.BoxGeometry(5.2, 6.5, 0.3), this._glow(2.2), 0, 3.2, 4.95, hall); frame.castShadow = false;
    for (let i = 0; i < 3; i++) add(new THREE.BoxGeometry(15 + i * 1.2, 0.2 * (3 - i), 1.1), stoneDark, 0, 0.1 * (3 - i), 5.55 + i * 1.1, hall);   // steps
    for (const sx of [-1, 1]) {
      for (let i = 0; i < 3; i++) {                                                         // colonnade
        const col = add(new THREE.CylinderGeometry(0.42, 0.5, 9.5, 14), stone, sx * (4 + i * 3.4), 4.75, 6.6, hall);
        add(new THREE.BoxGeometry(1.3, 0.4, 1.3), stoneDark, col.position.x, 9.6, 6.6, hall);
      }
      const wing = new THREE.Group(); wing.position.set(sx * 21.5, 0, 3.5); wing.rotation.y = -sx * 0.42; hall.add(wing);
      add(new THREE.BoxGeometry(17, 9, 8), stone, 0, 4.5, 0, wing);
      add(new THREE.BoxGeometry(18, 0.5, 9), slate, 0, 9.2, 0, wing);
      for (let r = 0; r < 2; r++) add(new THREE.BoxGeometry(14.5, 1.2, 0.2), warm, 0, 3 + r * 3.2, 4.02, wing).castShadow = false;
      for (let i = 0; i < 6; i++) add(new THREE.BoxGeometry(0.3, 8.2, 0.34), stoneDark, -7.25 + i * 2.9, 4.5, 4.05, wing);
      // banners in academy colours
      const pole = add(new THREE.CylinderGeometry(0.07, 0.07, 9, 8), metal, sx * 8.2, 4.5, 11.5, hall);
      const banner = add(new THREE.PlaneGeometry(1.5, 5.2, 4, 10), this._glow(0.9), pole.position.x + sx * 0.0, 5.6, 11.56, hall);
      banner.material = this._glow(0.75); banner.material.side = THREE.DoubleSide; banner.castShadow = false;
      banner.userData.wave = sx;
      (this.banners = this.banners || []).push(banner);
    }
    add(new THREE.BoxGeometry(18, 0.5, 2.6), slate, 0, 9.9, 6.6, hall);                     // portico roof
    // floating crest above the doors
    this.crest = new THREE.Group(); this.crest.position.set(0, 12.2, 9.2); hall.add(this.crest);
    add(new THREE.TorusGeometry(1.5, 0.07, 8, 48), this._glow(3), 0, 0, 0, this.crest).castShadow = false;
    const st = add(new THREE.OctahedronGeometry(0.9, 0), this._glow(3.4), 0, 0, 0, this.crest); st.scale.set(1, 1.5, 0.3); st.castShadow = false;
    this.crestStar = st;

    // ---- lamps and blossom trees around the plaza
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * TAU + TAU / 24, x = Math.cos(a) * 18.3, z = Math.sin(a) * 18.3;
      add(new THREE.CylinderGeometry(0.06, 0.1, 3.4, 8), metal, x, 1.7, z);
      add(new THREE.SphereGeometry(0.19, 12, 8), this._glow(3.2), x, 3.55, z).castShadow = false;
      this.obstacles.push({ x, z, r: 0.35 });
    }
    const petalPink = new THREE.MeshStandardMaterial({ color: 0xffb7cf, roughness: 0.85, emissive: 0xff5f95, emissiveIntensity: 0.28, flatShading: true });
    const bark = new THREE.MeshStandardMaterial({ color: 0x3a2a2a, roughness: 0.9 });
    const rnd = seeded(77);
    const treeSpots = [[-13, -9], [13, -9], [-15.5, 4.5], [15.5, 4.5], [-9.5, 13], [9.5, 13], [-17.5, -3], [17.5, -3]];
    for (const [x, z] of treeSpots) {
      const h = 2.6 + rnd() * 0.8;
      const trunk = add(new THREE.CylinderGeometry(0.16, 0.26, h, 7), bark, x, h / 2, z); trunk.rotation.z = (rnd() - 0.5) * 0.16;
      for (let i = 0; i < 6; i++) {
        const b = add(new THREE.IcosahedronGeometry(0.95 + rnd() * 0.7, 1), petalPink, x + (rnd() - 0.5) * 2.2, h + 0.5 + rnd() * 1.5, z + (rnd() - 0.5) * 2.2);
        b.scale.y = 0.78;
      }
      add(new THREE.CylinderGeometry(1.25, 1.35, 0.35, 16), stoneDark, x, 0.175, z);
      this.obstacles.push({ x, z, r: 1.45 });
    }
    // drifting petals
    const N = 420, pos = new Float32Array(N * 3), seed = new Float32Array(N);
    for (let i = 0; i < N; i++) { pos[i * 3] = (rnd() - 0.5) * 44; pos[i * 3 + 1] = rnd() * 9; pos[i * 3 + 2] = (rnd() - 0.5) * 44; seed[i] = rnd(); }
    const pg = new THREE.BufferGeometry();
    pg.setAttribute('position', new THREE.BufferAttribute(pos, 3)); pg.setAttribute('aSeed', new THREE.BufferAttribute(seed, 1));
    this.petalMat = new THREE.ShaderMaterial({
      uniforms: { uTime: { value: 0 }, uScale: { value: 600 } },
      vertexShader: `attribute float aSeed; uniform float uTime; uniform float uScale; varying float vA;
        void main() {
          vec3 p = position;
          p.y = mod(p.y - uTime * (0.35 + aSeed * 0.5), 9.0);
          p.x += sin(uTime * 0.7 + aSeed * 40.0) * 1.1 + uTime * 0.25; p.x = mod(p.x + 22.0, 44.0) - 22.0;
          p.z += cos(uTime * 0.5 + aSeed * 60.0) * 0.9;
          vA = smoothstep(0.0, 0.6, p.y) * (0.6 + 0.4 * sin(uTime * 3.0 + aSeed * 90.0));
          vec4 mv = modelViewMatrix * vec4(p, 1.0);
          gl_Position = projectionMatrix * mv;
          gl_PointSize = uScale * (0.035 + aSeed * 0.035) / max(-mv.z, 0.1);
        }`,
      fragmentShader: 'precision highp float; varying float vA; void main(){ vec2 c = gl_PointCoord - 0.5; float a = smoothstep(0.5, 0.15, length(c * vec2(1.0, 1.7))); gl_FragColor = vec4(vec3(1.0, 0.55, 0.72) * a * vA * 1.3, 1.0); }',
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false,
    });
    const petals = new THREE.Points(pg, this.petalMat); petals.frustumCulled = false; g.add(petals);

    // ---- the Register board (holographic seat ranking)
    this.boardCanvas = document.createElement('canvas'); this.boardCanvas.width = 1024; this.boardCanvas.height = 768;
    this.boardTex = tex(this.boardCanvas);
    const board = new THREE.Group(); board.position.set(-9.2, 0, -1.5); board.rotation.y = 0.95; g.add(board);
    add(new THREE.CylinderGeometry(1.5, 1.7, 0.3, 24), slate, 0, 0.15, 0, board);
    const emit = add(new THREE.TorusGeometry(1.25, 0.05, 6, 40), this._glow(3), 0, 0.32, 0, board); emit.rotation.x = Math.PI / 2; emit.castShadow = false;
    for (const sx of [-1, 1]) add(new THREE.BoxGeometry(0.1, 4.2, 0.1), metal, sx * 2.45, 2.1, 0, board);
    const screen = new THREE.Mesh(new THREE.PlaneGeometry(4.7, 3.52), new THREE.MeshBasicMaterial({ map: this.boardTex, transparent: true, opacity: 0.96, side: THREE.DoubleSide, color: new THREE.Color(1.5, 1.5, 1.5) }));
    screen.position.set(0, 2.45, 0); board.add(screen);
    this.spots.register = { x: -9.2 + Math.sin(0.95) * 2.0, z: -1.5 + Math.cos(0.95) * 2.0, r: 2.6 };
    this.obstacles.push({ x: -9.2, z: -1.5, r: 1.6 });

    // ---- training hall terminal
    const tr = new THREE.Group(); tr.position.set(9.2, 0, -1.5); tr.rotation.y = -0.95; g.add(tr);
    add(new THREE.CylinderGeometry(1.5, 1.7, 0.3, 24), slate, 0, 0.15, 0, tr);
    for (const sx of [-1, 1]) add(new THREE.BoxGeometry(0.35, 3.6, 0.35), stoneDark, sx * 1.5, 1.8, 0, tr);
    add(new THREE.BoxGeometry(3.7, 0.4, 0.5), stoneDark, 0, 3.75, 0, tr);
    add(new THREE.BoxGeometry(3.0, 0.1, 0.1), this._glow(3), 0, 3.5, 0.1, tr).castShadow = false;
    const icon = new THREE.Group(); icon.position.set(0, 2.1, 0); tr.add(icon);
    for (const rz of [0.7, -0.7]) { const b = add(new THREE.BoxGeometry(0.09, 1.7, 0.05), this._glow(3.2), 0, 0, 0, icon); b.rotation.z = rz; b.castShadow = false; }
    this.trainIcon = icon;
    this.spots.training = { x: 9.2 - Math.sin(0.95) * 2.0, z: -1.5 + Math.cos(0.95) * 2.0, r: 2.6 };
    this.obstacles.push({ x: 9.2, z: -1.5, r: 1.6 });

    // ---- the Crown Gate
    const gate = new THREE.Group(); gate.position.set(0, 0, 13.4); g.add(gate);
    add(new THREE.BoxGeometry(7, 0.35, 2.2), slate, 0, 0.175, 0, gate);
    this.gateRingMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
    const gr = add(new THREE.TorusGeometry(2.7, 0.2, 10, 64), metal, 0, 3.1, 0, gate);
    const gr2 = add(new THREE.TorusGeometry(2.7, 0.07, 6, 64), this.gateRingMat, 0, 3.1, 0.2, gate); gr2.castShadow = false; void gr;
    this.gateMat = new THREE.ShaderMaterial({
      uniforms: { uTime: { value: 0 }, uColor: { value: new THREE.Color(0xff4466) }, uOpen: { value: 0 } },
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
      fragmentShader: `precision highp float; varying vec2 vUv; uniform float uTime, uOpen; uniform vec3 uColor;
        void main(){
          vec2 p = (vUv - 0.5) * 2.0; float r = length(p), a = atan(p.y, p.x);
          float swirl = sin(a * 5.0 + r * 9.0 - uTime * (1.0 + uOpen * 2.5)) * 0.5 + 0.5;
          float rim = smoothstep(0.55, 1.0, r);
          float core = smoothstep(0.9, 0.0, r) * uOpen;
          float bars = (1.0 - uOpen) * step(0.5, fract(p.x * 4.0)) * 0.25;
          float alpha = step(r, 1.0) * (0.12 + swirl * 0.35 * (0.4 + uOpen) + rim * 0.5 + core * 0.8 + bars);
          gl_FragColor = vec4(mix(uColor, vec3(1.0), core * 0.6) * alpha * 1.8, 1.0);
        }`,
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false,
    });
    const membrane = new THREE.Mesh(new THREE.CircleGeometry(2.62, 48), this.gateMat); membrane.position.set(0, 3.1, 0); gate.add(membrane);
    this.spots.gate = { x: 0, z: 11.4, r: 2.8 };
    this.obstacles.push({ x: -2.9, z: 13.4, r: 0.7 }, { x: 2.9, z: 13.4, r: 0.7 });

    // where people stand
    this.spots.proctor = { x: 6.4, z: -9.4, facing: -0.5 };
    this.spots.npc = [{ x: -5.2, z: 2.6, facing: 1.9 }, { x: 5.4, z: 3.4, facing: -1.9 }, { x: -1.2, z: -5.6, facing: 0.1 }];
    this.spots.spawn = { x: 0, z: 6.5, facing: Math.PI };
  }

  setAcademy(academy) {
    this.accent.set(academy.accent);
    for (const m of this.accentMats) m.color.copy(this.accent).lerp(new THREE.Color(1, 1, 1), 0.15).multiplyScalar(m.userData.k);
    this.plazaMat.emissive.copy(this.accent);
    this.academy = academy;
  }

  /** Redraw the holographic Register from the ladder view. */
  setBoard(view, academy) {
    const c = this.boardCanvas, x = c.getContext('2d'), w = c.width, h = c.height;
    x.clearRect(0, 0, w, h);
    x.fillStyle = 'rgba(6,12,28,0.78)'; x.fillRect(0, 0, w, h);
    x.strokeStyle = academy.css; x.lineWidth = 6; x.strokeRect(8, 8, w - 16, h - 16);
    x.fillStyle = academy.css; x.font = '700 60px "Teko", "Arial Narrow", Impact, sans-serif'; x.textBaseline = 'middle';
    x.fillText(`${academy.name.toUpperCase()}  ·  THE REGISTER`, 36, 58);
    x.fillRect(36, 96, w - 72, 3);
    const rowH = 53;
    view.forEach((v, i) => {
      const y = 132 + i * rowH;
      if (v.player) { x.fillStyle = 'rgba(255,255,255,0.16)'; x.fillRect(24, y - 24, w - 48, rowH - 4); }
      x.fillStyle = v.player ? '#ffffff' : i < 3 ? '#ffd76a' : '#c9d6f5';
      x.font = '700 44px "Teko", "Arial Narrow", Impact, sans-serif';
      x.textAlign = 'right'; x.fillText(ROMAN[i], 120, y + 3);
      x.textAlign = 'left'; x.fillText(v.name.toUpperCase() + (v.player ? '  ◄ YOU' : ''), 150, y + 3);
      x.fillStyle = v.css; x.fillRect(132, y - 18, 6, 36);
      x.fillStyle = '#8fa0c8'; x.font = '500 28px "Chakra Petch", "Trebuchet MS", sans-serif';
      x.textAlign = 'right'; x.fillText(`LV ${v.level}`, w - 40, y + 2);
      x.textAlign = 'left';
    });
    this.boardTex.needsUpdate = true;
  }

  setGate(open) {
    this.gateMat.uniforms.uOpen.value = open ? 1 : 0;
    this.gateMat.uniforms.uColor.value.set(open ? 0xffc24a : 0xff3d5c);
    this.gateRingMat.color.set(open ? 0xffc24a : 0xff3d5c).multiplyScalar(open ? 3 : 1.4);
  }

  update(dt, viewportHeight, fovDeg) {
    this.time += dt;
    const t = this.time;
    this.petalMat.uniforms.uTime.value = t;
    this.petalMat.uniforms.uScale.value = viewportHeight / (2 * Math.tan((fovDeg * Math.PI) / 360));
    this.gateMat.uniforms.uTime.value = t;
    this.crest.rotation.y = t * 0.5; this.crest.position.y = 12.2 + Math.sin(t * 0.9) * 0.15;
    this.trainIcon.rotation.y = t * 0.8;
    this.clockHand.rotation.z = -t * 0.1;
    for (const b of this.banners) b.rotation.y = Math.sin(t * 1.3 + b.userData.wave) * 0.18;
  }
}

// ------------------------------------------------------------ walking around
export class Explorer {
  constructor(scene, campus, def) {
    this.scene = scene; this.campus = campus;
    this.rig = new Rig(def);
    this.anim = new Animator(this.rig);
    this.rig.setIgnite(0);
    this.root = this.rig.root; this.pos = this.root.position;
    this.vel = new THREE.Vector3();
    const s = campus.spots.spawn;
    this.pos.set(s.x, 0, s.z); this.facing = s.facing;
    this.speed = 5.4;
    this.npcs = [];
    this.time = 0;
    this.frozen = false;
    scene.add(this.root);
    this.anim.play('relax', { blend: 0, force: true });
  }

  /** list: [{ id, def, spot, label, sub, css, hideWeapon }] */
  setNPCs(list) {
    this.clearNPCs();
    for (const n of list) {
      const rig = new Rig(n.def), anim = new Animator(rig);
      rig.setIgnite(0);
      if (n.hideWeapon) for (const w of rig.weapons) w.group.visible = false;
      rig.root.position.set(n.spot.x, 0, n.spot.z);
      const npc = { ...n, rig, anim, facing: n.spot.facing ?? 0, home: n.spot.facing ?? 0, phase: Math.random() * 10 };
      anim.play('relax', { blend: 0, force: true });
      anim.time = npc.phase;
      this.scene.add(rig.root);
      this.npcs.push(npc);
    }
  }

  clearNPCs() {
    for (const n of this.npcs) disposeRig(this.scene, n.rig);
    this.npcs.length = 0;
  }

  dispose() { this.clearNPCs(); disposeRig(this.scene, this.rig); }

  update(dt, input, camRig) {
    this.time += dt;
    let mx = 0, mz = 0;
    if (!this.frozen) {
      mx = input.x * camRig.right.x + input.y * camRig.forward.x;
      mz = input.x * camRig.right.z + input.y * camRig.forward.z;
    }
    const mag = Math.hypot(mx, mz);
    let tx = 0, tz = 0;
    if (mag > 0.15) { tx = (mx / mag) * this.speed * Math.min(1, mag); tz = (mz / mag) * this.speed * Math.min(1, mag); }
    const k = Math.min(1, 12 * dt);
    this.vel.x += (tx - this.vel.x) * k; this.vel.z += (tz - this.vel.z) * k;
    this.pos.x += this.vel.x * dt; this.pos.z += this.vel.z * dt;
    // stay on the plaza, out of the furniture and out of other people
    const r = Math.hypot(this.pos.x, this.pos.z);
    if (r > CAMPUS_RADIUS) { this.pos.x *= CAMPUS_RADIUS / r; this.pos.z *= CAMPUS_RADIUS / r; }
    const push = (ox, oz, rad) => {
      const dx = this.pos.x - ox, dz = this.pos.z - oz, d = Math.hypot(dx, dz);
      if (d < rad && d > 1e-4) { this.pos.x = ox + (dx / d) * rad; this.pos.z = oz + (dz / d) * rad; }
    };
    for (const o of this.campus.obstacles) push(o.x, o.z, o.r + 0.4);
    for (const n of this.npcs) push(n.rig.root.position.x, n.rig.root.position.z, 0.95);

    const speed = Math.hypot(this.vel.x, this.vel.z);
    if (mag > 0.15) {
      const want = Math.atan2(mx, mz), d = angDiff(this.facing, want), step = 12 * dt;
      this.facing += Math.abs(d) <= step ? d : Math.sign(d) * step;
      this.anim.play('run', { blend: 0.14 });
      this.anim.runPhase += speed * dt * 2.35;
    } else this.anim.play('relax', { blend: 0.22 });
    this.root.rotation.y = this.facing;
    this.anim.update(dt);
    this.rig.updateSecondary(dt, this.vel, this.facing, this.time);

    for (const n of this.npcs) {
      const p = n.rig.root.position, d = Math.hypot(this.pos.x - p.x, this.pos.z - p.z);
      const want = d < 6 ? Math.atan2(this.pos.x - p.x, this.pos.z - p.z) : n.home;
      n.facing += angDiff(n.facing, want) * Math.min(1, dt * 4);
      n.rig.root.rotation.y = n.facing;
      n.anim.update(dt);
      n.rig.updateSecondary(dt, ZERO, n.facing, this.time);
      n.dist = d;
    }
  }

  /** The closest thing the player could interact with, or null. */
  nearest(spots) {
    let best = null, bd = 1e9;
    for (const n of this.npcs) { if (n.dist < 2.5 && n.dist < bd) { bd = n.dist; best = { type: 'npc', npc: n }; } }
    for (const s of spots) {
      const d = Math.hypot(this.pos.x - s.x, this.pos.z - s.z);
      if (d < s.r && d < bd) { bd = d; best = { type: 'spot', spot: s }; }
    }
    return best;
  }
}

const ZERO = new THREE.Vector3();

function disposeRig(scene, rig) {
  scene.remove(rig.root);
  rig.root.traverse((o) => {
    if (!o.isMesh) return;
    if (!o.geometry.userData.shared) o.geometry.dispose();
    const m = o.material;
    if (m !== Rig._blob) { if (m.map) m.map.dispose(); m.dispose(); }
  });
}
