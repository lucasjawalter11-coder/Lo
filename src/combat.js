// Duel simulation: fighters, moves, projectiles, hit resolution.
import * as THREE from './three.js';
import { Rig } from './character.js';
import { Animator } from './anim.js';
import { Trail, rand } from './fx.js';
import { PLAY_RADIUS, ARENA_RADIUS } from './arena.js';

const TAU = Math.PI * 2;
const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3();
const _col = new THREE.Color();
export const angDiff = (from, to) => { let d = (to - from) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return d; };
const clamp = THREE.MathUtils.clamp;

const DASH_TIME = 0.28, DASH_SPEED = 15, DASH_CD = 0.6;
const CUT_IN = 0.9;

export class Fighter {
  constructor(def, world, slot) {
    this.def = def; this.world = world; this.slot = slot;
    this.rig = new Rig(def);
    this.anim = new Animator(this.rig);
    this.root = this.rig.root;
    this.pos = this.root.position;
    this.vel = new THREE.Vector3();
    this.facing = 0;
    this.color = new THREE.Color(def.accent);
    this.trail = def.weapon === 'pistol' ? null : new Trail(world.scene, def.accent);
    this.intent = { mx: 0, mz: 0, light: false, special: false, dash: false, ult: false, guard: false };
    this.maxHp = def.stats.hp;
    this.dmgMul = 1; this.dmgTakenMul = 1;
    this.target = null;
    this.serial = 0;
    this.energy = 0;
    this.wins = 0;
    world.scene.add(this.root);
    this.reset(0, 0, 0);
  }

  reset(x, z, facing) {
    this.pos.set(x, 0, z); this.vel.set(0, 0, 0); this.facing = facing;
    this.hp = this.maxHp; this.shownHp = this.maxHp;
    this.state = 'still'; this.stateT = 0;
    this.move = null; this.comboIdx = 0; this.buf = null;
    this.invuln = 0; this.dashCd = 0; this.hitsTaken = 0; this.combo = 0; this.comboT = 0;
    this.stun = 0; this.hitDone = false; this.fired = 0; this.armor = false; this.ghost = false;
    this.ult = null; this.beamOn = false; this.hitFlip = false; this.windUsed = false; this.guardLock = 0;
    this.trail && this.trail.reset();
    this.rig.fx.flash.value = 0;
    this.rig.setIgnite(1);
    this.root.visible = true;
    this.anim.play('idle', { blend: 0, force: true });
    this.sync(0);
  }

  // ---- helpers
  get dirX() { return Math.sin(this.facing); }
  get dirZ() { return Math.cos(this.facing); }
  distTo(o) { return Math.hypot(o.pos.x - this.pos.x, o.pos.z - this.pos.z); }
  angleTo(o) { return Math.atan2(o.pos.x - this.pos.x, o.pos.z - this.pos.z); }
  faceTarget() { if (this.target) this.facing = this.angleTo(this.target); }
  turnToward(angle, rate, dt) { const d = angDiff(this.facing, angle); const step = rate * dt; this.facing += Math.abs(d) <= step ? d : Math.sign(d) * step; }
  chest(out) { return out.set(this.pos.x, this.pos.y + 1.15 * this.rig.scale, this.pos.z); }
  get canAct() { return this.state === 'idle' || this.state === 'guard'; }
  get busy() { return this.state === 'attack' || this.state === 'ult' || this.state === 'leap'; }
  get vulnerable() { return this.invuln <= 0 && !['down', 'getup', 'ko', 'win', 'still'].includes(this.state) && !(this.ult && this.ult.invuln); }
  get threatening() { return (this.state === 'attack' && this.move && this.stateT < (this.move.hit ? this.move.hit[1] : this.move.dur * 0.6)) || this.state === 'leap' || (this.state === 'ult' && this.ult && this.ult.phase === 'exec'); }
  gainEnergy(v) { this.energy = clamp(this.energy + (v > 0 ? v * (this.def.stats.focus ?? 1) : v), 0, 100); }

  setState(s) { this.state = s; this.stateT = 0; }

  toIdle() {
    this.setState('idle'); this.move = null; this.comboIdx = 0; this.armor = false; this.ghost = false; this.ult = null;
    if (this.trail) this.trail.active = false;
    this.pos.y = 0;
  }

  interrupt() {
    this.move = null; this.armor = false; this.ghost = false; this.ult = null;
    if (this.trail) this.trail.active = false;
    if (this.beamOn) { this.beamOn = false; this.world.fx.setBeam(this.pos, 0, 0, 0, 0, 0); this.world.audio.stopLoop('beam'); }
    this.pos.y = 0;
  }

  // ---- actions
  startAttack(i) {
    const m = this.def.combo[i];
    this.move = m; this.comboIdx = i; this.setState('attack');
    this.faceTarget();
    this.hitDone = false; this.fired = 0; this.serial++;
    this.anim.play(m.clip, { speed: m.speed, blend: 0.05, force: true });
    this.swung = false;
    this.buf = null;
  }

  startSpecial() {
    const s = this.def.special;
    this.gainEnergy(-s.cost);
    this.buf = null; this.serial++;
    this.faceTarget();
    const w = this.world;
    w.fx.flare(this.chest(_a), this.def.accent, 2.4, 0.2, 2.5);
    w.fx.ring(this.pos, this.def.accent, 0.3, 2.2, 0.3);
    w.audio.play('special');
    w.emit('special', { fighter: this, name: s.name });
    if (s.kind === 'leap') {
      this.setState('leap'); this.move = s; this.armor = true;
      const d = clamp(this.distTo(this.target) - 1.3, 1.2, 7.5);
      this.leap = { fx: this.pos.x, fz: this.pos.z, tx: this.pos.x + this.dirX * d, tz: this.pos.z + this.dirZ * d, landed: false, air: 0.5, height: 2.6 };
      this.anim.play('leap', { blend: 0.06, force: true });
      return;
    }
    this.move = s; this.comboIdx = 99; this.setState('attack');
    this.hitDone = false; this.fired = 0; this.swung = false;
    this.ghost = !!s.through;
    if (s.kind === 'vault') this.invuln = 0.22;
    this.anim.play(s.clip, { speed: s.speed, blend: 0.05, force: true });
  }

