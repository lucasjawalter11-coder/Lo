// Who drives a fighter: the player's input device, or the rival AI.
import { rand } from './fx.js';
import { PLAY_RADIUS } from './arena.js';

export class PlayerController {
  constructor(input, camRig) { this.input = input; this.camRig = camRig; }
  update(dt, f) {
    const s = this.input, it = f.intent, c = this.camRig;
    // stick is camera-relative: up = away from the camera
    it.mx = s.x * c.right.x + s.y * c.forward.x;
    it.mz = s.x * c.right.z + s.y * c.forward.z;
    it.light = s.take('light'); it.special = s.take('special'); it.dash = s.take('dash'); it.ult = s.take('ult');
    it.guard = s.guard;
  }
}

const LEVELS = [
  { react: 0.46, aggro: 0.3, guard: 0.1, dodge: 0.05, combo: 0.45, special: 0.1, ult: 0.35, pause: 1.0 },
  { react: 0.32, aggro: 0.5, guard: 0.28, dodge: 0.13, combo: 0.72, special: 0.28, ult: 0.65, pause: 0.6 },
  { react: 0.21, aggro: 0.68, guard: 0.46, dodge: 0.25, combo: 0.9, special: 0.48, ult: 0.9, pause: 0.35 },
  { react: 0.14, aggro: 0.82, guard: 0.6, dodge: 0.36, combo: 1.0, special: 0.62, ult: 1.0, pause: 0.2 },
];

export class AIController {
  constructor(level = 1) {
    this.level = level;
    this.L = LEVELS[Math.max(0, Math.min(LEVELS.length - 1, level))];
    this.mode = 'approach'; this.modeT = 0.4;
    this.seen = -1; this.react = null; this.guardT = 0;
    this.strafe = Math.random() < 0.5 ? 1 : -1;
    this.plan = 0; this.cool = 0.6; this.evade = false; this.evadeDir = 1;
  }

