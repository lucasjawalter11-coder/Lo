// The Crown Arena: a floating duel platform above the academy city of Halcyon.
import * as THREE from './three.js';

export const ARENA_RADIUS = 13;      // visual floor radius
export const PLAY_RADIUS = 12.2;     // fighters are kept inside this

const TAU = Math.PI * 2;

function mulberry(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------- floor art
function drawFloorMaps(size) {
  const mk = () => { const c = document.createElement('canvas'); c.width = c.height = size; return c; };
  const albedo = mk(), emissive = mk(), orm = mk();
  const a = albedo.getContext('2d'), e = emissive.getContext('2d'), o = orm.getContext('2d');
  const c = size / 2, R = size / 2;
  const rand = mulberry(7);

  // albedo base: deep blue-black alloy with a faint radial sheen
  const g = a.createRadialGradient(c, c, 0, c, c, R);
  g.addColorStop(0, '#2c3448'); g.addColorStop(0.55, '#222a3c'); g.addColorStop(1, '#161b29');
  a.fillStyle = g; a.fillRect(0, 0, size, size);
  // roughness (G) / metalness (B)
  o.fillStyle = 'rgb(0,74,96)'; o.fillRect(0, 0, size, size);
  e.fillStyle = '#000'; e.fillRect(0, 0, size, size);

  // hex plating
  const hr = size / 44, hw = Math.sqrt(3) * hr;
  for (let row = -1; row < size / (hr * 1.5) + 1; row++) {
    for (let col = -1; col < size / hw + 1; col++) {
      const x = col * hw + (row & 1 ? hw / 2 : 0), y = row * hr * 1.5;
      const d = Math.hypot(x - c, y - c) / R;
      if (d > 1.02) continue;
      const tone = rand();
      const path = (ctx) => {
        ctx.beginPath();
        for (let i = 0; i < 6; i++) {
          const ang = Math.PI / 6 + i * Math.PI / 3;
          const px = x + Math.cos(ang) * hr * 0.96, py = y + Math.sin(ang) * hr * 0.96;
          if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py);
        }
        ctx.closePath();
      };
      path(a);
      a.fillStyle = `rgba(${150 + tone * 60}, ${170 + tone * 60}, 255, ${0.012 + tone * 0.035})`;
      a.fill();
      a.strokeStyle = 'rgba(0,0,0,0.5)'; a.lineWidth = size / 900; a.stroke();
      path(o);
      o.fillStyle = `rgb(0,${Math.round(52 + tone * 60)},${Math.round(80 + tone * 45)})`;
      o.fill();
      o.strokeStyle = 'rgb(0,150,60)'; o.lineWidth = size / 700; o.stroke();
    }
  }

  const ring = (ctx, r, w, style) => { ctx.beginPath(); ctx.arc(c, c, r * R, 0, TAU); ctx.lineWidth = w * R; ctx.strokeStyle = style; ctx.stroke(); };
  const CY = '#39d5ff', GOLD = '#ffc24a', WH = '#eaf6ff';

  // painted bands (albedo) under the lights
  ring(a, 0.955, 0.05, 'rgba(255,194,74,0.16)');
  ring(a, 0.62, 0.012, 'rgba(120,200,255,0.2)');
  ring(a, 0.30, 0.01, 'rgba(120,200,255,0.2)');

  // emissive rings
  e.shadowBlur = size / 160;
  e.shadowColor = GOLD; ring(e, 0.975, 0.008, GOLD);
  e.shadowColor = CY;
  ring(e, 0.925, 0.003, CY);
  ring(e, 0.62, 0.004, CY);
  ring(e, 0.30, 0.004, WH);
  ring(e, 0.335, 0.0015, CY);

  // ticks around the boundary
  for (let i = 0; i < 120; i++) {
    const ang = (i / 120) * TAU, major = i % 10 === 0;
    const r0 = (major ? 0.885 : 0.905) * R, r1 = 0.92 * R;
    e.beginPath();
    e.moveTo(c + Math.cos(ang) * r0, c + Math.sin(ang) * r0);
    e.lineTo(c + Math.cos(ang) * r1, c + Math.sin(ang) * r1);
    e.lineWidth = (major ? 0.004 : 0.0018) * R; e.strokeStyle = major ? GOLD : CY; e.shadowColor = e.strokeStyle; e.stroke();
  }

  // segmented arcs between rings
  e.shadowColor = CY;
  for (let i = 0; i < 6; i++) {
    const a0 = (i / 6) * TAU + 0.12, a1 = ((i + 1) / 6) * TAU - 0.12;
    e.beginPath(); e.arc(c, c, 0.78 * R, a0, a1); e.lineWidth = 0.0025 * R; e.strokeStyle = 'rgba(57,213,255,0.85)'; e.stroke();
    e.beginPath(); e.arc(c, c, 0.47 * R, a0 + 0.2, a1 - 0.2); e.lineWidth = 0.002 * R; e.strokeStyle = 'rgba(57,213,255,0.6)'; e.stroke();
  }
  // spokes
  for (let i = 0; i < 6; i++) {
    const ang = (i / 6) * TAU + TAU / 12;
    e.beginPath();
    e.moveTo(c + Math.cos(ang) * 0.335 * R, c + Math.sin(ang) * 0.335 * R);
    e.lineTo(c + Math.cos(ang) * 0.62 * R, c + Math.sin(ang) * 0.62 * R);
    e.lineWidth = 0.0018 * R; e.strokeStyle = 'rgba(57,213,255,0.5)'; e.stroke();
  }

  // center crest: a six-point crown star
  const star = (ctx, rOut, rIn, n, rot) => {
    ctx.beginPath();
    for (let i = 0; i < n * 2; i++) {
      const rr = (i & 1 ? rIn : rOut) * R, ang = rot + (i / (n * 2)) * TAU;
      const px = c + Math.cos(ang) * rr, py = c + Math.sin(ang) * rr;
      if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py);
    }
    ctx.closePath();
  };
  star(a, 0.27, 0.12, 6, -Math.PI / 2); a.fillStyle = 'rgba(255,194,74,0.10)'; a.fill();
  e.shadowColor = GOLD; e.shadowBlur = size / 120;
  star(e, 0.27, 0.115, 6, -Math.PI / 2); e.lineWidth = 0.005 * R; e.strokeStyle = GOLD; e.stroke();
  star(e, 0.17, 0.075, 6, -Math.PI / 2 + Math.PI / 6); e.lineWidth = 0.003 * R; e.strokeStyle = WH; e.shadowColor = WH; e.stroke();
  e.beginPath(); e.arc(c, c, 0.035 * R, 0, TAU); e.fillStyle = WH; e.fill();

  // lettering around the outer band
  const text = 'HALCYON  CROWN  TRIALS   ✦   ';
  e.shadowBlur = size / 300; e.shadowColor = GOLD; e.fillStyle = 'rgba(255,205,110,0.95)';
  e.font = `600 ${Math.round(0.03 * R)}px "Chakra Petch", "Trebuchet MS", sans-serif`;
  e.textAlign = 'center'; e.textBaseline = 'middle';
  const chars = (text + text + text).split('');
  chars.forEach((ch, i) => {
    const ang = (i / chars.length) * TAU - Math.PI / 2;
    e.save();
    e.translate(c + Math.cos(ang) * 0.845 * R, c + Math.sin(ang) * 0.845 * R);
    e.rotate(ang + Math.PI / 2);
    e.fillText(ch, 0, 0);
    e.restore();
  });

  // start pads for the two duelists (along the canvas Y axis = world Z)
  for (const s of [-1, 1]) {
    const py = c + s * 0.27 * R * 1.0;
    e.shadowColor = CY; e.strokeStyle = CY; e.lineWidth = 0.003 * R;
    e.beginPath(); e.moveTo(c - 0.05 * R, py + s * 0.03 * R); e.lineTo(c, py + s * 0.055 * R); e.lineTo(c + 0.05 * R, py + s * 0.03 * R); e.stroke();
  }
  return { albedo, emissive, orm };
}