  startDash() {
    const it = this.intent, mag = Math.hypot(it.mx, it.mz);
    let dx, dz, back = false;
    if (mag > 0.3) { dx = it.mx / mag; dz = it.mz / mag; }
    else { const a = this.target ? this.angleTo(this.target) : this.facing; dx = -Math.sin(a); dz = -Math.cos(a); back = true; }
    if (this.target && !back) {
      const a = this.angleTo(this.target);
      back = dx * Math.sin(a) + dz * Math.cos(a) < -0.5;
    }
    this.interrupt();
    this.setState('dash'); this.buf = null;
    this.vel.set(dx * DASH_SPEED, 0, dz * DASH_SPEED);
    this.invuln = 0.22; this.dashCd = DASH_CD * (this.def.stats.dashCd ?? 1);
    if (back) { this.faceTarget(); this.anim.play('guardHit', { blend: 0.04, force: true, speed: 0.7 }); }
    else { this.facing = Math.atan2(dx, dz); this.anim.play('dash', { blend: 0.05, force: true }); }
    const w = this.world;
    w.fx.dust(this.pos, 8, 3);
    w.fx.sparks(this.chest(_a), this.def.accent, 10, 4, { dir: _b.set(-dx, 0.1, -dz), spread: 0.4, life: 0.3, size: 0.08, grav: 0 });
    w.audio.play('dash');
  }

  startUlt() {
    this.interrupt();
    this.energy = 0; this.buf = null; this.serial++;
    this.setState('ult');
    this.faceTarget();
    this.ult = { kind: this.def.ultimate.kind, phase: 'cutin', t: 0, step: 0, invuln: true, data: {} };
    this.anim.play('charge', { blend: 0.1, force: true });
    this.world.beginCutIn(this);
  }

  stagger(time) {
    this.interrupt();
    this.setState('hit'); this.stun = time;
    this.anim.play('hit2', { blend: 0.04, force: true });
    if (this.target) { const a = this.angleTo(this.target); this.vel.set(-Math.sin(a) * 4, 0, -Math.cos(a) * 4); }
  }

  // ---- being hit
  takeHit(spec, attacker, from) {
    if (!this.vulnerable) return { type: 'miss' };
    let dx = this.pos.x - from.x, dz = this.pos.z - from.z;
    const dl = Math.hypot(dx, dz) || 1; dx /= dl; dz /= dl;
    const power = attacker ? attacker.def.stats.power * attacker.dmgMul : 1;
    let dmg = spec.dmg * power * this.dmgTakenMul;
    const superArmor = this.state === 'ult';

    if (this.state === 'guard' && !spec.unblockable) {
      const front = (-dx) * this.dirX + (-dz) * this.dirZ;      // source is in front of us
      if (front > -0.25) {
        if (this.stateT < (this.def.perks && this.def.perks.keen ? 0.24 : 0.17) && !spec.guardBreak) return { type: 'parry' };
        if (spec.guardBreak) {
          dmg *= 0.6; this.hp -= dmg;
          if (this.hp <= 0) { this.hp = 0; this.enterKO(dx, dz, spec.push); return { type: 'hit', dmg, ko: true, broke: true }; }
          this.enterHit(0.75, dx, dz, spec.push * 0.6);
          return { type: 'hit', dmg, broke: true };
        }
        const chip = (dmg * 0.12) / this.def.stats.guard;
        this.hp = Math.max(1, this.hp - chip);
        this.vel.set(dx * (2 + spec.push * 0.5), 0, dz * (2 + spec.push * 0.5));
        this.anim.play('guardHit', { blend: 0.03, force: true });
        this.guardLock = 0.2;
        return { type: 'guard', dmg: chip };
      }
    }
    if ((this.armor || superArmor) && !(spec.launch && !superArmor && spec.heavy) ) {
      if (superArmor || !spec.unblockable) {
        dmg *= superArmor ? 0.5 : 0.75;
        this.hp -= dmg;
        this.rig.fx.flash.value = 0.5;
        if (this.hp <= 0) { this.hp = 0; this.enterKO(dx, dz, spec.push); return { type: 'hit', dmg, ko: true }; }
        return { type: 'armor', dmg };
      }
    }
    const scale = Math.max(0.45, 1 - Math.max(0, this.hitsTaken - 1) * 0.1);
    dmg *= scale;
    this.hp -= dmg;
    this.hitsTaken++;
    if (this.hp <= 0) { this.hp = 0; this.enterKO(dx, dz, spec.push); return { type: 'hit', dmg, ko: true }; }
    let wind = false;
    if (this.def.perks && this.def.perks.wind && !this.windUsed && this.hp < this.maxHp * 0.25) {
      this.windUsed = true; wind = true;
      this.hp = Math.min(this.maxHp, this.hp + this.maxHp * 0.2);
    }
    if (spec.launch) this.enterDown(dx, dz, spec.push); else this.enterHit(spec.stun, dx, dz, spec.push);
    return { type: 'hit', dmg, wind };
  }

  enterHit(stun, dx, dz, push) {
    this.interrupt();
    this.setState('hit'); this.stun = stun;
    this.vel.set(dx * push, 0, dz * push);
    this.facing = Math.atan2(-dx, -dz);
    this.hitFlip = !this.hitFlip;
    this.anim.play(this.hitFlip ? 'hit1' : 'hit2', { blend: 0.03, force: true });
    this.rig.fx.flash.value = 0.6;
  }

  enterDown(dx, dz, push) {
    this.interrupt();
    this.setState('down');
    this.vel.set(dx * push, 0, dz * push);
    this.facing = Math.atan2(-dx, -dz);
    this.anim.play('knockdown', { blend: 0.04, force: true });
    this.rig.fx.flash.value = 0.75;
    this.landed = false;
  }

  enterKO(dx, dz, push) {
    this.interrupt();
    this.setState('ko');
    this.vel.set(dx * (push + 4), 0, dz * (push + 4));
    this.facing = Math.atan2(-dx, -dz);
    this.anim.play('ko', { blend: 0.04, force: true });
    this.rig.fx.flash.value = 0.7;
    this.landed = false;
  }