  update(dt, f) {
    const it = f.intent, foe = f.target, L = this.L;
    it.light = it.special = it.dash = it.ult = false; it.guard = false; it.mx = 0; it.mz = 0;
    if (!foe) return;
    const d = f.distTo(foe), ang = f.angleTo(foe);
    const tx = Math.sin(ang), tz = Math.cos(ang), px = tz * this.strafe, pz = -tx * this.strafe;
    const ranged = f.def.weapon === 'pistol';
    const range = f.def.range;
    const move = (x, z) => { const l = Math.hypot(x, z) || 1; it.mx = x / l; it.mz = z / l; };
    this.modeT -= dt; this.cool -= dt;

    // ---- notice the rival starting something
    if (foe.serial !== this.seen) {
      this.seen = foe.serial;
      if (foe.busy) {
        const big = foe.state === 'ult' || foe.state === 'leap';
        const reach = (foe.move && foe.move.reach ? foe.move.reach : foe.def.range) + 1.6 + (big ? 30 : 0) + (foe.def.weapon === 'pistol' ? 30 : 0);
        if (d < reach) {
          const r = Math.random(), t = L.react * rand(0.7, 1.25);
          const noBlock = big || (foe.move && foe.move.guardBreak);
          if (big) { this.evade = Math.random() < 0.2 + L.dodge * 1.9; this.evadeDir = Math.random() < 0.5 ? 1 : -1; }
          if (noBlock) { if (r < L.dodge * 1.8 + 0.08) this.react = { a: 'dash', t }; }
          else if (r < L.guard) this.react = { a: 'guard', t, hold: rand(0.35, 0.65) };
          else if (r < L.guard + L.dodge) this.react = { a: 'dash', t };
        }
      }
    }
    if (foe.state !== 'ult') this.evade = this.evade && foe.state === 'leap';

    if (this.react) {
      this.react.t -= dt;
      if (this.react.t <= 0) {
        if (this.react.a === 'guard') this.guardT = this.react.hold;
        else if (f.canAct || f.state === 'attack') { this.strafe = Math.random() < 0.5 ? 1 : -1; move(tz * this.strafe - tx * 0.4, -tx * this.strafe - tz * 0.4); it.dash = true; this.react = null; return; }
        this.react = null;
      }
    }

    // ---- surviving an ultimate
    if (this.evade && foe.ult && foe.ult.phase === 'exec') {
      const kind = foe.ult.kind;
      if (kind === 'meteor' || kind === 'rain') move(tz * this.evadeDir + tx * 0.2, -tx * this.evadeDir + tz * 0.2);
      else move(tz * this.evadeDir - tx * 0.3, -tx * this.evadeDir - tz * 0.3);
      this.avoidEdge(f, it);
      if (f.dashCd <= 0 && Math.random() < dt * (2 + L.dodge * 8)) it.dash = true;
      return;
    }

    if (this.guardT > 0) {
      this.guardT -= dt;
      it.guard = true;
      if (!foe.threatening && this.guardT < 0.3) this.guardT = 0;
      // answer a blocked string
      if (this.guardT <= 0 && d < range + 0.4 && Math.random() < L.aggro) { it.light = true; this.plan = this.pickPlan(f); }
      return;
    }

    // ---- mid-attack: keep the string going
    if (f.state === 'attack') {
      if (f.comboIdx < 99 && f.comboIdx + 1 < this.plan) it.light = true;
      else if (f.comboIdx < 99 && f.hitDone && f.comboIdx === f.def.combo.length - 2 && f.energy >= f.def.special.cost && Math.random() < L.special * dt * 6 && f.def.special.kind === 'rush') it.special = true;
      return;
    }
    if (!f.canAct) return;

    // ---- ultimate
    if (f.energy >= 100 && foe.vulnerable && Math.random() < L.ult * dt * 1.6) {
      const kind = f.def.ultimate.kind;
      if ((kind === 'flurry' && d < 9) || kind === 'rain' || kind === 'meteor' || (kind === 'beam' && d > 2.5)) { it.ult = true; return; }
    }

    const foeDown = foe.state === 'down' || foe.state === 'getup' || foe.state === 'ko';

    if (ranged) {
      // keep the ring between us
      if (d < 4.2 && !foeDown) {
        if (f.energy >= f.def.special.cost && Math.random() < L.special * dt * 5) { it.special = true; return; }
        if (f.dashCd <= 0 && Math.random() < (0.5 + L.dodge) * dt * 4) { move(-tx + px * 0.5, -tz + pz * 0.5); it.dash = true; return; }
        move(-tx + px * 0.7, -tz + pz * 0.7);
      } else if (d > 10.5) move(tx + px * 0.3, tz + pz * 0.3);
      else if (this.mode === 'circle') move(px + tx * (d > 8 ? 0.3 : -0.2), pz + tz * (d > 8 ? 0.3 : -0.2));
      this.avoidEdge(f, it);
      if (!foeDown && this.cool <= 0 && d > 2.5 && Math.random() < L.aggro * dt * 7) {
        it.light = true; this.plan = this.pickPlan(f); this.cool = L.pause * rand(0.6, 1.4) + 0.25;
      }
      if (this.modeT <= 0) { this.mode = Math.random() < 0.7 ? 'circle' : 'hold'; this.modeT = rand(0.6, 1.6); if (Math.random() < 0.4) this.strafe *= -1; }
      return;
    }

    // ---- melee
    if (this.modeT <= 0) {
      const r = Math.random();
      this.mode = r < L.aggro ? 'approach' : r < L.aggro + (1 - L.aggro) * 0.65 ? 'circle' : 'wait';
      this.modeT = this.mode === 'approach' ? rand(1.2, 2.6) : rand(0.5, 1.2);
      if (Math.random() < 0.5) this.strafe *= -1;
    }
    // punish a whiff or a recovering rival
    const punish = foe.state === 'attack' && foe.move && foe.move.hit && foe.stateT > foe.move.hit[1] && d < range + 0.6;
    if (punish && this.cool <= 0.2 && Math.random() < L.aggro * dt * 14) { it.light = true; this.plan = f.def.combo.length; this.cool = L.pause; return; }

    if (foeDown) {
      // hover just outside their reach until they are back up
      if (d > range + 1.6) move(tx, tz); else if (d < range + 0.6) move(-tx + px * 0.5, -tz + pz * 0.5); else move(px, pz);
      this.avoidEdge(f, it);
      return;
    }
    const sp = f.def.special;
    if (f.energy >= sp.cost && this.cool <= 0 && d > 2.6 && d < (sp.kind === 'leap' ? 7.5 : 6.2) && Math.random() < L.special * dt * 2.2) { it.special = true; this.cool = L.pause + 0.4; return; }

    if (this.mode === 'approach') {
      if (d > range * 0.92) {
        move(tx + px * 0.22, tz + pz * 0.22);
        if (d > 6.5 && f.dashCd <= 0 && Math.random() < L.aggro * dt * 1.5) it.dash = true;
      } else if (this.cool <= 0) {
        it.light = true; this.plan = this.pickPlan(f);
        this.cool = L.pause * rand(0.7, 1.5) + 0.35;
        if (Math.random() > L.aggro) { this.mode = Math.random() < 0.5 ? 'circle' : 'wait'; this.modeT = rand(0.5, 1.1); }
      } else move(px - tx * 0.15, pz - tz * 0.15);
    } else if (this.mode === 'circle') {
      const want = range + 1.6;
      move(px + tx * (d > want ? 0.5 : -0.5), pz + tz * (d > want ? 0.5 : -0.5));
    } else if (d < range + 0.5 && Math.random() < L.guard * dt * 3) {
      this.guardT = rand(0.3, 0.6);
    }
    this.avoidEdge(f, it);
  }

  pickPlan(f) {
    let n = 1;
    while (n < f.def.combo.length && Math.random() < this.L.combo) n++;
    return n;
  }

  avoidEdge(f, it) {
    const r = Math.hypot(f.pos.x, f.pos.z);
    if (r > PLAY_RADIUS - 2.2) {
      const nx = f.pos.x / r, nz = f.pos.z / r, out = it.mx * nx + it.mz * nz;
      if (out > -0.2) { it.mx -= nx * (out + 0.6); it.mz -= nz * (out + 0.6); const l = Math.hypot(it.mx, it.mz) || 1; it.mx /= l; it.mz /= l; }
    }
  }
}