function canvasTex(canvas, srgb) {
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  t.anisotropy = 8;
  t.generateMipmaps = true;
  t.minFilter = THREE.LinearMipmapLinearFilter;
  return t;
}

// ---------------------------------------------------------------- shaders
const SKY_VERT = /* glsl */ `
varying vec3 vDir;
void main() {
  vDir = normalize(position);
  vec4 p = projectionMatrix * mat4(mat3(modelViewMatrix)) * vec4(position, 1.0);
  gl_Position = p.xyww;
}
`;
const SKY_FRAG = /* glsl */ `
precision highp float;
varying vec3 vDir;
uniform float uTime;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 17.0; a *= 0.5; } return v; }
void main() {
  vec3 d = normalize(vDir);
  float h = clamp(d.y, -1.0, 1.0);
  vec3 sunDir = normalize(vec3(-0.55, 0.06, -0.83));
  float sunAmt = max(dot(d, sunDir), 0.0);
  // dusk gradient
  vec3 zenith = vec3(0.012, 0.018, 0.06);
  vec3 mid = vec3(0.06, 0.035, 0.16);
  vec3 horizon = vec3(0.42, 0.13, 0.30);
  float t = pow(1.0 - max(h, 0.0), 3.0);
  vec3 col = mix(zenith, mid, smoothstep(0.0, 0.55, t));
  col = mix(col, horizon, smoothstep(0.45, 1.0, t));
  // afterglow where the sun went down
  col += vec3(1.3, 0.42, 0.12) * pow(sunAmt, 6.0) * smoothstep(0.35, 0.0, h) * 0.9;
  col += vec3(1.0, 0.3, 0.35) * pow(sunAmt, 2.0) * smoothstep(0.5, 0.0, h) * 0.22;
  // below horizon: city haze
  col = mix(col, vec3(0.05, 0.035, 0.11), smoothstep(0.0, -0.25, h));
  // stars
  vec2 sp = vec2(atan(d.z, d.x), asin(h)) * 180.0;
  vec2 cell = floor(sp); vec2 f = fract(sp) - 0.5;
  float rnd = hash(cell);
  float star = step(0.965, rnd) * smoothstep(0.32, 0.0, length(f + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5));
  star *= 0.6 + 0.4 * sin(uTime * (1.0 + rnd * 3.0) + rnd * 40.0);
  col += vec3(0.8, 0.9, 1.0) * star * smoothstep(0.02, 0.4, h) * 1.6;
  // aurora ribbons
  float band = fbm(vec2(atan(d.z, d.x) * 2.2 + uTime * 0.015, h * 5.0 - uTime * 0.01));
  float aur = smoothstep(0.5, 0.85, band) * smoothstep(0.08, 0.3, h) * smoothstep(0.85, 0.35, h);
  col += mix(vec3(0.1, 0.9, 0.75), vec3(0.6, 0.25, 1.0), smoothstep(0.2, 0.7, h)) * aur * 0.22;
  // thin cloud streaks near the horizon
  float cl = fbm(vec2(atan(d.z, d.x) * 3.0, h * 22.0));
  col = mix(col, col * 0.45 + vec3(0.25, 0.08, 0.16) * 0.5, smoothstep(0.55, 0.8, cl) * smoothstep(0.3, 0.02, abs(h - 0.07)));
  // moon
  vec3 moonDir = normalize(vec3(0.62, 0.42, -0.66));
  float md = distance(d, moonDir);
  float disc = smoothstep(0.085, 0.08, md);
  float crater = fbm(d.xy * 38.0);
  col = mix(col, vec3(1.25, 1.3, 1.5) * (0.72 + 0.28 * crater), disc);
  col += vec3(0.35, 0.45, 0.8) * (0.012 / (md * md + 0.01)) * 0.5;
  gl_FragColor = vec4(col, 1.0);
}
`;