  celebrate() { this.interrupt(); this.setState('win'); this.vel.set(0, 0, 0); this.anim.play('victory', { blend: 0.2, force: true }); }
  hold(clip = 'idle', blend = 0.2) { this.interrupt(); this.setState('still'); this.vel.set(0, 0, 0); this.anim.play(clip, { blend, force: true }); }
  release() { if (this.state === 'still' || this.state === 'win') this.toIdle(); }

  // ---- per-frame
  update(dt) {
    const w = this.world, it = this.intent, t0 = this.stateT;
    this.stateT += dt;
    const t = this.stateT;
    this.invuln = Math.max(0, this.invuln - dt);
    this.dashCd = Math.max(0, this.dashCd - dt);
    if (this.guardLock > 0) this.guardLock -= dt;
    if (this.buf && (this.buf.t -= dt) <= 0) this.buf = null;
    if (it.ult) this.buf = { a: 'ult', t: 0.3 };
    else if (it.dash) this.buf = { a: 'dash', t: 0.22 };
    else if (it.special) this.buf = { a: 'special', t: 0.3 };
    else if (it.light) this.buf = { a: 'light', t: 0.3 };
    const fighting = w.fightOn;
    if (fighting && this.state !== 'ko') this.gainEnergy(dt * 1.6);
    let friction = 10;

    switch (this.state) {
      case 'idle':
      case 'guard': {
        if (fighting && this.tryAct()) break;
        const guarding = fighting && (it.guard || this.guardLock > 0);
        if (guarding && this.state === 'idle') { this.setState('guard'); this.anim.play('guard', { blend: 0.07 }); w.audio.play('guardUp'); }
        else if (!guarding && this.state === 'guard' && t > 0.1) { this.setState('idle'); }
        const mag = Math.hypot(it.mx, it.mz);
        const sp = this.def.stats.speed * (this.state === 'guard' ? 0.34 : 1) * Math.min(1, mag);
        let tx = 0, tz = 0;
        if (mag > 0.15 && fighting) { tx = (it.mx / mag) * sp; tz = (it.mz / mag) * sp; }
        const k = Math.min(1, 14 * dt);
        this.vel.x += (tx - this.vel.x) * k; this.vel.z += (tz - this.vel.z) * k;
        friction = 0;
        if (this.state === 'guard') {
          if (this.target) this.turnToward(this.angleTo(this.target), 12, dt);
        } else if (mag > 0.15 && fighting) {
          this.turnToward(Math.atan2(it.mx, it.mz), 13, dt);
          this.anim.play('run', { blend: 0.12 });
          this.anim.runPhase += Math.hypot(this.vel.x, this.vel.z) * dt * 2.35;
          this.stepT = (this.stepT || 0) + Math.hypot(this.vel.x, this.vel.z) * dt;
          if (this.stepT > 1.35) { this.stepT = 0; w.audio.play('step'); }
        } else {
          if (this.target) this.turnToward(this.angleTo(this.target), 6, dt);
          this.anim.play('idle', { blend: 0.16 });
        }
        if (this.hitsTaken && t > 0.25) this.hitsTaken = 0;
        break;
      }
      case 'attack': this.runMove(dt, t0, t); break;
      case 'leap': this.runLeap(dt, t); friction = 0; break;
      case 'ult': this.runUlt(dt); friction = this.ult && this.ult.noFriction ? 0 : 12; break;
      case 'dash': {
        friction = t > 0.18 ? 16 : 0;
        if (Math.random() < 0.7) w.fx.emit(this.pos.x + rand(-0.3, 0.3), rand(0.3, 1.5), this.pos.z + rand(-0.3, 0.3), -this.vel.x * 0.1, 0, -this.vel.z * 0.1, _col.copy(this.color).multiplyScalar(3), 0.25, 0.09, 0, 0);
        if (t >= DASH_TIME) { this.toIdle(); }
        break;
      }
      case 'hit':
        friction = 7;
        if (t >= this.stun) this.toIdle();
        break;
      case 'down':
      case 'ko': {
        friction = 3.2;
        if (!this.landed && t > (this.state === 'ko' ? 0.62 : 0.44)) {
          this.landed = true;
          w.fx.dust(this.pos, 16, 4); w.audio.play('land'); w.cam.shake(0.25);
        }
        if (this.state === 'down' && t >= 0.95) { this.setState('getup'); this.anim.play('getup', { blend: 0.05, force: true, speed: 1.2 }); }
        break;
      }
      case 'getup':
        if (t >= 0.6) { this.toIdle(); this.invuln = 0.3; this.hitsTaken = 0; }
        break;
      default: break;
    }

    // integrate + keep inside the ring
    if (friction > 0) { const f = Math.max(0, 1 - friction * dt); this.vel.x *= f; this.vel.z *= f; }
    this.pos.x += this.vel.x * dt; this.pos.z += this.vel.z * dt;
    const r = Math.hypot(this.pos.x, this.pos.z);
    if (r > PLAY_RADIUS) {
      const nx = this.pos.x / r, nz = this.pos.z / r;
      const out = this.vel.x * nx + this.vel.z * nz;
      this.pos.x = nx * PLAY_RADIUS; this.pos.z = nz * PLAY_RADIUS;
      if (out > 5 && (this.state === 'down' || this.state === 'ko' || this.state === 'hit')) {
        w.arena.pulseBarrier(_a.set(nx * (ARENA_RADIUS + 0.1), 1.2, nz * (ARENA_RADIUS + 0.1)));
        w.fx.sparks(_a, 0x7fd8ff, 26, 7, { dir: _b.set(-nx, 0.4, -nz), spread: 0.8 });
        w.audio.play('barrier'); w.cam.shake(0.3);
        this.vel.x -= nx * out * 1.5; this.vel.z -= nz * out * 1.5;
      } else if (out > 0) { this.vel.x -= nx * out; this.vel.z -= nz * out; }
    }
    this.sync(dt);
  }

