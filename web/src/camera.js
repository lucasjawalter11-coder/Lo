// Camera direction: duel framing, cinematic cut-ins, showcase orbits and the campus follow-cam.
import * as THREE from './three.js';
import { angDiff } from './combat.js';

const ease = (u) => u * u * (3 - 2 * u);
const _p = new THREE.Vector3(), _l = new THREE.Vector3();

export class CamRig {
  constructor(camera) {
    this.camera = camera;
    this.pos = new THREE.Vector3(0, 4, 12);
    this.look = new THREE.Vector3(0, 1.2, 0);
    this.forward = new THREE.Vector3(0, 0, -1);   // flattened view direction (for stick mapping)
    this.right = new THREE.Vector3(1, 0, 0);
    this.fromPos = new THREE.Vector3(); this.fromLook = new THREE.Vector3(); this.fromFov = 46;
    this.blendT = 1; this.blendDur = 0;
    this.mode = 'fixed'; this.params = {};
    this.modeT = 0;
    this.yaw = Math.PI;
    this.anchor = new THREE.Vector3(); this.focus = new THREE.Vector3();
    this.trauma = 0; this.shakeScale = 1;
    this.time = 0;
    this.baseFov = 46; this.fov = 46;
    this.aspect = 1.6;
    this.maxRadius = 16.6;
    this.first = true;
  }

  shake(v) { this.trauma = Math.min(1.5, this.trauma + v); }

  set(mode, params = {}, blend = 0.6) {
    this.fromPos.copy(this.pos); this.fromLook.copy(this.look); this.fromFov = this.fov;
    this.mode = mode; this.params = params; this.modeT = 0;
    this.blendT = 0; this.blendDur = blend;
    this.first = true;
  }

  _desired(dt, outPos, outLook) {
    const m = this.mode, q = this.params, t = this.modeT;
    let fov = this.baseFov;
    if (m === 'duel') {
      const p = q.player.pos, e = q.enemy.pos;
      const dx = e.x - p.x, dz = e.z - p.z, sep = Math.hypot(dx, dz);
      if (this.first) { this.yaw = Math.atan2(dx, dz); this.anchor.copy(p); this.focus.set((p.x + e.x) / 2, 0, (p.z + e.z) / 2); }
      if (sep > 1.5) this.yaw += angDiff(this.yaw, Math.atan2(dx, dz)) * (1 - Math.exp(-2.6 * dt));
      const k = 1 - Math.exp(-9 * dt);
      this.anchor.x += (p.x - this.anchor.x) * k; this.anchor.z += (p.z - this.anchor.z) * k;
      this.focus.x += ((p.x + e.x) / 2 - this.focus.x) * k; this.focus.z += ((p.z + e.z) / 2 - this.focus.z) * k;
      const fx = Math.sin(this.yaw), fz = Math.cos(this.yaw);
      const portrait = this.aspect < 1;
      const back = (portrait ? 5.4 : 4.7) + sep * 0.4, h = (portrait ? 3.1 : 2.75) + sep * 0.12, side = portrait ? 0.5 : 1.7;
      outPos.set(this.anchor.x - fx * back - fz * side, h, this.anchor.z - fz * back + fx * side);
      outLook.set(this.focus.x, 1.15 + Math.max(p.y, e.y) * 0.35, this.focus.z);
    } else if (m === 'follow') {
      const p = q.target;
      if (this.first) { this.yaw = q.yaw ?? this.yaw; this.anchor.copy(p); }
      const k = 1 - Math.exp(-10 * dt);
      this.anchor.x += (p.x - this.anchor.x) * k; this.anchor.z += (p.z - this.anchor.z) * k;
      const fx = Math.sin(this.yaw), fz = Math.cos(this.yaw);
      const dist = this.aspect < 1 ? 6.4 : 5.4;
      outPos.set(this.anchor.x - fx * dist, this.aspect < 1 ? 3.2 : 2.7, this.anchor.z - fz * dist);
      outLook.set(this.anchor.x + fx * 1.2, 1.35, this.anchor.z + fz * 1.2);
    } else if (m === 'orbit') {
      const a = (q.angle ?? 0) + t * (q.speed ?? 0.08);
      const c = q.center || _l.set(0, 0, 0);
      outPos.set(c.x + Math.sin(a) * q.radius, q.height, c.z + Math.cos(a) * q.radius);
      outLook.set(c.x, q.lookY ?? 1.2, c.z);
      fov = q.fov ?? fov;
    } else if (m === 'sweep') {
      const u = ease(Math.min(1, t / q.dur));
      const a = q.a0 + (q.a1 - q.a0) * u, r = q.r0 + (q.r1 - q.r0) * u, h = q.h0 + (q.h1 - q.h0) * u;
      outPos.set(Math.sin(a) * r, h, Math.cos(a) * r);
      outLook.set(0, q.lookY ?? 1.3, 0);
    } else if (m === 'face') {
      // look at a fighter from the front: showcase, cut-in, victory
      const f = q.fighter, s = f.rig ? f.rig.scale : 1;
      const yaw = (f.facing ?? 0) + (q.angle ?? 0.45) + t * (q.spin ?? 0);
      const dist = (q.dist ?? 3.2) - Math.min(1, t / (q.push ?? 1e9)) * (q.pushBy ?? 0);
      const wide = this.aspect < 1 ? 1.35 : 1;
      outPos.set(f.pos.x + Math.sin(yaw) * dist * wide, f.pos.y + (q.height ?? 1.3) * s, f.pos.z + Math.cos(yaw) * dist * wide);
      outLook.set(f.pos.x, f.pos.y + (q.lookY ?? 1.25) * s, f.pos.z);
      fov = q.fov ?? fov;
    } else if (m === 'ko') {
      const a = q.loser.pos, b = q.winner.pos;
      const mx = (a.x + b.x) / 2, mz = (a.z + b.z) / 2;
      let dx = b.x - a.x, dz = b.z - a.z; const l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l;
      const d = 3.6 + l * 0.45 - Math.min(1, t / 2) * 0.8;
      outPos.set(mx - dz * d, 1.0, mz + dx * d);
      outLook.set(a.x * 0.6 + b.x * 0.4, 0.9, a.z * 0.6 + b.z * 0.4);
      fov = 40;
    } else {
      outPos.copy(q.pos || this.pos); outLook.copy(q.look || this.look);
      fov = q.fov ?? fov;
    }
    return fov;
  }