const BARRIER_VERT = /* glsl */ `
varying vec2 vUv;
varying vec3 vWorld;
void main() {
  vUv = uv;
  vec4 w = modelMatrix * vec4(position, 1.0);
  vWorld = w.xyz;
  gl_Position = projectionMatrix * viewMatrix * w;
}
`;
const BARRIER_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
varying vec3 vWorld;
uniform float uTime;
uniform vec3 uColor;
uniform vec4 uPulse[4];   // xyz = world position, w = age (seconds)
uniform float uPower;
float hexDist(vec2 p) { p = abs(p); return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x); }
vec4 hexCoords(vec2 uv) {
  vec2 r = vec2(1.0, 1.7320508), h = r * 0.5;
  vec2 a = mod(uv, r) - h, b = mod(uv - h, r) - h;
  vec2 gv = dot(a, a) < dot(b, b) ? a : b;
  return vec4(gv, uv - gv);
}
void main() {
  vec2 uv = vec2(vUv.x * 72.0, vUv.y * 6.2);
  vec4 hc = hexCoords(uv);
  float edge = smoothstep(0.42, 0.5, hexDist(hc.xy));
  float cellRnd = fract(sin(dot(hc.zw, vec2(12.9898, 78.233))) * 43758.5453);
  float flicker = smoothstep(0.93, 1.0, sin(uTime * 0.9 + cellRnd * 60.0) * 0.5 + 0.5);
  float base = smoothstep(0.55, 0.0, vUv.y);                 // strongest near the floor
  float sweep = smoothstep(0.06, 0.0, abs(fract(vUv.y * 1.0 - uTime * 0.11) - 0.5) - 0.02);
  float a = edge * (0.01 + base * 0.07) + flicker * 0.035 * (0.3 + base) + sweep * 0.012;
  // impact ripples
  float ripple = 0.0;
  for (int i = 0; i < 4; i++) {
    float age = uPulse[i].w;
    if (age < 1.2) {
      float d = distance(vWorld, uPulse[i].xyz);
      float ring = smoothstep(0.9, 0.0, abs(d - age * 9.0));
      ripple += ring * (1.0 - age / 1.2) * (0.35 + edge * 1.4);
      ripple += smoothstep(3.0, 0.0, d) * (1.0 - age / 1.2) * 0.5;
    }
  }
  a = a * uPower + ripple;
  float top = smoothstep(1.0, 0.8, vUv.y);
  gl_FragColor = vec4(uColor * a * top * 2.0, 1.0);
}
`;

const CROWD_VERT = /* glsl */ `
attribute vec3 aColor;
attribute float aSeed;
uniform float uTime;
uniform float uHype;
uniform float uScale;
varying vec3 vColor;
void main() {
  vec3 p = position;
  float bob = sin(uTime * (2.0 + aSeed * 3.0) + aSeed * 50.0);
  p.y += bob * (0.08 + uHype * 0.35);
  float ang = atan(p.z, p.x);
  float wave = smoothstep(0.75, 1.0, sin(ang * 2.0 - uTime * 0.8 + aSeed * 0.4));
  float tw = 0.55 + 0.45 * sin(uTime * (1.5 + aSeed * 5.0) + aSeed * 90.0);
  vColor = aColor * (0.16 + tw * 0.5 + wave * 1.1 + uHype * 1.8);
  vec4 mv = modelViewMatrix * vec4(p, 1.0);
  gl_Position = projectionMatrix * mv;
  gl_PointSize = max(1.5, uScale * (0.10 + aSeed * 0.08) / max(-mv.z, 0.1));
}
`;
const CROWD_FRAG = /* glsl */ `
precision highp float;
varying vec3 vColor;
void main() {
  vec2 c = gl_PointCoord - 0.5;
  float a = smoothstep(0.5, 0.05, length(c));
  gl_FragColor = vec4(vColor * a, 1.0);
}
`;

const CITY_VERT = /* glsl */ `
varying vec3 vWorld;
varying vec3 vNormalW;
varying float vTop;
varying float vFogDepth;
attribute float aSeed;
varying float vSeed;
void main() {
  vec4 w = modelMatrix * instanceMatrix * vec4(position, 1.0);
  vWorld = w.xyz;
  vNormalW = normalize(mat3(modelMatrix * instanceMatrix) * normal);
  vTop = position.y;
  vSeed = aSeed;
  vec4 mv = viewMatrix * w;
  vFogDepth = -mv.z;
  gl_Position = projectionMatrix * mv;
}
`;
const CITY_FRAG = /* glsl */ `
precision highp float;
varying vec3 vWorld;
varying vec3 vNormalW;
varying float vTop;
varying float vFogDepth;
varying float vSeed;
uniform vec3 uFogColor;
uniform float uFogDensity;
uniform float uTime;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void main() {
  vec3 n = normalize(vNormalW);
  vec3 base = vec3(0.018, 0.022, 0.04) + vec3(0.03, 0.02, 0.05) * max(n.y, 0.0);
  // sunset rim on faces turned toward the afterglow
  float sun = max(dot(n, normalize(vec3(-0.55, 0.1, -0.83))), 0.0);
  base += vec3(0.5, 0.16, 0.12) * sun * 0.22;
  vec3 col = base;
  if (abs(n.y) < 0.5) {
    float along = abs(n.x) > 0.5 ? vWorld.z : vWorld.x;
    vec2 wuv = vec2(along / 5.0, vWorld.y / 6.0);
    vec2 cell = floor(wuv), f = fract(wuv);
    float lit = step(0.6 + 0.3 * fract(vSeed * 7.3), hash(cell + vSeed * 91.0));
    float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.8);
    vec3 warm = mix(vec3(1.0, 0.72, 0.38), vec3(0.45, 0.8, 1.0), step(0.6, hash(cell * 1.7 + vSeed)));
    col += warm * win * lit * (0.2 + 0.45 * hash(cell + 5.0));
    // neon trim bands
    float band = step(0.985, fract(vWorld.y / 46.0 + vSeed));
    vec3 neon = mix(vec3(0.1, 0.9, 1.0), vec3(1.0, 0.2, 0.7), step(0.5, fract(vSeed * 3.7)));
    col += neon * band * 1.6;
  }
  // beacon at the crown of each tower
  col += vec3(1.0, 0.25, 0.3) * smoothstep(0.985, 1.0, vTop) * (0.5 + 0.5 * sin(uTime * 2.0 + vSeed * 40.0)) * 2.0;
  float fog = 1.0 - exp(-uFogDensity * uFogDensity * vFogDepth * vFogDepth);
  col = mix(col, uFogColor, clamp(fog, 0.0, 1.0));
  gl_FragColor = vec4(col, 1.0);
}
`;

const BEAM_VERT = /* glsl */ `
varying vec2 vUv;
varying vec3 vView;
varying vec3 vNormalV;
void main() {
  vUv = uv;
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  vView = -mv.xyz;
  vNormalV = normalMatrix * normal;
  gl_Position = projectionMatrix * mv;
}
`;
const BEAM_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
varying vec3 vView;
varying vec3 vNormalV;
uniform vec3 uColor;
uniform float uIntensity;
void main() {
  float facing = abs(dot(normalize(vNormalV), normalize(vView)));
  float a = pow(facing, 2.5) * smoothstep(0.0, 0.08, vUv.y) * pow(1.0 - vUv.y, 1.6);
  gl_FragColor = vec4(uColor * a * uIntensity, 1.0);
}
`;