  sync(dt) {
    this.root.rotation.y = this.facing;
    this.anim.update(dt);
    const fxu = this.rig.fx;
    if (fxu.flash.value > 0) fxu.flash.value = Math.max(0, fxu.flash.value - dt * 7);
    this.rig.updateSecondary(dt, this.vel, this.facing, this.world.time);
    this.rig.blob.scale.setScalar(Math.max(0.3, 1 - this.pos.y * 0.2));
    this.rig.blob.position.y = 0.012 - this.pos.y;
    if (this.trail) this.trail.update(dt, this.rig.weapon.base, this.rig.weapon.tip);
    const light = this.world.fx.weaponLights[this.slot];
    if (light) {
      this.rig.weapon.muzzle.getWorldPosition(light.position);
      light.color.copy(this.color);
      const want = this.root.visible ? (this.busy ? 34 : 14) * (0.9 + 0.1 * Math.sin(this.world.time * 17 + this.slot)) : 0;
      light.intensity += (want - light.intensity) * Math.min(1, dt * 10 + (dt === 0 ? 1 : 0));
    }
  }

  tryAct() {
    const b = this.buf;
    if (!b) return false;
    if (b.a === 'ult' && this.energy >= 100) { this.startUlt(); return true; }
    if (b.a === 'dash' && this.dashCd <= 0) { this.startDash(); return true; }
    if (b.a === 'special' && this.energy >= this.def.special.cost) { this.startSpecial(); return true; }
    if (b.a === 'light') { this.startAttack(0); return true; }
    return false;
  }

  runMove(dt, t0, t) {
    const m = this.move, w = this.world, tg = this.target;
    const crossed = (x) => t0 < x && t >= x;
    this.armor = !!(m.armor && t >= m.armor[0] && t <= m.armor[1]);

    if (m.kind === 'melee' || m.kind === 'rush') {
      const [h0, h1] = m.hit;
      if (this.trail) this.trail.active = t >= h0 - 0.08 && t <= h1 + 0.05;
      if (!this.swung && t >= h0 - 0.05) { this.swung = true; w.audio.play(m.heavy ? 'swingHeavy' : 'swing'); }
      const win = m.rush || m.lunge;
      if (win && t >= win[0] && t <= win[1]) {
        const d = tg ? this.distTo(tg) : 99;
        const stop = m.through ? -1 : m.reach * 0.55;
        const sp = d > stop ? win[2] : 0;
        this.vel.set(this.dirX * sp, 0, this.dirZ * sp);
        if (m.rush && Math.random() < 0.9) w.fx.sparks(this.chest(_a), this.def.accent, 2, 3, { dir: _b.set(-this.dirX, 0.2, -this.dirZ), spread: 0.5, life: 0.35, grav: 0, size: 0.1 });
      }
      if (!this.hitDone && tg && t >= h0 && t <= h1 && this.inReach(tg, m.reach, m.arc)) {
        this.hitDone = true;
        w.resolveHit(this, tg, m, this.pos);
      }
      if (m.quake && crossed(h0 + 0.03)) {
        _a.set(this.pos.x + this.dirX * 2.2, 0, this.pos.z + this.dirZ * 2.2);
        w.fx.ring(_a, this.def.accent, 0.4, 3.0, 0.4); w.fx.dust(_a, 14, 5); w.cam.shake(0.45); w.audio.play('quake');
      }
      if (m.rush && crossed(win[1])) this.ghost = false;
    } else if (m.kind === 'shot' || m.kind === 'vault') {
      if (m.kind === 'vault') {
        const air = 0.36;
        if (t < air) { this.vel.set(-this.dirX * 10.5, 0, -this.dirZ * 10.5); this.pos.y = Math.sin((t / air) * Math.PI) * 1.0; }
        else if (t0 < air) { this.pos.y = 0; w.fx.dust(this.pos, 8, 3); }
      }
      while (this.fired < m.fire.length && t >= m.fire[this.fired][0]) {
        const hand = m.fire[this.fired][1];
        this.fired++;
        if (hand === 'fan') { for (let i = -2; i <= 2; i++) w.fireBolt(this, i & 1 ? 'L' : 'R', m, i * 0.2); }
        else w.fireBolt(this, hand, m, 0);
      }
    }

    // follow-ups
    const b = this.buf;
    if (b && w.fightOn) {
      const chainAt = m.chain ?? m.dur * 0.8;
      if (b.a === 'light' && this.comboIdx + 1 < this.def.combo.length && t >= chainAt) { this.startAttack(this.comboIdx + 1); return; }
      if (b.a === 'special' && this.comboIdx < 99 && t >= chainAt && this.energy >= this.def.special.cost) { this.startSpecial(); return; }
      if (b.a === 'ult' && t >= chainAt && this.energy >= 100) { this.startUlt(); return; }
      if (b.a === 'dash' && this.dashCd <= 0 && t >= (m.hit ? m.hit[1] : chainAt)) { this.startDash(); return; }
    }
    if (t >= m.dur) this.toIdle();
  }

  inReach(tg, reach, arc) {
    const d = this.distTo(tg);
    if (d > reach + 0.35 || tg.pos.y > 1.6) return false;
    if (d < 1.0) return true;
    return Math.abs(angDiff(this.facing, this.angleTo(tg))) <= arc / 2;
  }

  runLeap(dt, t) {
    const L = this.leap, m = this.move, w = this.world, wind = 0.16;
    this.vel.set(0, 0, 0);
    if (t >= wind && !L.landed) {
      const k = Math.min(1, (t - wind) / L.air);
      this.pos.x = L.fx + (L.tx - L.fx) * k; this.pos.z = L.fz + (L.tz - L.fz) * k;
      this.pos.y = Math.sin(k * Math.PI) * L.height;
      if (this.trail) this.trail.active = k > 0.5;
      if (k >= 1) {
        L.landed = true; L.landT = t; this.pos.y = 0;
        this.anim.play('slam', { blend: 0.02, force: true });
        _a.set(this.pos.x + this.dirX * 1.0, 0, this.pos.z + this.dirZ * 1.0);
        w.fx.ring(_a, this.def.accent, 0.5, m.radius * 1.15, 0.5, 0.2);
        w.fx.ring(_a, 0xffffff, 0.3, m.radius * 0.8, 0.35);
        w.fx.sparks(_b.set(_a.x, 0.3, _a.z), this.def.accent, 46, 10, { dir: _c.set(0, 1, 0), spread: 0.9, life: 0.7 });
        w.fx.dust(_a, 22, 7); w.fx.flash(_b, this.def.accent, 160, 0.35);
        w.cam.shake(0.8); w.audio.play('explosion'); w.arena.cheer(0.5);
        w.aoe(this, _a, m.radius, m);
      }
    }
    if (L.landed) {
      if (this.trail) this.trail.active = t - L.landT < 0.08;
      if (t - L.landT > 0.22) this.armor = false;
      if (t - L.landT >= 0.55) this.toIdle();
    }
  }