  update(dt, aspect) {
    this.time += dt; this.modeT += dt;
    this.aspect = aspect;
    let fov = this._desired(dt, _p, _l);
    this.first = false;
    // keep the lens inside the bowl
    if (this.maxRadius) {
      const r = Math.hypot(_p.x, _p.z);
      if (r > this.maxRadius) { _p.x *= this.maxRadius / r; _p.z *= this.maxRadius / r; }
      if (_p.y < 0.45) _p.y = 0.45;
    }
    if (this.blendDur > 0 && this.blendT < this.blendDur) {
      this.blendT += dt;
      const u = ease(Math.min(1, this.blendT / this.blendDur));
      this.pos.lerpVectors(this.fromPos, _p, u); this.look.lerpVectors(this.fromLook, _l, u);
      fov = this.fromFov + (fov - this.fromFov) * u;
    } else { this.pos.copy(_p); this.look.copy(_l); }
    this.fov = fov;

    const cam = this.camera;
    // portrait screens need a taller field of view to keep both duelists in frame
    let vfov = fov;
    if (aspect < 1.25) vfov = Math.min(88, THREE.MathUtils.radToDeg(2 * Math.atan(Math.tan(THREE.MathUtils.degToRad(fov * 1.25) / 2) / aspect)) );
    if (aspect < 1.25) vfov = Math.max(fov, vfov * 0.82);
    cam.fov = vfov; cam.aspect = aspect;
    cam.position.copy(this.pos);
    cam.lookAt(this.look);
    this.forward.set(this.look.x - this.pos.x, 0, this.look.z - this.pos.z).normalize();
    this.right.set(-this.forward.z, 0, this.forward.x);
    if (this.trauma > 0) {
      const s = this.trauma * this.trauma * this.shakeScale, t = this.time;
      cam.position.x += Math.sin(t * 71) * 0.11 * s; cam.position.y += Math.sin(t * 83 + 1.3) * 0.09 * s; cam.position.z += Math.sin(t * 67 + 2.1) * 0.11 * s;
      cam.rotation.z += Math.sin(t * 59 + 0.7) * 0.018 * s;
      this.trauma = Math.max(0, this.trauma - dt * 1.9);
    }
    cam.updateProjectionMatrix();
    cam.updateMatrixWorld();
  }
}