const SCREEN_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
uniform sampler2D tMap;
uniform float uTime;
void main() {
  vec2 uv = vUv;
  vec3 c = texture2D(tMap, uv).rgb;
  float scan = 0.82 + 0.18 * sin(uv.y * 420.0 + uTime * 6.0);
  float roll = smoothstep(0.02, 0.0, abs(fract(uv.y - uTime * 0.07) - 0.5) - 0.47) * 0.25;
  float edge = smoothstep(0.0, 0.03, uv.x) * smoothstep(1.0, 0.97, uv.x) * smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.94, uv.y);
  gl_FragColor = vec4(c * (scan + roll) * edge * 1.9, 1.0);
}
`;

// ---------------------------------------------------------------- build
export class Arena {
  constructor(scene, gfx) {
    this.scene = scene;
    this.gfx = gfx;
    this.time = 0;
    this.hype = 0;
    this.pulses = [0, 1, 2, 3].map(() => new THREE.Vector4(0, 0, 0, 99));
    this.pulseIdx = 0;
    this.updaters = [];
    this.group = new THREE.Group();
    scene.add(this.group);

    scene.fog = new THREE.FogExp2(0x0b0a1c, 0.0032);
    scene.background = new THREE.Color(0x05060d);

    this._buildSky();
    this._buildEnvironment();
    this._buildLights();
    this._buildFloor();
    this._buildBarrier();
    this._buildStands();
    this._buildPylons();
    this._buildScreens();
    this._buildCity();
    this._buildHaloRings();
    this._buildMotes();
  }

  _buildSky() {
    this.skyMat = new THREE.ShaderMaterial({
      vertexShader: SKY_VERT, fragmentShader: SKY_FRAG, uniforms: { uTime: { value: 0 } },
      side: THREE.BackSide, depthWrite: false, depthTest: true, fog: false,
    });
    const sky = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 20), this.skyMat);
    sky.frustumCulled = false;
    sky.renderOrder = -10;
    this.group.add(sky);
  }

  _buildEnvironment() {
    // A small light-card scene baked to a PMREM so PBR surfaces have something rich to reflect.
    const env = new THREE.Scene();
    const sky = new THREE.Mesh(new THREE.SphereGeometry(50, 32, 16), this.skyMat.clone());
    env.add(sky);
    const card = (color, intensity, w, h, pos) => {
      const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), side: THREE.DoubleSide }));
      m.position.copy(pos); m.lookAt(0, 0, 0); env.add(m);
    };
    card(0xdfe8ff, 9, 14, 6, new THREE.Vector3(10, 22, 8));       // key
    card(0x35c9ff, 6, 10, 10, new THREE.Vector3(26, 6, 14));       // cyan rim
    card(0xff3d9a, 6, 10, 10, new THREE.Vector3(-26, 6, -14));     // magenta rim
    card(0xffb45a, 4, 30, 3, new THREE.Vector3(-20, 3, -30));      // sunset strip
    for (let i = 0; i < 10; i++) {                                 // ring of stadium lamps
      const a = (i / 10) * TAU;
      card(i % 2 ? 0x9fd8ff : 0xffe1b0, 5, 3, 1.2, new THREE.Vector3(Math.cos(a) * 34, 15, Math.sin(a) * 34));
    }
    const pmrem = new THREE.PMREMGenerator(this.gfx.renderer);
    const rt = pmrem.fromScene(env, 0.03, 0.1, 100);
    this.scene.environment = rt.texture;
    this.scene.environmentIntensity = 0.55;
    pmrem.dispose();
    env.traverse((o) => { if (o.geometry) o.geometry.dispose(); });
  }

  _buildLights() {
    const hemi = new THREE.HemisphereLight(0x9bb8ff, 0x1c1226, 0.55);
    this.group.add(hemi);

    const key = new THREE.DirectionalLight(0xe6edff, 3.2);
    key.position.set(9, 20, 7);
    key.target.position.set(0, 0, 0);
    key.castShadow = true;
    const sc = key.shadow.camera;
    sc.left = -15; sc.right = 15; sc.top = 15; sc.bottom = -15; sc.near = 2; sc.far = 48;
    key.shadow.bias = -0.0005;
    key.shadow.normalBias = 0.03;
    key.shadow.radius = 3;
    this.group.add(key, key.target);
    this.keyLight = key;
    this.gfx.registerShadowLight(key);

    const rimA = new THREE.PointLight(0xff3d9a, 320, 70, 1.8);
    rimA.position.set(-17, 7.5, -11);
    const rimB = new THREE.PointLight(0x35c9ff, 320, 70, 1.8);
    rimB.position.set(17, 7.5, 11);
    this.group.add(rimA, rimB);
    this.rimA = rimA; this.rimB = rimB;
  }

  _buildFloor() {
    const maps = drawFloorMaps(2048);
    const albedo = canvasTex(maps.albedo, true), emissive = canvasTex(maps.emissive, true), orm = canvasTex(maps.orm, false);
    const refl = this.gfx.reflection;
    const mat = new THREE.MeshStandardMaterial({
      map: albedo, emissiveMap: emissive, emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 2.2,
      roughnessMap: orm, metalnessMap: orm, roughness: 1.0, metalness: 1.0, envMapIntensity: 0.7,
    });
    mat.onBeforeCompile = (shader) => {
      shader.uniforms.tReflect = refl.texture;
      shader.uniforms.tReflectBlur = refl.blurTexture;
      shader.uniforms.uReflMatrix = refl.matrix;
      shader.uniforms.uReflStrength = refl.strength;
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nuniform mat4 uReflMatrix;\nvarying vec4 vReflUv;\nvarying vec3 vFloorWorld;')
        .replace('#include <project_vertex>', '#include <project_vertex>\nvec4 floorWp = modelMatrix * vec4(transformed, 1.0);\nvFloorWorld = floorWp.xyz;\nvReflUv = uReflMatrix * floorWp;');
      shader.fragmentShader = shader.fragmentShader
        .replace('#include <common>', `#include <common>