  // ---- ultimates
  runUlt(dt) {
    const u = this.ult, w = this.world, tg = this.target, def = this.def.ultimate, acc = this.def.accent;
    u.t += dt;
    if (u.phase === 'cutin') {
      this.chest(_a);
      w.fx.gather(_a, acc, 5, 2.4);
      w.fx.aura(this.pos, acc, 2, 0.8, 3);
      if (u.t >= CUT_IN) {
        u.phase = 'exec'; u.t = 0; u.step = 0; u.invuln = false;
        w.endCutIn(this);
        w.fx.ring(this.pos, acc, 0.5, 5, 0.5, 0.2);
        w.fx.flash(_a, acc, 200, 0.4);
      }
      return;
    }
    const t = u.t;
    const hitSpec = (frac, extra = {}) => ({ dmg: def.dmg * frac, stun: 0.34, push: 0.6, energy: 0, unblockable: true, heavy: true, ...extra });

    if (u.kind === 'flurry') {
      // blink in, six slashes, one finishing cut
      if (u.step === 0) {
        u.step = 1;
        if (tg && this.distTo(tg) < 13) {
          const a = this.angleTo(tg);
          w.fx.sparks(this.chest(_a), acc, 24, 6); w.fx.pillar(this.pos, acc, 0.5, 5, 0.25);
          this.pos.x = tg.pos.x - Math.sin(a) * 1.9; this.pos.z = tg.pos.z - Math.cos(a) * 1.9;
          this.facing = a;
          w.fx.sparks(this.chest(_a), acc, 24, 6);
          w.audio.play('dash');
        }
      }
      const n = 6, gap = 0.135, first = 0.06;
      if (u.step >= 1 && u.step <= n && t >= first + (u.step - 1) * gap) {
        const i = u.step - 1; u.step++;
        if (tg) this.turnToward(this.angleTo(tg), 99, 1);
        this.anim.play(i & 1 ? 'slashBack' : 'slashH', { speed: 2.6, blend: 0.03, force: true, at: 0.09 });
        if (this.trail) this.trail.active = true;
        w.audio.play('swing');
        w.fireWave(this, i & 1 ? 1.1 : -1.1);
        if (tg && this.inReach(tg, 3.3, 3.4)) w.resolveHit(this, tg, hitSpec(0.095, { quiet: i % 2 === 1 }), this.pos);
        this.vel.set(this.dirX * 3, 0, this.dirZ * 3);
      }
      if (u.step === n + 1 && t >= first + n * gap + 0.04) {
        u.step++;
        this.anim.play('overhead', { speed: 1.35, blend: 0.04, force: true });
        u.finalAt = t + 0.19;
      }
      if (u.step === n + 2 && t >= u.finalAt) {
        u.step++;
        w.audio.play('swingHeavy');
        _a.set(this.pos.x + this.dirX * 1.8, 0, this.pos.z + this.dirZ * 1.8);
        w.fx.ring(_a, acc, 0.4, 4.5, 0.45, 0.2); w.fx.pillar(_a, acc, 1.1, 12, 0.4);
        w.fx.sparks(_b.set(_a.x, 0.5, _a.z), acc, 50, 11, { life: 0.7 });
        w.cam.shake(0.9); w.audio.play('explosion');
        if (tg && this.inReach(tg, 3.6, 3.0)) w.resolveHit(this, tg, hitSpec(0.43, { launch: true, push: 10 }), this.pos);
      }
      if (u.step === n + 3 && t >= u.finalAt + 0.5) this.toIdle();
    } else if (u.kind === 'rain') {
      // nine spears of light fall where the rival stands
      const n = 9, gap = 0.15, delay = 0.44, radius = 1.9;
      if (!u.data.list) { u.data.list = []; this.armor = true; }
      if (u.step < n && t >= 0.08 + u.step * gap && tg) {
        const i = u.step++;
        const off = i === 0 ? 0 : rand(0, 1.3), oa = rand(TAU);
        const p = new THREE.Vector3(tg.pos.x + Math.cos(oa) * off + tg.vel.x * 0.15, 0, tg.pos.z + Math.sin(oa) * off + tg.vel.z * 0.15);
        const rr = Math.hypot(p.x, p.z); if (rr > PLAY_RADIUS) p.multiplyScalar(PLAY_RADIUS / rr);
        u.data.list.push({ p, at: t + delay, ring: w.fx.telegraph(p, acc, radius, delay + 0.05), done: false, last: i === n - 1 });
        w.audio.play('telegraph');
      }
      for (const s of u.data.list) {
        if (s.done || t < s.at) continue;
        s.done = true;
        s.ring.hold = false; s.ring.active = false; s.ring.mesh.visible = false;
        w.fx.pillar(s.p, acc, 1.0, 18, 0.3);
        w.fx.ring(s.p, acc, 0.4, radius * 1.5, 0.4);
        w.fx.sparks(_a.set(s.p.x, 0.3, s.p.z), acc, 26, 9, { dir: _b.set(0, 1, 0), spread: 0.8, life: 0.6 });
        w.fx.flash(_a.set(s.p.x, 1, s.p.z), acc, 120, 0.3);
        w.cam.shake(0.4); w.audio.play('strike');
        w.aoe(this, s.p, radius, hitSpec(1 / n, { launch: s.last, push: s.last ? 8 : 0.3 }));
      }
      this.rig.weapon.tip.getWorldPosition(_a);
      w.fx.aura(_a, acc, 2, 0.2, 4);
      if (t >= 0.08 + n * gap + delay + 0.35) this.toIdle();
    } else if (u.kind === 'beam') {
      // sustained twin-pistol beam that slowly tracks
      const start = 0.12, end = 1.45, ticks = 13;
      if (u.step === 0) { u.step = 1; this.anim.play('aimBoth', { blend: 0.08, force: true }); u.data.tick = 0; }
      if (t >= start && t < end) {
        if (!this.beamOn) { this.beamOn = true; w.audio.startLoop('beam'); w.audio.play('explosion'); }
        if (tg) this.turnToward(this.angleTo(tg), 0.85, dt);
        const k = Math.min(1, (t - start) * 8) * Math.min(1, (end - t) * 6);
        _a.set(this.pos.x + this.dirX * 0.75, 1.28 * this.rig.scale, this.pos.z + this.dirZ * 0.75);
        w.fx.setBeam(_a, this.facing, 30, 0.5 + 0.08 * Math.sin(t * 60), acc, k);
        w.fx.sparks(_a, acc, 3, 8, { dir: _b.set(this.dirX, 0, this.dirZ), spread: 0.25, grav: 0, life: 0.4, size: 0.1 });
        w.fx.flashLights[0].light.position.copy(_a); w.fx.flashLights[0].light.color.copy(this.color); w.fx.flashLights[0].peak = 140; w.fx.flashLights[0].t = 0; w.fx.flashLights[0].life = 0.2;
        w.cam.shake(0.18);
        this.vel.set(-this.dirX * 0.8, 0, -this.dirZ * 0.8);
        const due = Math.floor(((t - start) / (end - start)) * ticks);
        if (due > u.data.tick) {
          u.data.tick = due;
          if (tg) {
            const rx = tg.pos.x - this.pos.x, rz = tg.pos.z - this.pos.z;
            const along = rx * this.dirX + rz * this.dirZ, perp = Math.abs(rx * this.dirZ - rz * this.dirX);
            if (along > 0 && perp < 1.0 && tg.pos.y < 1.5) {
              const last = due >= ticks;
              w.resolveHit(this, tg, hitSpec(1 / ticks, { stun: 0.26, push: last ? 9 : 2.2, launch: last, quiet: due % 3 !== 0 }), this.pos);
            }
          }
        }
        // scorch the barrier where the beam ends
        if (Math.random() < 0.2) w.arena.pulseBarrier(_b.set(this.pos.x + this.dirX * 30, 1.3, this.pos.z + this.dirZ * 30).setLength(ARENA_RADIUS).setY(1.3));
      } else if (t >= end && this.beamOn) {
        this.beamOn = false; w.fx.setBeam(_a, 0, 0, 0, acc, 0); w.audio.stopLoop('beam');
        this.anim.play('idle', { blend: 0.25 });
      }
      if (t >= end + 0.35) this.toIdle();
    } else if (u.kind === 'meteor') {
      // vanish skyward, then come down on the rival like a falling star
      const rise = 0.42, lockAt = 0.9, hitAt = 1.25, radius = 4.3, H = 16;
      u.noFriction = true; this.vel.set(0, 0, 0);
      if (u.step === 0) {
        u.step = 1; u.invuln = true;
        this.anim.play('leap', { blend: 0.05, force: true, at: 0.1 });
        w.fx.ring(this.pos, acc, 0.4, 3.5, 0.4); w.fx.dust(this.pos, 18, 6); w.audio.play('whoosh');
        u.data.p = new THREE.Vector3(tg ? tg.pos.x : this.pos.x, 0, tg ? tg.pos.z : this.pos.z);
        u.data.ring = w.fx.telegraph(u.data.p, acc, radius, hitAt + 0.05);
        w.audio.play('telegraph');
      }
      if (t < rise) { this.pos.y = Math.pow(t / rise, 1.6) * H; if (this.trail) this.trail.active = true; }
      else if (t < hitAt - 0.14) { this.pos.y = H; this.root.visible = false; }
      if (t < lockAt && tg) { u.data.p.set(tg.pos.x, 0, tg.pos.z); u.data.ring.mesh.position.set(tg.pos.x, 0.035, tg.pos.z); }
      if (t >= hitAt - 0.14 && u.step === 1) {
        u.step = 2; this.root.visible = true;
        const a = tg ? Math.atan2(tg.pos.x - u.data.p.x, tg.pos.z - u.data.p.z) : this.facing;
        this.pos.x = u.data.p.x - Math.sin(this.facing) * 0.9; this.pos.z = u.data.p.z - Math.cos(this.facing) * 0.9;
        if (tg && this.distTo(tg) > 0.5) this.facing = this.angleTo(tg) || a;
      }
      if (u.step === 2) {
        const k = clamp((t - (hitAt - 0.14)) / 0.14, 0, 1);
        this.pos.y = H * (1 - k * k);
        w.fx.sparks(this.chest(_a), acc, 4, 3, { dir: _b.set(0, 1, 0), spread: 0.3, grav: 0, life: 0.4, size: 0.14 });
        if (k >= 1) {
          u.step = 3; u.invuln = false; this.pos.y = 0;
          this.anim.play('slam', { blend: 0.02, force: true });
          const p = u.data.p;
          const ringObj = u.data.ring; ringObj.hold = false; ringObj.active = false; ringObj.mesh.visible = false;
          w.fx.ring(p, acc, 0.6, radius * 1.5, 0.7, 0.22); w.fx.ring(p, 0xffffff, 0.4, radius, 0.45); w.fx.ring(p, acc, 0.2, radius * 2.1, 1.0, 0.08);
          w.fx.pillar(p, acc, 2.2, 22, 0.6);
          w.fx.sparks(_a.set(p.x, 0.4, p.z), acc, 110, 15, { dir: _b.set(0, 1, 0), spread: 1, life: 1.0, size: 0.13 });
          w.fx.dust(p, 30, 9); w.fx.flash(_a.set(p.x, 1.2, p.z), acc, 420, 0.6); w.fx.flare(_a, acc, 7, 0.4, 5);
          w.cam.shake(1.4); w.audio.play('explosion', { big: true }); w.arena.cheer(1);
          for (let i = 0; i < 4; i++) { const an = rand(TAU); w.arena.pulseBarrier(_b.set(Math.cos(an) * ARENA_RADIUS, 1.5, Math.sin(an) * ARENA_RADIUS)); }
          w.aoe(this, p, radius, hitSpec(1, { launch: true, push: 11 }));
        }
      }
      if (u.step === 3 && t >= hitAt + 0.65) this.toIdle();
    }
  }
}

