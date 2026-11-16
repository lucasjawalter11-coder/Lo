// Visual effects: sparks, weapon trails, shockwaves, beams, pillars, impact flares and pooled lights.
import * as THREE from './three.js';

const TAU = Math.PI * 2;
const _v = new THREE.Vector3(), _v2 = new THREE.Vector3(), _q = new THREE.Quaternion();
const rand = (a = 1, b) => (b === undefined ? Math.random() * a : a + Math.random() * (b - a));

const additive = (o) => new THREE.ShaderMaterial({ transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, ...o });

// ------------------------------------------------------------ weapon trail
const TRAIL_SAMPLES = 12, TRAIL_SUB = 3, TRAIL_ROWS = (TRAIL_SAMPLES - 1) * TRAIL_SUB + 1;

function catmull(out, p0, p1, p2, p3, t) {
  const t2 = t * t, t3 = t2 * t;
  out.x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
  out.y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
  out.z = 0.5 * ((2 * p1.z) + (-p0.z + p2.z) * t + (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 + (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3);
  return out;
}

export class Trail {
  constructor(scene, color) {
    this.base = []; this.tip = []; this.age = [];
    for (let i = 0; i < TRAIL_SAMPLES; i++) { this.base.push(new THREE.Vector3()); this.tip.push(new THREE.Vector3()); this.age.push(9); }
    this.count = 0;
    this.active = false;
    this.life = 0.16;
    const geo = new THREE.BufferGeometry();
    this.pos = new Float32Array(TRAIL_ROWS * 2 * 3);
    this.alpha = new Float32Array(TRAIL_ROWS * 2);
    const idx = [];
    for (let i = 0; i < TRAIL_ROWS - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('aAlpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setIndex(idx);
    this.mat = additive({
      uniforms: { uColor: { value: new THREE.Color(color) }, uBoost: { value: 1 } },
      vertexShader: 'attribute float aAlpha; varying float vA; varying float vEdge; void main(){ vA = aAlpha; vEdge = mod(float(gl_VertexID), 2.0); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
      fragmentShader: 'precision highp float; uniform vec3 uColor; uniform float uBoost; varying float vA; varying float vEdge; void main(){ float e = pow(vEdge, 1.6); vec3 c = mix(uColor * 0.6, mix(uColor, vec3(1.0), 0.55) * 3.2, e * e); gl_FragColor = vec4(c * vA * (0.25 + 0.75 * e) * uBoost, 1.0); }',
      side: THREE.DoubleSide,
    });
    this.mesh = new THREE.Mesh(geo, this.mat);
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = 6;
    scene.add(this.mesh);
    this._a = new THREE.Vector3(); this._b = new THREE.Vector3();
  }

  /** Feed the weapon's base/tip (world space) once per frame. */
  update(dt, baseObj, tipObj) {
    for (let i = 0; i < TRAIL_SAMPLES; i++) this.age[i] += dt;
    if (this.active) {
      // newest sample at index 0
      const b = this.base.pop(), t = this.tip.pop(); this.age.pop();
      baseObj.getWorldPosition(b); tipObj.getWorldPosition(t);
      this.base.unshift(b); this.tip.unshift(t); this.age.unshift(0);
      this.count = Math.min(TRAIL_SAMPLES, this.count + 1);
    } else if (this.count > 0 && this.age[0] > this.life) {
      this.count = 0;
    }
    const n = this.count;
    if (n < 2) { this.mesh.visible = false; return; }
    this.mesh.visible = true;
    const pos = this.pos, al = this.alpha;
    let row = 0;
    for (let i = 0; i < TRAIL_SAMPLES - 1; i++) {
      for (let s = 0; s < TRAIL_SUB; s++) {
        const t = s / TRAIL_SUB;
        let a = 0;
        if (i < n - 1) {
          const i0 = Math.max(0, i - 1), i3 = Math.min(n - 1, i + 2);
          catmull(this._a, this.base[i0], this.base[i], this.base[i + 1], this.base[i3], t);
          catmull(this._b, this.tip[i0], this.tip[i], this.tip[i + 1], this.tip[i3], t);
          const age = this.age[i] + (this.age[i + 1] - this.age[i]) * t;
          a = Math.max(0, 1 - age / this.life);
          a *= a;
        }
        const o = row * 6;
        pos[o] = this._a.x; pos[o + 1] = this._a.y; pos[o + 2] = this._a.z;
        pos[o + 3] = this._b.x; pos[o + 4] = this._b.y; pos[o + 5] = this._b.z;
        al[row * 2] = a; al[row * 2 + 1] = a;
        row++;
      }
    }
    // final row
    const li = Math.min(n - 1, TRAIL_SAMPLES - 1), o = row * 6;
    pos[o] = this.base[li].x; pos[o + 1] = this.base[li].y; pos[o + 2] = this.base[li].z;
    pos[o + 3] = this.tip[li].x; pos[o + 4] = this.tip[li].y; pos[o + 5] = this.tip[li].z;
    al[row * 2] = 0; al[row * 2 + 1] = 0;
    this.mesh.geometry.attributes.position.needsUpdate = true;
    this.mesh.geometry.attributes.aAlpha.needsUpdate = true;
  }

  reset() { this.count = 0; this.active = false; this.mesh.visible = false; }
}

// ------------------------------------------------------------ the effect system
const MAX_P = 2600;

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.group = new THREE.Group();
    scene.add(this.group);
    this.time = 0;
    this._initParticles();
    this._initRings();
    this._initFlares();
    this._initPillars();
    this._initBeam();
    this._initLights();
    this._initBolts();
    this._initShards();
  }

  // ---- particles
  _initParticles() {
    this.pPos = new Float32Array(MAX_P * 3);
    this.pCol = new Float32Array(MAX_P * 3);
    this.pSize = new Float32Array(MAX_P);
    this.pVel = new Float32Array(MAX_P * 3);
    this.pBase = new Float32Array(MAX_P * 3);
    this.pLife = new Float32Array(MAX_P);
    this.pMax = new Float32Array(MAX_P);
    this.pSize0 = new Float32Array(MAX_P);
    this.pGrav = new Float32Array(MAX_P);
    this.pDrag = new Float32Array(MAX_P);
    this.pNext = 0;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(this.pPos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('aColor', new THREE.BufferAttribute(this.pCol, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('aSize', new THREE.BufferAttribute(this.pSize, 1).setUsage(THREE.DynamicDrawUsage));
    this.pMat = additive({
      uniforms: { uScale: { value: 600 } },
      vertexShader: 'attribute vec3 aColor; attribute float aSize; uniform float uScale; varying vec3 vC; void main(){ vC = aColor; vec4 mv = modelViewMatrix * vec4(position, 1.0); gl_Position = projectionMatrix * mv; gl_PointSize = aSize * uScale / max(-mv.z, 0.1); }',
      fragmentShader: 'precision highp float; varying vec3 vC; void main(){ float d = length(gl_PointCoord - 0.5); float a = smoothstep(0.5, 0.0, d); gl_FragColor = vec4(vC * a * a, 1.0); }',
    });
    this.points = new THREE.Points(geo, this.pMat);
    this.points.frustumCulled = false;
    this.points.renderOrder = 7;
    this.group.add(this.points);
    this._c = new THREE.Color();
  }

  emit(x, y, z, vx, vy, vz, color, life, size, grav = 0, drag = 0.0) {
    const i = this.pNext; this.pNext = (i + 1) % MAX_P;
    const o = i * 3;
    this.pPos[o] = x; this.pPos[o + 1] = y; this.pPos[o + 2] = z;
    this.pVel[o] = vx; this.pVel[o + 1] = vy; this.pVel[o + 2] = vz;
    this.pBase[o] = color.r; this.pBase[o + 1] = color.g; this.pBase[o + 2] = color.b;
    this.pLife[i] = life; this.pMax[i] = life; this.pSize0[i] = size; this.pGrav[i] = grav; this.pDrag[i] = drag;
  }

  /** Burst of sparks. `dir` (optional unit vector) biases the spray. */
  sparks(pos, color, n = 20, speed = 8, { dir = null, spread = 1, life = 0.45, size = 0.09, grav = 14, drag = 1.5, white = 0.35 } = {}) {
    const c = this._c;
    for (let i = 0; i < n; i++) {
      const th = rand(TAU), ph = Math.acos(rand(-1, 1));
      let vx = Math.sin(ph) * Math.cos(th), vy = Math.cos(ph), vz = Math.sin(ph) * Math.sin(th);
      if (dir) { vx = vx * spread + dir.x; vy = vy * spread + dir.y; vz = vz * spread + dir.z; const l = Math.hypot(vx, vy, vz) || 1; vx /= l; vy /= l; vz /= l; }
      const sp = speed * rand(0.25, 1);
      c.set(color); if (Math.random() < white) c.lerp(WHITE, 0.7);
      c.multiplyScalar(rand(2.2, 5.0));
      this.emit(pos.x, pos.y, pos.z, vx * sp, vy * sp, vz * sp, c, life * rand(0.5, 1), size * rand(0.5, 1.3), grav, drag);
    }
  }

  /** Slow rising motes around a point (charging aura). */
  aura(pos, color, n = 3, radius = 0.7, up = 2.6) {
    const c = this._c;
    for (let i = 0; i < n; i++) {
      const a = rand(TAU), r = radius * Math.sqrt(Math.random());
      c.set(color).multiplyScalar(rand(2, 4.5));
      this.emit(pos.x + Math.cos(a) * r, pos.y + rand(0, 0.5), pos.z + Math.sin(a) * r, Math.cos(a) * 0.3, up * rand(0.5, 1.2), Math.sin(a) * 0.3, c, rand(0.4, 0.9), rand(0.05, 0.11), -1.5, 0.6);
    }
  }

  /** Motes pulled inward toward a point (gathering power). */
  gather(pos, color, n = 4, radius = 2.2) {
    const c = this._c;
    for (let i = 0; i < n; i++) {
      const th = rand(TAU), ph = Math.acos(rand(-0.4, 1)), r = radius * rand(0.6, 1);
      const dx = Math.sin(ph) * Math.cos(th), dy = Math.cos(ph), dz = Math.sin(ph) * Math.sin(th);
      const life = rand(0.25, 0.45), sp = r / life;
      c.set(color).multiplyScalar(rand(2, 4));
      this.emit(pos.x + dx * r, pos.y + dy * r, pos.z + dz * r, -dx * sp, -dy * sp, -dz * sp, c, life, rand(0.05, 0.1), 0, 0);
    }
  }

  dust(pos, n = 10, speed = 3) {
    const c = this._c;
    for (let i = 0; i < n; i++) {
      const a = rand(TAU), sp = speed * rand(0.3, 1);
      c.setRGB(0.5, 0.6, 0.8).multiplyScalar(rand(0.25, 0.6));
      this.emit(pos.x, 0.08, pos.z, Math.cos(a) * sp, rand(0.3, 1.4), Math.sin(a) * sp, c, rand(0.35, 0.7), rand(0.2, 0.42), -0.6, 3.5);
    }
  }

  _updateParticles(dt) {
    const { pPos, pVel, pCol, pBase, pSize, pLife, pMax, pSize0, pGrav, pDrag } = this;
    for (let i = 0; i < MAX_P; i++) {
      if (pLife[i] <= 0) { if (pSize[i] !== 0) pSize[i] = 0; continue; }
      pLife[i] -= dt;
      const o = i * 3, k = Math.max(0, pLife[i] / pMax[i]);
      const dr = Math.max(0, 1 - pDrag[i] * dt);
      pVel[o] *= dr; pVel[o + 1] = pVel[o + 1] * dr - pGrav[i] * dt; pVel[o + 2] *= dr;
      pPos[o] += pVel[o] * dt; pPos[o + 1] += pVel[o + 1] * dt; pPos[o + 2] += pVel[o + 2] * dt;
      if (pPos[o + 1] < 0.03 && pVel[o + 1] < 0) { pPos[o + 1] = 0.03; pVel[o + 1] *= -0.35; pVel[o] *= 0.6; pVel[o + 2] *= 0.6; }
      const f = k * k;
      pCol[o] = pBase[o] * f; pCol[o + 1] = pBase[o + 1] * f; pCol[o + 2] = pBase[o + 2] * f;
      pSize[i] = pLife[i] > 0 ? pSize0[i] * (0.4 + 0.6 * k) : 0;
    }
    const g = this.points.geometry;
    g.attributes.position.needsUpdate = true; g.attributes.aColor.needsUpdate = true; g.attributes.aSize.needsUpdate = true;
  }

  // ---- ground rings / telegraphs
  _initRings() {
    this.rings = [];
    const geo = new THREE.PlaneGeometry(2, 2);
    geo.rotateX(-Math.PI / 2);
    for (let i = 0; i < 18; i++) {
      const mat = additive({
        uniforms: { uColor: { value: new THREE.Color() }, uAlpha: { value: 0 }, uWidth: { value: 0.12 }, uFill: { value: 0 }, uTime: { value: 0 } },
        vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
        fragmentShader: `precision highp float; varying vec2 vUv; uniform vec3 uColor; uniform float uAlpha, uWidth, uFill, uTime;
          void main(){
            vec2 p = (vUv - 0.5) * 2.0; float r = length(p);
            float band = smoothstep(uWidth, 0.0, abs(r - (1.0 - uWidth))) ;
            float inner = smoothstep(1.0, 0.0, r) * 0.25;
            float ang = atan(p.y, p.x);
            float fill = uFill * step(r, 1.0) * (0.22 + 0.2 * step(0.5, fract(ang * 1.909 + r * 3.0 - uTime * 2.0)) + 0.3 * smoothstep(0.75, 1.0, r));
            gl_FragColor = vec4(uColor * (band * 2.4 + inner * (1.0 - uFill) + fill) * uAlpha, 1.0);
          }`,
        side: THREE.DoubleSide,
      });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.visible = false; mesh.layers.set(1); mesh.renderOrder = 3;
      this.group.add(mesh);
      this.rings.push({ mesh, mat, t: 0, life: 0, r0: 0, r1: 1, active: false, hold: false });
    }
  }

  /** Expanding shockwave on the floor. */
  ring(pos, color, r0, r1, life = 0.4, width = 0.14, y = 0.04) {
    const r = this.rings.find((o) => !o.active) || this.rings[0];
    r.active = true; r.t = 0; r.life = life; r.r0 = r0; r.r1 = r1; r.hold = false;
    r.mat.uniforms.uColor.value.set(color); r.mat.uniforms.uWidth.value = width; r.mat.uniforms.uFill.value = 0;
    r.mesh.position.set(pos.x, y, pos.z); r.mesh.visible = true;
    return r;
  }

  /** Warning marker that sits on the floor until released. */
  telegraph(pos, color, radius, life) {
    const r = this.ring(pos, color, radius, radius, life, 0.08, 0.035);
    r.hold = true; r.mat.uniforms.uFill.value = 1;
    return r;
  }

  // ---- impact flares (camera-facing star bursts)
  _initFlares() {
    const c = document.createElement('canvas'); c.width = c.height = 256;
    const x = c.getContext('2d');
    const g = x.createRadialGradient(128, 128, 0, 128, 128, 128);
    g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.12, 'rgba(255,255,255,0.75)'); g.addColorStop(0.4, 'rgba(255,255,255,0.14)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, 256, 256);
    x.globalCompositeOperation = 'lighter';
    for (const [len, w, rot] of [[126, 5, 0.3], [126, 5, 0.3 + Math.PI / 2], [86, 3, 1.1], [86, 3, 1.1 + Math.PI / 2]]) {
      x.save(); x.translate(128, 128); x.rotate(rot);
      const lg = x.createLinearGradient(-len, 0, len, 0);
      lg.addColorStop(0, 'rgba(255,255,255,0)'); lg.addColorStop(0.5, 'rgba(255,255,255,1)'); lg.addColorStop(1, 'rgba(255,255,255,0)');
      x.fillStyle = lg; x.beginPath(); x.moveTo(-len, 0); x.lineTo(0, -w); x.lineTo(len, 0); x.lineTo(0, w); x.closePath(); x.fill();
      x.restore();
    }
    const tex = new THREE.CanvasTexture(c);
    this.flares = [];
    const geo = new THREE.PlaneGeometry(1, 1);
    for (let i = 0; i < 10; i++) {
      const mat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false, fog: false });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.visible = false; mesh.renderOrder = 9;
      this.group.add(mesh);
      this.flares.push({ mesh, mat, t: 0, life: 0, size: 1, active: false, color: new THREE.Color(), roll: 0 });
    }
  }

  flare(pos, color, size = 1.6, life = 0.16, boost = 3) {
    const f = this.flares.find((o) => !o.active) || this.flares[0];
    f.active = true; f.t = 0; f.life = life; f.size = size; f.roll = rand(TAU);
    f.color.set(color).lerp(WHITE, 0.45).multiplyScalar(boost);
    f.mesh.position.copy(pos); f.mesh.visible = true;
  }

  // ---- light pillars
  _initPillars() {
    const geo = new THREE.CylinderGeometry(1, 1, 1, 20, 1, true);
    geo.translate(0, 0.5, 0);
    this.pillars = [];
    for (let i = 0; i < 10; i++) {
      const mat = additive({
        uniforms: { uColor: { value: new THREE.Color() }, uAlpha: { value: 0 } },
        vertexShader: 'varying vec2 vUv; varying vec3 vN; varying vec3 vV; void main(){ vUv = uv; vec4 mv = modelViewMatrix * vec4(position, 1.0); vN = normalMatrix * normal; vV = -mv.xyz; gl_Position = projectionMatrix * mv; }',
        fragmentShader: 'precision highp float; varying vec2 vUv; varying vec3 vN; varying vec3 vV; uniform vec3 uColor; uniform float uAlpha; void main(){ float f = abs(dot(normalize(vN), normalize(vV))); float a = pow(f, 1.5) * (0.25 + 0.75 * pow(1.0 - vUv.y, 2.0)); gl_FragColor = vec4(mix(uColor, vec3(1.0), f * f * 0.6) * a * uAlpha * 3.0, 1.0); }',
        side: THREE.DoubleSide,
      });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.visible = false; mesh.renderOrder = 6;
      this.group.add(mesh);
      this.pillars.push({ mesh, mat, t: 0, life: 0, active: false, r: 1, h: 1 });
    }
  }

  pillar(pos, color, radius = 1, height = 14, life = 0.35) {
    const p = this.pillars.find((o) => !o.active) || this.pillars[0];
    p.active = true; p.t = 0; p.life = life; p.r = radius; p.h = height;
    p.mat.uniforms.uColor.value.set(color);
    p.mesh.position.set(pos.x, 0, pos.z); p.mesh.visible = true;
  }

  // ---- sustained beam
  _initBeam() {
    const geo = new THREE.CylinderGeometry(1, 1, 1, 20, 1, true);
    geo.rotateX(Math.PI / 2); geo.translate(0, 0, 0.5);
    this.beamMat = additive({
      uniforms: { uColor: { value: new THREE.Color() }, uAlpha: { value: 0 }, uTime: { value: 0 } },
      vertexShader: 'varying vec2 vUv; varying vec3 vN; varying vec3 vV; void main(){ vUv = uv; vec4 mv = modelViewMatrix * vec4(position, 1.0); vN = normalMatrix * normal; vV = -mv.xyz; gl_Position = projectionMatrix * mv; }',
      fragmentShader: `precision highp float; varying vec2 vUv; varying vec3 vN; varying vec3 vV; uniform vec3 uColor; uniform float uAlpha, uTime;
        float h(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
        void main(){
          float f = abs(dot(normalize(vN), normalize(vV)));
          float streak = 0.6 + 0.4 * h(vec2(floor(vUv.x * 40.0), floor(vUv.y * 8.0 - uTime * 30.0)));
          float core = pow(f, 3.0);
          gl_FragColor = vec4(mix(uColor * 1.6, vec3(1.0) * 3.5, core) * (0.2 + f) * streak * uAlpha, 1.0);
        }`,
      side: THREE.DoubleSide,
    });
    this.beam = new THREE.Mesh(geo, this.beamMat);
    this.beam.visible = false; this.beam.renderOrder = 6; this.beam.frustumCulled = false;
    this.group.add(this.beam);
  }

  setBeam(origin, yaw, length, width, color, alpha) {
    if (alpha <= 0.001) { this.beam.visible = false; return; }
    this.beam.visible = true;
    this.beam.position.copy(origin);
    this.beam.rotation.set(0, yaw, 0);
    this.beam.scale.set(width, width, length);
    this.beamMat.uniforms.uColor.value.set(color);
    this.beamMat.uniforms.uAlpha.value = alpha;
  }

  // ---- pooled point lights (never added/removed, so shaders never recompile mid-fight)
  _initLights() {
    this.weaponLights = [0, 1].map(() => { const l = new THREE.PointLight(0xffffff, 0, 7, 1.6); this.group.add(l); return l; });
    this.flashLights = [0, 1, 2].map(() => { const l = new THREE.PointLight(0xffffff, 0, 16, 1.5); this.group.add(l); return { light: l, t: 0, life: 0, peak: 0 }; });
    this._fl = 0;
  }

  flash(pos, color, intensity = 60, life = 0.22) {
    const f = this.flashLights[this._fl]; this._fl = (this._fl + 1) % this.flashLights.length;
    f.light.color.set(color); f.light.position.copy(pos); f.t = 0; f.life = life; f.peak = intensity;
  }

  // ---- projectile visuals
  _initBolts() {
    this.bolts = [];
    const geo = new THREE.SphereGeometry(1, 10, 8);
    const crescent = crescentGeo();
    for (let i = 0; i < 28; i++) {
      const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, side: THREE.DoubleSide });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.visible = false; mesh.renderOrder = 6;
      this.group.add(mesh);
      this.bolts.push({ mesh, mat, used: false, sphere: geo, crescent });
    }
  }

  acquireBolt(color, shape = 'bolt', scale = 1) {
    const b = this.bolts.find((o) => !o.used);
    if (!b) return null;
    b.used = true; b.mesh.visible = true;
    b.mesh.geometry = shape === 'crescent' ? b.crescent : b.sphere;
    b.mat.color.set(color).lerp(WHITE, 0.4).multiplyScalar(3.4);
    if (shape === 'crescent') b.mesh.scale.setScalar(scale); else b.mesh.scale.set(0.11 * scale, 0.11 * scale, 0.5 * scale);
    return b;
  }

  releaseBolt(b) { if (b) { b.used = false; b.mesh.visible = false; } }

  // ---- shattering crest shards
  _initShards() {
    this.shards = [];
    const geo = new THREE.TetrahedronGeometry(0.07, 0);
    for (let i = 0; i < 26; i++) {
      const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.visible = false;
      this.group.add(mesh);
      this.shards.push({ mesh, mat, vel: new THREE.Vector3(), spin: new THREE.Vector3(), life: 0, max: 1 });
    }
  }

  shatter(pos, color) {
    for (const s of this.shards) {
      s.mesh.visible = true; s.mesh.position.copy(pos);
      s.mat.color.set(color).lerp(WHITE, 0.5).multiplyScalar(rand(2, 4));
      const th = rand(TAU), ph = Math.acos(rand(-0.3, 1)), sp = rand(2, 7);
      s.vel.set(Math.sin(ph) * Math.cos(th) * sp, Math.cos(ph) * sp + 1.5, Math.sin(ph) * Math.sin(th) * sp);
      s.spin.set(rand(-9, 9), rand(-9, 9), rand(-9, 9));
      s.life = s.max = rand(0.9, 1.6);
      s.mesh.scale.setScalar(rand(0.5, 1.6));
    }
    this.sparks(pos, color, 60, 9, { life: 0.9, size: 0.12, grav: 7 });
    this.flare(pos, color, 4.5, 0.35, 5);
    this.flash(pos, color, 220, 0.5);
  }

  clear() {
    this.pLife.fill(0);
    for (const r of this.rings) { r.active = false; r.mesh.visible = false; }
    for (const p of this.pillars) { p.active = false; p.mesh.visible = false; }
    for (const f of this.flares) { f.active = false; f.mesh.visible = false; }
    for (const b of this.bolts) this.releaseBolt(b);
    for (const s of this.shards) { s.life = 0; s.mesh.visible = false; }
    this.beam.visible = false;
  }

  update(dt, camera, viewportHeight) {
    this.time += dt;
    this.pMat.uniforms.uScale.value = viewportHeight / (2 * Math.tan((camera.fov * Math.PI) / 360));
    this._updateParticles(dt);
    for (const r of this.rings) {
      if (!r.active) continue;
      r.t += dt;
      const k = Math.min(1, r.t / r.life);
      r.mat.uniforms.uTime.value = this.time;
      if (r.hold) {
        r.mat.uniforms.uAlpha.value = Math.min(1, r.t * 8) * (0.7 + 0.3 * Math.sin(this.time * 22));
        r.mesh.scale.setScalar(r.r1);
      } else {
        const e = 1 - Math.pow(1 - k, 3);
        r.mesh.scale.setScalar(r.r0 + (r.r1 - r.r0) * e);
        r.mat.uniforms.uAlpha.value = (1 - k) * (1 - k);
      }
      if (k >= 1) { r.active = false; r.mesh.visible = false; }
    }
    for (const f of this.flares) {
      if (!f.active) continue;
      f.t += dt;
      const k = Math.min(1, f.t / f.life);
      f.mesh.quaternion.copy(camera.quaternion);
      f.mesh.rotateZ(f.roll + k * 0.6);
      f.mesh.scale.setScalar(f.size * (0.35 + 0.65 * (1 - Math.pow(1 - k, 3))));
      f.mat.color.copy(f.color).multiplyScalar((1 - k) * (1 - k));
      if (k >= 1) { f.active = false; f.mesh.visible = false; }
    }
    for (const p of this.pillars) {
      if (!p.active) continue;
      p.t += dt;
      const k = Math.min(1, p.t / p.life);
      p.mesh.scale.set(p.r * (1 - k * 0.6), p.h, p.r * (1 - k * 0.6));
      p.mat.uniforms.uAlpha.value = (1 - k) * (1 - k);
      if (k >= 1) { p.active = false; p.mesh.visible = false; }
    }
    for (const f of this.flashLights) {
      if (f.life <= 0) { f.light.intensity = 0; continue; }
      f.t += dt;
      const k = Math.min(1, f.t / f.life);
      f.light.intensity = f.peak * (1 - k) * (1 - k);
      if (k >= 1) f.life = 0;
    }
    for (const s of this.shards) {
      if (s.life <= 0) continue;
      s.life -= dt;
      s.vel.y -= 9 * dt;
      s.mesh.position.addScaledVector(s.vel, dt);
      if (s.mesh.position.y < 0.05) { s.mesh.position.y = 0.05; s.vel.y *= -0.4; s.vel.x *= 0.7; s.vel.z *= 0.7; }
      s.mesh.rotation.x += s.spin.x * dt; s.mesh.rotation.y += s.spin.y * dt; s.mesh.rotation.z += s.spin.z * dt;
      s.mat.opacity = Math.max(0, s.life / s.max);
      if (s.life <= 0) s.mesh.visible = false;
    }
    this.beamMat.uniforms.uTime.value = this.time;
  }
}

const WHITE = new THREE.Color(1, 1, 1);

/** A blade-wave crescent lying in the XZ plane, convex side toward +Z. */
function crescentGeo() {
  const n = 22, R = 1, pos = [], idx = [];
  for (let i = 0; i <= n; i++) {
    const a = -1.15 + (i / n) * 2.3, w = 0.22 * Math.cos((a / 1.15) * Math.PI * 0.5) + 0.01;
    const sx = Math.sin(a), cz = Math.cos(a);
    pos.push(sx * R, 0, cz * R - 0.6, sx * (R - w), 0, cz * (R - w) - 0.6 - w * 0.5);
  }
  for (let i = 0; i < n; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(pos), 3));
  g.setIndex(idx);
  return g;
}

export { rand };