uniform sampler2D tReflect;
uniform sampler2D tReflectBlur;
uniform float uReflStrength;
varying vec4 vReflUv;
varying vec3 vFloorWorld;
`)
        .replace('#include <opaque_fragment>', `
{
  vec2 ruv = vReflUv.xy / max(vReflUv.w, 1e-4);
  float rr = roughnessFactor;
  vec3 sharp = texture2D(tReflect, ruv).rgb;
  vec3 soft = texture2D(tReflectBlur, ruv).rgb;
  vec3 refl = min(mix(sharp, soft, clamp(0.35 + rr * 1.6, 0.0, 1.0)), vec3(24.0));
  float fres = pow(1.0 - saturate(dot(normalize(vViewPosition), normal)), 3.0);
  float k = mix(0.16, 0.85, fres) * (1.0 - rr * 0.9) * uReflStrength;
  outgoingLight = outgoingLight * (1.0 - 0.3 * uReflStrength * (1.0 - rr)) + refl * k;
}
#include <opaque_fragment>`);
    };
    const floor = new THREE.Mesh(new THREE.CircleGeometry(ARENA_RADIUS, 128), mat);
    floor.rotation.x = -Math.PI / 2;
    floor.receiveShadow = true;
    floor.layers.set(1);
    this.group.add(floor);
    this.floor = floor;
    this.floorMat = mat;

    // glowing rim + platform body (below the floor plane: main camera only)
    const rimMat = new THREE.MeshStandardMaterial({ color: 0x0c0f18, emissive: 0xffb23e, emissiveIntensity: 3.0, roughness: 0.4, metalness: 0.8 });
    const rim = new THREE.Mesh(new THREE.TorusGeometry(ARENA_RADIUS + 0.06, 0.06, 8, 160), rimMat);
    rim.rotation.x = Math.PI / 2; rim.position.y = -0.02; rim.layers.set(1);
    this.group.add(rim);
    this.rimMat = rimMat;

    const hull = new THREE.MeshStandardMaterial({ color: 0x10141f, roughness: 0.55, metalness: 0.85 });
    const body = new THREE.Mesh(new THREE.CylinderGeometry(ARENA_RADIUS + 0.12, ARENA_RADIUS - 2.5, 3.2, 96, 1, true), hull);
    body.position.y = -1.62; body.layers.set(1);
    this.group.add(body);

    // moat between platform and stands with light vents
    const moat = new THREE.Mesh(new THREE.RingGeometry(ARENA_RADIUS - 2.6, 17.4, 96, 1), new THREE.MeshStandardMaterial({ color: 0x070910, roughness: 0.8, metalness: 0.4 }));
    moat.rotation.x = -Math.PI / 2; moat.position.y = -3.2; moat.layers.set(1);
    this.group.add(moat);
    const ventMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(0x35c9ff).multiplyScalar(1.6) });
    const vents = new THREE.Mesh(new THREE.TorusGeometry(15.3, 0.05, 6, 120), ventMat);
    vents.rotation.x = Math.PI / 2; vents.position.y = -3.1; vents.layers.set(1);
    this.group.add(vents);
    const wall = new THREE.Mesh(new THREE.CylinderGeometry(17.4, 17.4, 3.2, 96, 1, true), new THREE.MeshStandardMaterial({ color: 0x0d1019, roughness: 0.6, metalness: 0.7, side: THREE.BackSide }));
    wall.position.y = -1.6; wall.layers.set(1);
    this.group.add(wall);
  }

  _buildBarrier() {
    this.barrierMat = new THREE.ShaderMaterial({
      vertexShader: BARRIER_VERT, fragmentShader: BARRIER_FRAG,
      uniforms: {
        uTime: { value: 0 }, uColor: { value: new THREE.Color(0x49c8ff) }, uPulse: { value: this.pulses }, uPower: { value: 1.0 },
      },
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false,
    });
    const b = new THREE.Mesh(new THREE.CylinderGeometry(ARENA_RADIUS + 0.1, ARENA_RADIUS + 0.1, 7, 128, 1, true), this.barrierMat);
    b.position.y = 3.5;
    b.renderOrder = 5;
    this.group.add(b);
    this.barrier = b;
  }

  _buildStands() {
    // tiered bowl (everything here is at or above y = 0 so it can appear in reflections)
    const pts = [];
    const tiers = 12, r0 = 17.4, r1 = 37, y0 = 0.0, y1 = 8.6;
    pts.push(new THREE.Vector2(r0, y0));
    pts.push(new THREE.Vector2(r0, y0 + 1.5));
    for (let i = 0; i < tiers; i++) {
      const ra = r0 + 0.6 + (i / tiers) * (r1 - r0 - 0.6), rb = r0 + 0.6 + ((i + 1) / tiers) * (r1 - r0 - 0.6);
      const ya = y0 + 1.5 + (i / tiers) * (y1 - 1.5), yb = y0 + 1.5 + ((i + 1) / tiers) * (y1 - 1.5);
      pts.push(new THREE.Vector2(ra, ya), new THREE.Vector2(rb, ya), new THREE.Vector2(rb, yb));
    }
    pts.push(new THREE.Vector2(r1 + 1.5, y1 + 1.2), new THREE.Vector2(r1 + 3.5, y1 + 1.2), new THREE.Vector2(r1 + 5, y0 - 30));
    const standMat = new THREE.MeshStandardMaterial({ color: 0x0c0e18, roughness: 0.75, metalness: 0.5, side: THREE.DoubleSide, flatShading: true });
    const stands = new THREE.Mesh(new THREE.LatheGeometry(pts, 72), standMat);
    this.group.add(stands);

    // light strips on the inner wall and the bowl's crown
    const strip = (r, y, color, tube, intensity) => {
      const m = new THREE.Mesh(new THREE.TorusGeometry(r, tube, 6, 160), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity) }));
      m.rotation.x = Math.PI / 2; m.position.y = y; this.group.add(m); return m;
    };
    strip(r0 - 0.02, 1.38, 0x35c9ff, 0.045, 2.2);
    strip(r0 - 0.02, 0.5, 0xff3d9a, 0.03, 1.6);
    strip(r1 + 2.5, y1 + 1.35, 0xffc24a, 0.12, 2.4);
    strip(27, y1 * 0.5 + 0.55, 0x35c9ff, 0.04, 1.4);

    // the crowd: thousands of light sticks
    const N = 7000, rand = mulberry(99);
    const pos = new Float32Array(N * 3), col = new Float32Array(N * 3), seed = new Float32Array(N);
    const palette = [[0.3, 0.85, 1.0], [1.0, 0.3, 0.65], [1.0, 0.8, 0.35], [0.9, 0.95, 1.0], [0.55, 0.4, 1.0]];
    for (let i = 0; i < N; i++) {
      const a = rand() * TAU, tier = Math.floor(rand() * tiers), tt = (tier + 0.2 + rand() * 0.6) / tiers;
      const r = r0 + 0.6 + tt * (r1 - r0 - 0.6), y = y0 + 1.5 + (tier / tiers) * (y1 - 1.5) + 0.75 + rand() * 0.35;
      pos[i * 3] = Math.cos(a) * r; pos[i * 3 + 1] = y; pos[i * 3 + 2] = Math.sin(a) * r;
      const section = Math.floor(((a / TAU) * 12)) % palette.length;
      const p = rand() < 0.6 ? palette[section] : palette[Math.floor(rand() * palette.length)];
      col[i * 3] = p[0]; col[i * 3 + 1] = p[1]; col[i * 3 + 2] = p[2];
      seed[i] = rand();
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('aColor', new THREE.BufferAttribute(col, 3));
    geo.setAttribute('aSeed', new THREE.BufferAttribute(seed, 1));
    this.crowdMat = new THREE.ShaderMaterial({
      vertexShader: CROWD_VERT, fragmentShader: CROWD_FRAG,
      uniforms: { uTime: { value: 0 }, uHype: { value: 0 }, uScale: { value: 600 } },
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false,
    });
    const crowd = new THREE.Points(geo, this.crowdMat);
    crowd.frustumCulled = false;
    this.group.add(crowd);
  }

  _buildPylons() {
    const metal = new THREE.MeshStandardMaterial({ color: 0x161b29, roughness: 0.35, metalness: 0.9 });
    this.beams = [];
    const coneGeo = new THREE.CylinderGeometry(4.2, 0.25, 60, 24, 1, true);
    coneGeo.translate(0, 30, 0);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * TAU + TAU / 12, x = Math.cos(a) * 15.4, z = Math.sin(a) * 15.4;
      const g = new THREE.Group();
      g.position.set(x, 0, z);
      g.rotation.y = -a;
      const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.42, 8.2, 8), metal);
      shaft.position.y = 4.1; g.add(shaft);
      const below = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.6, 3.2, 8), metal);
      below.position.y = -1.6; below.layers.set(1); g.add(below);
      const head = new THREE.Mesh(new THREE.OctahedronGeometry(0.55, 0), metal);
      head.position.y = 8.5; head.scale.set(1, 1.5, 1); g.add(head);
      const color = i % 2 ? 0xff3d9a : 0x35c9ff;
      const glow = new THREE.Mesh(new THREE.BoxGeometry(0.06, 6.5, 0.2), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(2.6) }));
      glow.position.set(-0.3, 4.2, 0); g.add(glow);
      const orb = new THREE.Mesh(new THREE.SphereGeometry(0.2, 12, 8), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(4) }));
      orb.position.y = 9.45; g.add(orb);
      const beamMat = new THREE.ShaderMaterial({
        vertexShader: BEAM_VERT, fragmentShader: BEAM_FRAG,
        uniforms: { uColor: { value: new THREE.Color(color) }, uIntensity: { value: 0.55 } },
        transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false,
      });
      const beam = new THREE.Mesh(coneGeo, beamMat);
      beam.position.y = 9.4;
      beam.renderOrder = 4;
      g.add(beam);
      this.beams.push({ mesh: beam, phase: i * 1.7, mat: beamMat });
      this.group.add(g);
    }
  }

  _buildScreens() {
    this.screenCanvas = document.createElement('canvas');
    this.screenCanvas.width = 1024; this.screenCanvas.height = 384;
    this.screenTex = new THREE.CanvasTexture(this.screenCanvas);
    this.screenTex.colorSpace = THREE.SRGBColorSpace;
    this.screenMat = new THREE.ShaderMaterial({
      vertexShader: BARRIER_VERT, fragmentShader: SCREEN_FRAG,
      uniforms: { tMap: { value: this.screenTex }, uTime: { value: 0 } }, side: THREE.DoubleSide, fog: false,
    });
    const frameMat = new THREE.MeshStandardMaterial({ color: 0x0b0d16, roughness: 0.4, metalness: 0.9 });
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * TAU + TAU / 8;
      const g = new THREE.Group();
      g.position.set(Math.cos(a) * 43, 17.5, Math.sin(a) * 43);
      g.lookAt(0, 4, 0);
      const screen = new THREE.Mesh(new THREE.PlaneGeometry(22, 8.25), this.screenMat);
      const frame = new THREE.Mesh(new THREE.BoxGeometry(23, 9.2, 0.5), frameMat);
      frame.position.z = -0.3;
      g.add(frame, screen);
      this.group.add(g);
    }
    this.setScreen({ title: 'CROWN TRIALS', left: 'HALCYON', right: 'CLASH', leftColor: '#39d5ff', rightColor: '#ff4f9a' });
  }

  /** Update the stadium jumbotrons. */
  setScreen({ title, left, right, leftColor, rightColor, center = 'VS' }) {
    const c = this.screenCanvas, x = c.getContext('2d'), w = c.width, h = c.height;
    const g = x.createLinearGradient(0, 0, w, 0);
    g.addColorStop(0, '#07101f'); g.addColorStop(0.5, '#0d0a1c'); g.addColorStop(1, '#1b0714');
    x.fillStyle = g; x.fillRect(0, 0, w, h);
    x.globalAlpha = 0.5;
    x.fillStyle = leftColor; x.beginPath(); x.moveTo(0, 0); x.lineTo(w * 0.42, 0); x.lineTo(w * 0.34, h); x.lineTo(0, h); x.fill();
    x.fillStyle = rightColor; x.beginPath(); x.moveTo(w, 0); x.lineTo(w * 0.66, 0); x.lineTo(w * 0.58, h); x.lineTo(w, h); x.fill();
    x.globalAlpha = 1;
    x.textAlign = 'center'; x.textBaseline = 'middle';
    x.fillStyle = '#ffd36b';
    x.font = '600 44px "Chakra Petch", "Trebuchet MS", sans-serif';
    x.fillText(title, w / 2, 52);
    x.fillStyle = '#ffffff';
    x.font = 'italic 700 150px "Teko", "Arial Narrow", Impact, sans-serif';
    x.fillText(center, w / 2, h / 2 + 40);
    x.font = 'italic 700 118px "Teko", "Arial Narrow", Impact, sans-serif';
    x.fillText(left, w * 0.2, h / 2 + 34, w * 0.34);
    x.fillText(right, w * 0.8, h / 2 + 34, w * 0.34);
    this.screenTex.needsUpdate = true;
  }

  _buildCity() {
    const rand = mulberry(2024);
    const N = 300;
    const geo = new THREE.BoxGeometry(1, 1, 1);
    geo.translate(0, 0.5, 0);
    const seeds = new Float32Array(N);
    this.cityMat = new THREE.ShaderMaterial({
      vertexShader: CITY_VERT, fragmentShader: CITY_FRAG,
      uniforms: { uFogColor: { value: new THREE.Color(0x140c26) }, uFogDensity: { value: 0.0026 }, uTime: { value: 0 } },
    });
    const mesh = new THREE.InstancedMesh(geo, this.cityMat, N);
    const m = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), p = new THREE.Vector3();
    for (let i = 0; i < N; i++) {
      const a = rand() * TAU, ring = rand();
      const r = 170 + ring * ring * 560;
      const w = 14 + rand() * 30, d = 14 + rand() * 30;
      const tall = rand() < 0.12;
      const h = (tall ? 300 + rand() * 200 : 150 + rand() * 130) * (0.8 + ring * 0.7);
      p.set(Math.cos(a) * r, -190, Math.sin(a) * r);
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), rand() * TAU);
      s.set(w, h, d);
      m.compose(p, q, s);
      mesh.setMatrixAt(i, m);
      seeds[i] = rand();
    }
    geo.setAttribute('aSeed', new THREE.InstancedBufferAttribute(seeds, 1));
    mesh.frustumCulled = false;
    this.group.add(mesh);
  }

  _buildHaloRings() {
    // Halcyon's signature: vast light rings turning slowly around the stadium
    this.halos = [];
    const mk = (r, tube, color, intensity, tilt, speed) => {
      const mesh = new THREE.Mesh(new THREE.TorusGeometry(r, tube, 6, 220), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), fog: false }));
      const g = new THREE.Group();
      g.rotation.set(tilt[0], 0, tilt[1]);
      mesh.rotation.x = Math.PI / 2;
      g.add(mesh); g.position.y = 22;
      this.group.add(g);
      this.halos.push({ mesh, speed });
      // beads travelling on the ring
      for (let i = 0; i < 5; i++) {
        const bead = new THREE.Mesh(new THREE.SphereGeometry(tube * 4, 8, 6), mesh.material);
        const a = (i / 5) * TAU; bead.position.set(Math.cos(a) * r, Math.sin(a) * r, 0);
        mesh.add(bead);
      }
    };
    mk(62, 0.22, 0x49c8ff, 1.8, [0.22, 0.1], 0.03);
    mk(74, 0.16, 0xffc24a, 1.6, [-0.3, -0.16], -0.022);
    mk(90, 0.12, 0xff4f9a, 1.4, [0.12, 0.34], 0.015);
  }

  _buildMotes() {
    // drifting light motes over the arena
    const N = 260, rand = mulberry(5);
    const pos = new Float32Array(N * 3), seed = new Float32Array(N), col = new Float32Array(N * 3);
    for (let i = 0; i < N; i++) {
      const a = rand() * TAU, r = Math.sqrt(rand()) * 16;
      pos[i * 3] = Math.cos(a) * r; pos[i * 3 + 1] = rand() * 9; pos[i * 3 + 2] = Math.sin(a) * r;
      seed[i] = rand();
      const c = rand() < 0.5 ? [0.4, 0.85, 1.0] : [1.0, 0.75, 0.4];
      col[i * 3] = c[0]; col[i * 3 + 1] = c[1]; col[i * 3 + 2] = c[2];
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('aSeed', new THREE.BufferAttribute(seed, 1));
    geo.setAttribute('aColor', new THREE.BufferAttribute(col, 3));
    this.moteMat = new THREE.ShaderMaterial({
      vertexShader: /* glsl */ `
        attribute float aSeed; attribute vec3 aColor; uniform float uTime; uniform float uScale; varying vec3 vColor;
        void main() {
          vec3 p = position;
          p.y = mod(p.y + uTime * (0.15 + aSeed * 0.35), 9.0);
          p.x += sin(uTime * 0.4 + aSeed * 30.0) * 0.6;
          p.z += cos(uTime * 0.33 + aSeed * 50.0) * 0.6;
          float fade = smoothstep(0.0, 1.0, p.y) * smoothstep(9.0, 6.5, p.y);
          vColor = aColor * fade * (0.6 + 0.6 * sin(uTime * 2.0 + aSeed * 80.0));
          vec4 mv = modelViewMatrix * vec4(p, 1.0);
          gl_Position = projectionMatrix * mv;
          gl_PointSize = uScale * (0.03 + aSeed * 0.05) / max(-mv.z, 0.1);
        }`,
      fragmentShader: CROWD_FRAG,
      uniforms: { uTime: { value: 0 }, uScale: { value: 600 } },
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false,
    });
    const motes = new THREE.Points(geo, this.moteMat);
    motes.frustumCulled = false;
    this.group.add(motes);
  }

  /** Ripple the barrier where something slammed into it. */
  pulseBarrier(worldPos) {
    const p = this.pulses[this.pulseIdx];
    p.set(worldPos.x, worldPos.y, worldPos.z, 0);
    this.pulseIdx = (this.pulseIdx + 1) % this.pulses.length;
  }

  cheer(amount = 1) { this.hype = Math.min(1.5, this.hype + amount); }

  update(dt, viewportHeight, fovDeg) {
    this.time += dt;
    const t = this.time;
    this.hype = Math.max(0, this.hype - dt * 0.8);
    const scale = viewportHeight / (2 * Math.tan((fovDeg * Math.PI) / 360));
    this.skyMat.uniforms.uTime.value = t;
    this.barrierMat.uniforms.uTime.value = t;
    this.crowdMat.uniforms.uTime.value = t;
    this.crowdMat.uniforms.uHype.value = Math.min(1, this.hype);
    this.crowdMat.uniforms.uScale.value = scale;
    this.moteMat.uniforms.uTime.value = t;
    this.moteMat.uniforms.uScale.value = scale;
    this.cityMat.uniforms.uTime.value = t;
    this.screenMat.uniforms.uTime.value = t;
    for (const p of this.pulses) p.w += dt;
    for (const b of this.beams) {
      b.mesh.rotation.x = Math.sin(t * 0.21 + b.phase) * 0.35 - 0.25;
      b.mesh.rotation.z = Math.cos(t * 0.17 + b.phase * 1.3) * 0.3;
      b.mat.uniforms.uIntensity.value = 0.4 + Math.min(1, this.hype) * 0.5;
    }
    for (const h of this.halos) h.mesh.rotation.z += dt * h.speed;
    this.rimMat.emissiveIntensity = 2.6 + Math.sin(t * 1.4) * 0.5;
  }
}