// ------------------------------------------------------------ the duel world
export class Duel {
  /**
   * @param ctx { scene, fx, arena, audio, cam }
   */
  constructor(ctx, defA, defB) {
    Object.assign(this, ctx);
    this.time = 0;
    this.fightOn = false;
    this.listeners = [];
    this.projectiles = [];
    this.cutIn = null;
    this.hitStop = 0;
    this.a = new Fighter(defA, this, 0);
    this.b = new Fighter(defB, this, 1);
    this.a.target = this.b; this.b.target = this.a;
    this.fighters = [this.a, this.b];
    this.controllers = [null, null];
    this.place();
  }

  on(fn) { this.listeners.push(fn); }
  emit(type, data) { for (const fn of this.listeners) fn(type, data); }

  place() {
    this.a.reset(0, 3.4, Math.PI);
    this.b.reset(0, -3.4, 0);
    this.clearProjectiles();
    this.cutIn = null; this.hitStop = 0;
  }

  dispose() {
    for (const f of this.fighters) {
      this.scene.remove(f.root);
      if (f.trail) { this.scene.remove(f.trail.mesh); f.trail.mesh.geometry.dispose(); f.trail.mat.dispose(); }
      f.root.traverse((o) => {
        if (!o.isMesh) return;
        if (!o.geometry.userData.shared) o.geometry.dispose();
        const m = o.material;
        if (m !== Rig._blob) { if (m.map) m.map.dispose(); m.dispose(); }
      });
    }
    this.clearProjectiles();
    this.fx.setBeam(_a, 0, 0, 0, 0, 0);
    this.audio.stopLoop('beam');
    for (const l of this.fx.weaponLights) l.intensity = 0;
  }

  clearProjectiles() { for (const p of this.projectiles) this.fx.releaseBolt(p.bolt); this.projectiles.length = 0; }

  beginCutIn(f) { this.cutIn = { fighter: f }; this.emit('cutin', { fighter: f, name: f.def.ultimate.name }); this.audio.play('charge'); }
  endCutIn(f) { this.cutIn = null; this.emit('cutinEnd', { fighter: f }); }

  fireBolt(f, hand, m, yawOff) {
    const wpn = hand === 'L' && f.rig.weaponL ? f.rig.weaponL : f.rig.weapon;
    const p = { owner: f, pos: new THREE.Vector3(), yaw: f.facing + yawOff, speed: 30, homing: yawOff ? 0.5 : 1.25, radius: 0.28, spec: m, life: 1.4, kind: 'bolt', bolt: this.fx.acquireBolt(f.def.accent) };
    wpn.muzzle.getWorldPosition(p.pos);
    if (f.target && !yawOff) p.yaw = Math.atan2(f.target.pos.x - p.pos.x, f.target.pos.z - p.pos.z);
    p.y = p.pos.y;
    this.projectiles.push(p);
    this.fx.flare(p.pos, f.def.accent, 0.9, 0.09, 3);
    this.fx.sparks(p.pos, f.def.accent, 5, 5, { dir: _b.set(Math.sin(p.yaw), 0, Math.cos(p.yaw)), spread: 0.5, life: 0.2, grav: 0, size: 0.07 });
    this.fx.flash(p.pos, f.def.accent, 40, 0.12);
    this.audio.play('shot');
  }

  /** Cosmetic blade wave used by flurry ultimates. */
  fireWave(f, roll) {
    const p = { owner: f, pos: f.chest(new THREE.Vector3()), yaw: f.facing, speed: 24, homing: 0, radius: 0, spec: null, life: 0.5, kind: 'wave', bolt: this.fx.acquireBolt(f.def.accent, 'crescent', 1.5), roll };
    p.pos.x += f.dirX * 1.2; p.pos.z += f.dirZ * 1.2; p.y = p.pos.y;
    this.projectiles.push(p);
  }

  aoe(attacker, center, radius, spec) {
    const tg = attacker.target;
    if (!tg) return;
    const d = Math.hypot(tg.pos.x - center.x, tg.pos.z - center.z);
    if (d <= radius + 0.35 && tg.pos.y < 1.6) this.resolveHit(attacker, tg, spec, d < 0.3 ? attacker.pos : center);
  }

  resolveHit(attacker, target, spec, from) {
    const res = target.takeHit(spec, attacker, from);
    if (res.type === 'miss') return res;
    const fx = this.fx, acc = attacker.def.accent;
    const p = target.chest(_a);
    _b.set(from.x - target.pos.x, 0, from.z - target.pos.z).normalize();
    p.addScaledVector(_b, 0.35);
    const away = _c.set(-_b.x, 0.35, -_b.z);
    if (res.type === 'parry') {
      fx.flare(p, 0xffffff, 3.6, 0.3, 5); fx.sparks(p, 0xffffff, 40, 10, { life: 0.5 }); fx.ring(target.pos, 0xffffff, 0.4, 3.2, 0.35);
      fx.flash(p, 0xffffff, 200, 0.3);
      this.audio.play('parry'); this.hitStop = 0.16; this.cam.shake(0.5);
      target.gainEnergy(15); target.guardLock = 0; target.setState('idle');
      if (!spec.projectile && attacker.state !== 'ult') attacker.stagger(0.8);
      this.arena.cheer(0.5);
      this.emit('parry', { fighter: target });
      return res;
    }
    if (res.type === 'guard') {
      fx.sparks(p, 0xbfe6ff, 14, 7, { dir: _b, spread: 0.8, life: 0.3 }); fx.flare(p, 0xbfe6ff, 1.3, 0.12, 2);
      this.audio.play('block'); this.hitStop = Math.max(this.hitStop, 0.035); this.cam.shake(0.14);
      attacker.gainEnergy((spec.energy || 0) * 0.35); target.gainEnergy(3);
      this.emit('guard', { fighter: target, dmg: res.dmg });
      return res;
    }
    const heavy = !!(spec.heavy || spec.launch);
    if (res.type === 'armor') {
      fx.sparks(p, acc, 10, 6, { dir: away, spread: 0.8, life: 0.3 });
      this.audio.play('block'); this.hitStop = Math.max(this.hitStop, 0.04);
      attacker.gainEnergy((spec.energy || 0) * 0.7); target.gainEnergy(4);
      this.emit('hit', { attacker, target, dmg: res.dmg, pos: p, armor: true });
      return res;
    }
    // clean hit
    fx.sparks(p, acc, heavy ? 34 : 18, heavy ? 11 : 8, { dir: away, spread: 0.75, life: heavy ? 0.6 : 0.4 });
    fx.flare(p, acc, heavy ? 2.6 : 1.6, res.ko ? 0.05 : heavy ? 0.2 : 0.13, 3);
    fx.flash(p, acc, heavy ? 80 : 36, 0.2);
    if (heavy) fx.ring(target.pos, acc, 0.3, 2.6, 0.32);
    if (!spec.quiet) this.audio.play(heavy ? 'hitHeavy' : 'hit');
    this.hitStop = Math.max(this.hitStop, res.ko ? 0.22 : heavy ? 0.1 : 0.055);
    this.cam.shake(res.ko ? 1.0 : heavy ? 0.55 : 0.26);
    attacker.gainEnergy(spec.energy || 0); target.gainEnergy((spec.energy || 0) * 0.55 + 2.5);
    attacker.combo = target.hitsTaken; attacker.comboT = 1.4;
    if (heavy) this.arena.cheer(0.35);
    this.emit('hit', { attacker, target, dmg: res.dmg, pos: p, heavy, broke: res.broke, combo: attacker.combo });
    if (res.wind) {
      fx.ring(target.pos, 0x9dffb0, 0.4, 3.4, 0.6, 0.2); fx.pillar(target.pos, 0x9dffb0, 0.9, 7, 0.6); fx.aura(target.pos, 0x9dffb0, 24, 0.8, 4);
      this.audio.play('levelUp');
      this.emit('wind', { fighter: target });
    }
    if (res.ko) {
      this.fightOn = false;
      target.rig.sigil.getWorldPosition(_b);
      fx.shatter(_b, target.def.accent);
      this.audio.play('shatter'); this.audio.play('ko');
      this.arena.cheer(1.5);
      this.emit('ko', { winner: attacker, loser: target });
    }
    return res;
  }

  updateProjectiles(dt) {
    const list = this.projectiles;
    for (let i = list.length - 1; i >= 0; i--) {
      const p = list[i];
      p.life -= dt;
      const tg = p.owner.target;
      if (p.homing && tg) {
        const want = Math.atan2(tg.pos.x - p.pos.x, tg.pos.z - p.pos.z);
        const d = angDiff(p.yaw, want), step = p.homing * dt;
        if (Math.abs(d) < 1.2) p.yaw += Math.abs(d) < step ? d : Math.sign(d) * step;
      }
      const dx = Math.sin(p.yaw), dz = Math.cos(p.yaw);
      p.pos.x += dx * p.speed * dt; p.pos.z += dz * p.speed * dt;
      let dead = p.life <= 0;
      if (p.bolt) {
        p.bolt.mesh.position.copy(p.pos);
        p.bolt.mesh.rotation.set(0, p.yaw, p.roll || 0, 'YXZ');
        if (p.kind === 'wave') { const k = Math.max(0, p.life / 0.5); p.bolt.mat.opacity = k; p.bolt.mesh.scale.setScalar(1.5 + (1 - k) * 1.2); }
      }
      if (p.kind === 'bolt') {
        if (Math.random() < 0.8) this.fx.emit(p.pos.x, p.pos.y, p.pos.z, rand(-0.5, 0.5), rand(-0.5, 0.5), rand(-0.5, 0.5), _col.copy(p.owner.color).multiplyScalar(3), 0.22, 0.09, 0, 0);
        if (tg && tg.pos.y < 1.3 && Math.hypot(tg.pos.x - p.pos.x, tg.pos.z - p.pos.z) < p.radius + 0.45) {
          _b.set(p.pos.x - dx * 2, 0, p.pos.z - dz * 2);
          const res = this.resolveHit(p.owner, tg, { ...p.spec, projectile: true }, _b);
          if (res.type !== 'miss') dead = true;
        }
      }
      const r = Math.hypot(p.pos.x, p.pos.z);
      if (r > ARENA_RADIUS && !dead) {
        dead = true;
        this.arena.pulseBarrier(p.pos);
        this.fx.sparks(p.pos, p.owner.def.accent, 10, 5, { dir: _b.set(-dx, 0.2, -dz), spread: 0.8, life: 0.3 });
      }
      if (dead) { this.fx.releaseBolt(p.bolt); list.splice(i, 1); }
    }
  }

  /** Advance the duel. Returns the dt actually simulated (0 during hit-stop). */
  update(dt) {
    if (this.hitStop > 0) { this.hitStop -= dt; return 0; }
    this.time += dt;
    const [a, b] = this.fighters;
    if (this.cutIn) {
      // the world holds its breath while an ultimate charges
      const f = this.cutIn.fighter;
      f.update(dt);
      (f === a ? b : a).sync(0);
      return dt;
    }
    for (let i = 0; i < 2; i++) {
      const c = this.controllers[i], f = this.fighters[i];
      if (c && this.fightOn) c.update(dt, f, this);
      else { const it = f.intent; it.mx = it.mz = 0; it.light = it.special = it.dash = it.ult = it.guard = false; }
    }
    a.update(dt); b.update(dt);
    // keep the duelists from overlapping
    if (!a.ghost && !b.ghost && a.pos.y < 1 && b.pos.y < 1 && a.root.visible && b.root.visible) {
      const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z, d = Math.hypot(dx, dz), min = 0.85;
      if (d < min && d > 1e-4) {
        const push = (min - d) / 2, nx = dx / d, nz = dz / d;
        const ka = a.state === 'ko' || a.state === 'down' ? 0 : 1, kb = b.state === 'ko' || b.state === 'down' ? 0 : 1;
        if (ka + kb > 0) {
          a.pos.x -= nx * push * (ka * 2 / (ka + kb)); a.pos.z -= nz * push * (ka * 2 / (ka + kb));
          b.pos.x += nx * push * (kb * 2 / (ka + kb)); b.pos.z += nz * push * (kb * 2 / (ka + kb));
        }
      }
    }
    this.updateProjectiles(dt);
    for (const f of this.fighters) { if (f.comboT > 0) { f.comboT -= dt; if (f.comboT <= 0 || (f.target.hitsTaken === 0 && f.target.canAct)) f.combo = 0; } }
    return dt;
  }
}
