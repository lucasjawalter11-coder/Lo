// Pose library and animator. Poses are authored as joint Euler angles and blended procedurally.
//
// Conventions (character faces +Z, its left is +X):
//   torso joints  rx+ lean forward, ry+ turn left, rz+ tilt to the right
//   arms / legs   hang along -Y; rx- swings forward; rz+ moves toward +X (out for the left side)
//   elbows        rx- flexes;  knees rx+ flexes;  feet rx+ points the toes down
//   weapon hand   rx = 0 weapon perpendicular to the forearm, rx = PI/2 in line with it
import { JOINTS } from './character.js';

const NJ = JOINTS.length;
export const POSE_SIZE = NJ * 3 + 5;
const IDX = Object.fromEntries(JOINTS.map((n, i) => [n, i * 3]));
const PX = NJ * 3, PY = PX + 1, PZ = PX + 2, TWO = PX + 3, GROUND = PX + 4;

/** Merge sparse pose objects (later wins) into a pose array. */
function P(...parts) {
  const out = new Float32Array(POSE_SIZE);
  out[TWO] = 1; out[GROUND] = 1;
  for (const part of parts) {
    if (!part) continue;
    for (const k in part) {
      const v = part[k];
      if (k === 'px') out[PX] = v;
      else if (k === 'py') out[PY] = v;
      else if (k === 'pz') out[PZ] = v;
      else if (k === 'two') out[TWO] = v;
      else if (k === 'ground') out[GROUND] = v;
      else { const i = IDX[k]; out[i] = v[0] || 0; out[i + 1] = v[1] || 0; out[i + 2] = v[2] || 0; }
    }
  }
  return out;
}

const EASE = {
  io: (u) => u * u * (3 - 2 * u),
  i: (u) => u * u,
  o: (u) => 1 - (1 - u) * (1 - u),
  l: (u) => u,
  snap: (u) => 1 - Math.pow(1 - u, 3),
};

const keys = (list, opts = {}) => ({
  type: 'keys',
  keys: list.map(([t, p, e]) => ({ t, p, e: EASE[e || 'io'] })),
  dur: list[list.length - 1][0],
  loop: !!opts.loop,
});

// ------------------------------------------------------------ building blocks
const LEGS = {
  hips: [0, -0.38, 0],
  legL: [-0.42, 0.38, 0.1], kneeL: [0.72, 0, 0], footL: [-0.3, 0, 0],
  legR: [0.26, 0, -0.16], kneeR: [0.3, 0, 0], footR: [-0.56, 0, 0],
};
const TORSO = { spine: [0.08, 0.12, 0], chest: [0.04, 0.22, 0], neck: [0, 0.04, 0], head: [-0.03, 0.0, 0] };

const UPPER = {
  saber: { armR: [-0.55, 0, -0.25], elbowR: [-1.25, 0, 0], handR: [1.1, 0, 0], armL: [-0.2, 0, 0.32], elbowL: [-1.05, 0, 0] },
  spear: { armR: [0.3, 0, -0.28], elbowR: [-1.35, 0, 0], handR: [0.95, 0, 0], armL: [-0.6, 0, 0.1], elbowL: [-0.8, 0, 0] },
  hammer: { armR: [-0.25, 0, -0.3], elbowR: [-1.05, 0, 0], handR: [0.55, 0, 0], armL: [-0.5, 0, 0.1], elbowL: [-0.9, 0, 0] },
  pistol: { armR: [-0.3, 0, -0.32], elbowR: [-1.95, 0, 0], handR: [0.65, 0, 0], armL: [-0.3, 0, 0.32], elbowL: [-1.95, 0, 0], handL: [0.65, 0, 0] },
};

const GUARD_UPPER = {
  saber: { spine: [0.12, 0.1, 0], chest: [0.06, 0.25, 0], armR: [-1.25, 0, 0.55], elbowR: [-1.45, 0, 0], handR: [0.95, 0, 0], armL: [-1.25, 0, -0.3], elbowL: [-1.5, 0, 0] },
  spear: { spine: [0.1, 0.1, 0], chest: [0.05, 0.2, 0], armR: [-0.9, 0, -0.35], elbowR: [-1.2, 0, 0], handR: [0.2, 0.9, 0], armL: [-1.0, 0, 0.3], elbowL: [-1.0, 0, 0] },
  hammer: { spine: [0.12, 0.1, 0], chest: [0.06, 0.2, 0], armR: [-0.95, 0, -0.3], elbowR: [-1.25, 0, 0], handR: [0.25, 0.9, 0], armL: [-1.0, 0, 0.3], elbowL: [-1.0, 0, 0] },
  pistol: { spine: [0.14, 0.1, 0], chest: [0.08, 0.2, 0], armR: [-1.2, 0, 0.62], elbowR: [-1.7, 0, 0], handR: [0.6, 0, 0], armL: [-1.2, 0, -0.62], elbowL: [-1.7, 0, 0], handL: [0.6, 0, 0] },
};

const RUN_ARM = {
  saber: { armR: [0.85, 0, -0.32], elbowR: [-0.25, 0, 0], handR: [1.45, 0, 0] },
  spear: { armR: [0.55, 0, -0.3], elbowR: [-0.7, 0, 0], handR: [1.2, 0, 0] },
  hammer: { armR: [0.5, 0, -0.35], elbowR: [-0.75, 0, 0], handR: [1.35, 0, 0] },
  pistol: { armR: [0.5, 0, -0.3], elbowR: [-1.2, 0, 0], handR: [1.0, 0, 0] },
};

function makeClips(weapon) {
  const up = UPPER[weapon];
  const IDLE = P(LEGS, TORSO, up);
  const two = weapon === 'spear' || weapon === 'hammer';
  const pistol = weapon === 'pistol';
  const c = {};

  c.idle = { type: 'fn', loop: true, fn: (out, t) => {
    out.set(IDLE);
    const b = Math.sin(t * 2.1), b2 = Math.sin(t * 1.05 + 0.6);
    out[IDX.chest] += b * 0.018; out[IDX.spine] += b * 0.01;
    out[IDX.armR] += b * 0.02; out[IDX.armL] += b * 0.025; out[IDX.elbowL] += b2 * 0.03;
    out[IDX.handR] += b2 * 0.04;
    out[IDX.head + 1] += b2 * 0.03;
    out[PY] += b * 0.004;
  } };

  // ---- locomotion (phase driven by distance travelled)
  c.run = { type: 'fn', loop: true, fn: (out, t, anim) => {
    const ph = anim.runPhase, s = Math.sin(ph), co = Math.cos(ph);
    out.fill(0); out[TWO] = two ? 0.85 : 0; out[GROUND] = 1;
    const set = (name, x, y = 0, z = 0) => { const i = IDX[name]; out[i] = x; out[i + 1] = y; out[i + 2] = z; };
    set('hips', 0.32, -0.16 * s, 0);
    set('spine', 0.1, 0.1 * s, 0);
    set('chest', 0.05, 0.22 * s, 0);
    set('head', -0.3, 0, 0);
    const hipL = -0.3 - 0.9 * s, kneeL = 0.35 + 1.15 * Math.max(0, co);
    const hipR = -0.3 + 0.9 * s, kneeR = 0.35 + 1.15 * Math.max(0, -co);
    set('legL', hipL, 0, 0.04); set('kneeL', kneeL); set('footL', -(hipL + kneeL) * 0.55 - 0.3 + 0.5 * Math.max(0, -s));
    set('legR', hipR, 0, -0.04); set('kneeR', kneeR); set('footR', -(hipR + kneeR) * 0.55 - 0.3 + 0.5 * Math.max(0, s));
    set('armL', 0.1 + 0.95 * s, 0, 0.22); set('elbowL', -1.35 - 0.25 * s);
    const ra = RUN_ARM[weapon];
    set('armR', ra.armR[0] - 0.22 * s, 0, ra.armR[2]); set('elbowR', ra.elbowR[0]); set('handR', ra.handR[0]);
    if (pistol) { set('armL', 0.5 + 0.22 * s, 0, 0.3); set('elbowL', -1.2); set('handL', 1.0); }
    out[PY] = Math.abs(co) * 0.035;
  } };

  const DASH = P({
    hips: [0.62, 0, 0], spine: [0.15, 0, 0], head: [-0.55, 0, 0],
    legL: [-1.15, 0, 0.05], kneeL: [1.25, 0, 0], footL: [0.3, 0, 0],
    legR: [0.75, 0, -0.05], kneeR: [0.55, 0, 0], footR: [0.7, 0, 0],
    armL: [1.05, 0, 0.3], elbowL: [-0.2, 0, 0], armR: [0.95, 0, -0.32], elbowR: [-0.2, 0, 0], handR: [1.5, 0, 0], handL: [1.4, 0, 0],
    two: 0,
  });
  c.dash = keys([[0, DASH], [0.3, DASH]]);

  const GUARD = P(LEGS, TORSO, GUARD_UPPER[weapon], { hips: [0.06, -0.3, 0] });
  c.guard = { type: 'fn', loop: true, fn: (out, t) => { out.set(GUARD); out[IDX.chest] += Math.sin(t * 9) * 0.006; } };
  const GUARD_HIT = P(LEGS, TORSO, GUARD_UPPER[weapon], { hips: [-0.06, -0.3, 0], spine: [-0.08, 0.1, 0], pz: -0.12 });
  c.guardHit = keys([[0, GUARD_HIT, 'snap'], [0.06, GUARD_HIT], [0.22, GUARD]]);

  // ---- reactions
  const HIT1 = P(LEGS, {
    hips: [-0.2, -0.1, 0], pz: -0.12, spine: [-0.25, 0.15, 0], chest: [-0.3, 0.25, 0.1], head: [-0.35, 0.3, 0],
    armR: [0.3, 0, -0.75], elbowR: [-0.9, 0, 0], handR: [0.8, 0, 0], armL: [0.3, 0, 0.85], elbowL: [-0.7, 0, 0], handL: [0.6, 0, 0],
    legR: [0.4, 0, -0.16], kneeR: [0.55, 0, 0], footR: [-0.8, 0, 0], two: 0,
  });
  const HIT2 = P(LEGS, {
    hips: [0.1, -0.55, 0], pz: -0.1, spine: [0.32, -0.2, 0], chest: [0.3, -0.2, -0.1], head: [0.3, 0.2, 0],
    armR: [-0.4, 0, -0.5], elbowR: [-1.3, 0, 0], handR: [0.8, 0, 0], armL: [-0.5, 0, 0.3], elbowL: [-1.6, 0, 0], handL: [0.6, 0, 0], two: 0,
  });
  c.hit1 = keys([[0, HIT1, 'snap'], [0.07, HIT1], [0.2, HIT1], [0.42, IDLE]]);
  c.hit2 = keys([[0, HIT2, 'snap'], [0.07, HIT2], [0.2, HIT2], [0.42, IDLE]]);

  const AIR1 = P({
    hips: [-0.6, 0, 0], py: 0.12, ground: 0, spine: [-0.2, 0, 0], chest: [-0.2, 0, 0], head: [0.35, 0, 0],
    armR: [-1.2, 0, -0.5], elbowR: [-0.4, 0, 0], handR: [0.9, 0, 0], armL: [-1.2, 0, 0.5], elbowL: [-0.4, 0, 0], handL: [0.8, 0, 0],
    legL: [-0.9, 0, 0.1], kneeL: [0.6, 0, 0], legR: [-0.5, 0, -0.1], kneeR: [0.9, 0, 0], two: 0,
  });
  const AIR2 = P({
    hips: [-1.35, 0, 0], py: -0.5, ground: 0, spine: [-0.1, 0, 0], head: [0.3, 0, 0],
    armR: [-0.4, 0, -1.2], elbowR: [-0.3, 0, 0], handR: [1.0, 0, 0], armL: [-0.4, 0, 1.2], elbowL: [-0.3, 0, 0], handL: [0.8, 0, 0],
    legL: [-1.0, 0, 0.1], kneeL: [0.5, 0, 0], legR: [-0.7, 0, -0.1], kneeR: [0.8, 0, 0], two: 0,
  });
  const DOWN = P({
    hips: [-1.57, 0, 0], py: -0.83, ground: 0, spine: [0.08, 0, 0], chest: [0.05, 0, 0], head: [0.1, 0.25, 0],
    armR: [-0.12, 0, -1.05], elbowR: [-0.5, 0, 0], handR: [1.2, 0.4, 0], armL: [-0.1, 0, 1.15], elbowL: [-0.45, 0, 0], handL: [0.8, 0, 0],
    legL: [-0.3, 0, 0.16], kneeL: [0.55, 0, 0], footL: [0.5, 0, 0], legR: [-0.06, 0, -0.2], kneeR: [0.14, 0, 0], footR: [0.6, 0, 0], two: 0,
  });
  const DOWN_BOUNCE = P();
  DOWN_BOUNCE.set(DOWN); DOWN_BOUNCE[PY] = -0.74; DOWN_BOUNCE[IDX.legL] = -0.6; DOWN_BOUNCE[IDX.legR] = -0.4; DOWN_BOUNCE[IDX.armR] = -0.5; DOWN_BOUNCE[IDX.armL] = -0.5;
  c.knockdown = keys([[0, AIR1, 'snap'], [0.1, AIR1], [0.34, AIR2, 'l'], [0.46, DOWN, 'i'], [0.56, DOWN_BOUNCE, 'o'], [0.68, DOWN, 'i'], [0.9, DOWN]]);
  const KO_DOWN = P();
  KO_DOWN.set(DOWN);
  KO_DOWN[IDX.head + 1] = -0.5; KO_DOWN[IDX.legL] = -0.75; KO_DOWN[IDX.kneeL] = 1.3; KO_DOWN[IDX.footL] = 0.1; KO_DOWN[IDX.armR + 2] = -1.35; KO_DOWN[IDX.armL + 2] = 0.6;
  c.ko = keys([[0, AIR1, 'snap'], [0.16, AIR1], [0.5, AIR2, 'l'], [0.66, DOWN, 'i'], [0.8, DOWN_BOUNCE, 'o'], [0.98, KO_DOWN, 'i'], [1.6, KO_DOWN]]);
  const SIT = P({
    hips: [-0.55, 0, 0], py: -0.62, ground: 0, spine: [0.5, 0, 0], chest: [0.4, 0, 0], head: [0.2, 0, 0],
    legL: [-1.55, 0, 0.12], kneeL: [2.0, 0, 0], footL: [0.2, 0, 0], legR: [-1.35, 0, -0.12], kneeR: [2.05, 0, 0], footR: [0.2, 0, 0],
    armR: [0.5, 0, -0.5], elbowR: [-0.4, 0, 0], handR: [1.2, 0, 0], armL: [0.6, 0, 0.5], elbowL: [-0.3, 0, 0], handL: [0.8, 0, 0], two: 0,
  });
  const CROUCH = P(TORSO, up, {
    hips: [0.5, -0.25, 0], spine: [0.3, 0.1, 0],
    legL: [-1.5, 0.2, 0.16], kneeL: [2.0, 0, 0], footL: [-0.55, 0, 0], legR: [-0.9, 0, -0.16], kneeR: [2.1, 0, 0], footR: [-1.25, 0, 0], two: 0.5,
  });
  c.getup = keys([[0, DOWN], [0.22, SIT], [0.42, CROUCH], [0.7, IDLE]]);

  // ---- attacks (right-hand weapon; two-handed weapons follow through IK)
  const stepF = { legL: [-0.78, 0.25, 0.1], kneeL: [0.95, 0, 0], footL: [-0.17, 0, 0], legR: [0.5, 0, -0.14], kneeR: [0.18, 0, 0], footR: [-0.28, 0, 0] };
  const coil = { legL: [-0.45, 0.3, 0.12], kneeL: [0.78, 0, 0], footL: [-0.33, 0, 0], legR: [0.3, 0, -0.16], kneeR: [0.36, 0, 0], footR: [-0.66, 0, 0] };

  c.slashH = keys([
    [0, IDLE],
    [0.11, P(coil, { hips: [0.04, -0.62, 0], spine: [0.05, -0.3, 0], chest: [0, -0.55, 0], neck: [0, 0.4, 0], head: [0, 0.75, 0],
      armR: [-1.4, 0, -1.3], elbowR: [-0.6, 0, 0], handR: [1.35, 0, 0], armL: [-0.9, 0, 0.15], elbowL: [-0.9, 0, 0] })],
    [0.2, P(stepF, { hips: [0.12, -0.18, 0], pz: 0.12, spine: [0.1, 0.05, 0], chest: [0.05, 0.15, 0], head: [0, 0.1, 0],
      armR: [-1.5, 0, -0.15], elbowR: [-0.1, 0, 0], handR: [1.45, 0, 0], armL: [0.3, 0, 0.5], elbowL: [-0.5, 0, 0] }), 'i'],
    [0.27, P(stepF, { hips: [0.12, 0.16, 0], pz: 0.14, spine: [0.1, 0.32, 0], chest: [0.05, 0.6, 0], neck: [0, -0.3, 0], head: [0, -0.6, 0],
      armR: [-1.38, 0, 0.95], elbowR: [-0.35, 0, 0], handR: [1.3, 0, 0], armL: [0.65, 0, 0.6], elbowL: [-0.4, 0, 0] }), 'o'],
    [0.36, P(stepF, { hips: [0.1, 0.2, 0], pz: 0.12, spine: [0.1, 0.34, 0], chest: [0.05, 0.62, 0], neck: [0, -0.3, 0], head: [0, -0.6, 0],
      armR: [-1.3, 0, 1.0], elbowR: [-0.5, 0, 0], handR: [1.2, 0, 0], armL: [0.6, 0, 0.6], elbowL: [-0.45, 0, 0] })],
    [0.56, IDLE],
  ]);

  c.slashBack = keys([
    [0, IDLE],
    [0.09, P(coil, { hips: [0.08, 0.05, 0], spine: [0.1, 0.3, 0], chest: [0.08, 0.62, 0], neck: [0, -0.3, 0], head: [0, -0.6, 0],
      armR: [-0.95, 0, 0.95], elbowR: [-1.0, 0, 0], handR: [0.95, 0, 0], armL: [0.2, 0, 0.5], elbowL: [-0.7, 0, 0] })],
    [0.17, P(stepF, { hips: [0.1, -0.2, 0], pz: 0.12, spine: [0.06, 0, 0], chest: [0, 0.05, 0], head: [0, 0.15, 0],
      armR: [-1.6, 0, -0.1], elbowR: [-0.1, 0, 0], handR: [1.45, 0, 0], armL: [-0.2, 0, 0.7], elbowL: [-0.6, 0, 0] }), 'i'],
    [0.24, P(stepF, { hips: [0.02, -0.55, 0], pz: 0.14, spine: [-0.04, -0.3, 0], chest: [-0.08, -0.6, 0], neck: [0, 0.4, 0], head: [-0.05, 0.7, 0],
      armR: [-2.0, 0, -1.1], elbowR: [-0.3, 0, 0], handR: [1.25, 0, 0], armL: [-0.6, 0, 0.5], elbowL: [-0.9, 0, 0] }), 'o'],
    [0.33, P(stepF, { hips: [0.02, -0.58, 0], pz: 0.12, spine: [-0.04, -0.32, 0], chest: [-0.08, -0.62, 0], neck: [0, 0.4, 0], head: [-0.05, 0.7, 0],
      armR: [-2.05, 0, -1.15], elbowR: [-0.45, 0, 0], handR: [1.15, 0, 0], armL: [-0.6, 0, 0.5], elbowL: [-0.9, 0, 0] })],
    [0.54, IDLE],
  ]);

  c.overhead = keys([
    [0, IDLE],
    [0.15, P({ hips: [-0.1, -0.2, 0], py: 0.03, spine: [-0.15, 0, 0], chest: [-0.2, 0.1, 0], head: [0.2, 0.1, 0],
      legL: [-0.3, 0.2, 0.1], kneeL: [0.4, 0, 0], footL: [-0.1, 0, 0], legR: [0.2, 0, -0.14], kneeR: [0.2, 0, 0], footR: [-0.2, 0, 0],
      armR: [-2.95, 0, -0.2], elbowR: [-1.15, 0, 0], handR: [0.5, 0, 0], armL: [-2.3, 0, 0.3], elbowL: [-1.0, 0, 0] })],
    [0.25, P(stepF, { hips: [0.16, -0.1, 0], pz: 0.16, spine: [0.14, 0, 0], chest: [0.1, 0.05, 0], head: [-0.2, 0, 0],
      armR: [-1.3, 0, -0.05], elbowR: [-0.15, 0, 0], handR: [1.5, 0, 0], armL: [-0.5, 0, 0.5], elbowL: [-0.7, 0, 0] }), 'i'],
    [0.31, P(stepF, { hips: [0.22, -0.1, 0], pz: 0.18, spine: [0.16, 0, 0], chest: [0.1, 0.05, 0], head: [-0.3, 0, 0],
      legL: [-1.0, 0.25, 0.1], kneeL: [1.2, 0, 0], footL: [-0.4, 0, 0],
      armR: [-0.95, 0, 0.0], elbowR: [-0.15, 0, 0], handR: [1.25, 0, 0], armL: [0.2, 0, 0.5], elbowL: [-0.6, 0, 0] }), 'o'],
    [0.42, P(stepF, { hips: [0.21, -0.1, 0], pz: 0.18, spine: [0.16, 0, 0], chest: [0.1, 0.05, 0], head: [-0.3, 0, 0],
      legL: [-1.0, 0.25, 0.1], kneeL: [1.2, 0, 0], footL: [-0.4, 0, 0],
      armR: [-0.92, 0, 0.0], elbowR: [-0.2, 0, 0], handR: [1.22, 0, 0], armL: [0.2, 0, 0.5], elbowL: [-0.6, 0, 0] })],
    [0.68, IDLE],
  ]);

  const THRUST_HIT = P(stepF, { hips: [0.22, 0.25, 0], pz: 0.3, spine: [0.12, 0.2, 0], chest: [0.08, 0.5, 0], neck: [0, -0.25, 0], head: [-0.2, -0.45, 0],
    legL: [-1.0, 0.1, 0.08], kneeL: [1.15, 0, 0], footL: [-0.15, 0, 0], legR: [0.62, 0, -0.1], kneeR: [0.1, 0, 0], footR: [-0.2, 0, 0],
    armR: [-1.5, 0, 0.1], elbowR: [-0.05, 0, 0], handR: [1.52, 0, 0], armL: [0.7, 0, 0.5], elbowL: [-0.3, 0, 0] });
  c.thrust = keys([
    [0, IDLE],
    [0.12, P(coil, { hips: [0.02, -0.7, 0], spine: [0.05, -0.2, 0], chest: [0, -0.4, 0], neck: [0, 0.4, 0], head: [0, 0.8, 0],
      armR: [0.5, 0, -0.3], elbowR: [-2.05, 0, 0], handR: [1.5, 0, 0], armL: [-1.2, 0, 0.1], elbowL: [-0.5, 0, 0] })],
    [0.2, THRUST_HIT, 'i'],
    [0.32, THRUST_HIT],
    [0.54, IDLE],
  ]);

  // ---- gunplay
  const aimR = { armR: [-1.5, 0, 0.14], elbowR: [-0.08, 0, 0], handR: [1.56, 0, 0] };
  const aimL = { armL: [-1.5, 0, -0.14], elbowL: [-0.08, 0, 0], handL: [1.56, 0, 0] };
  const kickR = { armR: [-1.72, 0, 0.14], elbowR: [-0.5, 0, 0], handR: [1.35, 0, 0] };
  const kickL = { armL: [-1.72, 0, -0.14], elbowL: [-0.5, 0, 0], handL: [1.35, 0, 0] };
  c.shootR = keys([[0, IDLE], [0.06, P(LEGS, TORSO, up, aimR, { chest: [0.04, 0.4, 0], head: [0, -0.2, 0] }), 'o'], [0.11, P(LEGS, TORSO, up, kickR, { chest: [0, 0.34, 0], head: [0, -0.2, 0] }), 'snap'], [0.2, P(LEGS, TORSO, up, aimR, { chest: [0.04, 0.4, 0], head: [0, -0.2, 0] })], [0.36, IDLE]]);
  c.shootL = keys([[0, IDLE], [0.06, P(LEGS, TORSO, up, aimL, { hips: [0, -0.1, 0], chest: [0.04, -0.2, 0], head: [0, 0.2, 0] }), 'o'], [0.11, P(LEGS, TORSO, up, kickL, { hips: [0, -0.1, 0], chest: [0, -0.14, 0], head: [0, 0.2, 0] }), 'snap'], [0.2, P(LEGS, TORSO, up, aimL, { hips: [0, -0.1, 0], chest: [0.04, -0.2, 0], head: [0, 0.2, 0] })], [0.36, IDLE]]);
  const AIM2 = P(LEGS, TORSO, up, aimR, aimL, { hips: [0.05, -0.12, 0], chest: [0.06, 0.1, 0], head: [0, 0, 0] });
  const KICK2 = P(LEGS, TORSO, up, kickR, kickL, { hips: [-0.04, -0.12, 0], chest: [-0.06, 0.1, 0], pz: -0.06 });
  c.shootBoth = keys([[0, IDLE], [0.08, AIM2, 'o'], [0.13, KICK2, 'snap'], [0.24, AIM2], [0.44, IDLE]]);
  c.aimBoth = { type: 'fn', loop: true, fn: (out, t) => { out.set(AIM2); const k = Math.sin(t * 46) * 0.03; out[IDX.armR] += k; out[IDX.armL] -= k; out[PZ] = -0.03 + k * 0.4; } };

  // ---- power moves
  const CHARGE = P({
    hips: [-0.04, -0.1, 0], spine: [-0.1, 0, 0], chest: [-0.15, 0.1, 0], head: [0.1, 0, 0],
    legL: [-0.3, 0.3, 0.36], kneeL: [0.55, 0, 0], footL: [-0.25, 0, -0.3], legR: [0.18, -0.2, -0.38], kneeR: [0.45, 0, 0], footR: [-0.6, 0, 0.3],
    armR: [-2.55, 0, -0.45], elbowR: [-0.35, 0, 0], handR: [1.2, 0, 0], armL: [-0.25, 0, 0.9], elbowL: [-0.75, 0, 0], handL: [1.0, 0, 0],
  });
  c.charge = { type: 'fn', loop: true, fn: (out, t) => { out.set(CHARGE); const k = Math.sin(t * 38) * 0.012; out[IDX.armR] += k; out[IDX.chest] += k * 0.5; out[IDX.armL + 2] += Math.sin(t * 5) * 0.05; } };

  const LEAP = P({
    hips: [-0.15, 0, 0], spine: [-0.15, 0, 0], chest: [-0.2, 0, 0], head: [0.3, 0, 0],
    legL: [-1.3, 0, 0.12], kneeL: [1.7, 0, 0], footL: [0.5, 0, 0], legR: [-0.5, 0, -0.12], kneeR: [1.5, 0, 0], footR: [0.7, 0, 0],
    armR: [-2.95, 0, -0.15], elbowR: [-1.0, 0, 0], handR: [0.55, 0, 0], armL: [-2.4, 0, 0.3], elbowL: [-0.9, 0, 0],
  });
  const SLAM = P(stepF, { hips: [0.3, -0.1, 0], spine: [0.2, 0, 0], chest: [0.14, 0.05, 0], head: [-0.4, 0, 0],
    legL: [-1.25, 0.2, 0.16], kneeL: [1.6, 0, 0], footL: [-0.35, 0, 0], legR: [-0.2, 0, -0.2], kneeR: [1.5, 0, 0], footR: [-0.5, 0, 0],
    armR: [-0.95, 0, 0.0], elbowR: [-0.15, 0, 0], handR: [1.2, 0, 0], armL: [0.2, 0, 0.5], elbowL: [-0.6, 0, 0] });
  c.leap = keys([[0, IDLE], [0.14, P(CROUCHLITE(up)), 'o'], [0.3, LEAP, 'o'], [1.0, LEAP]]);
  c.slam = keys([[0, LEAP], [0.08, SLAM, 'i'], [0.4, SLAM], [0.72, IDLE]]);

  // ---- ceremony
  const RELAX = P({
    hips: [0, -0.12, 0], spine: [0.02, 0.06, 0], chest: [0, 0.06, 0], head: [0, 0, 0],
    legL: [-0.04, 0.1, 0.07], kneeL: [0.06, 0, 0], footL: [-0.02, 0, 0], legR: [0.02, 0, -0.08], kneeR: [0.04, 0, 0], footR: [-0.06, 0, 0],
    armR: [0.05, 0, -0.16], elbowR: [-0.22, 0, 0], handR: [0.5, 0, 0], armL: [0.02, 0, 0.14], elbowL: [-0.18, 0, 0], handL: [0.5, 0, 0], two: 0,
  });
  const FLOURISH = P(LEGS, TORSO, { hips: [0, -0.3, 0], chest: [-0.05, 0.3, 0],
    armR: [-1.7, 0, -0.5], elbowR: [-0.5, 0, 0], handR: [1.0, 0, 0], armL: [-0.1, 0, 0.5], elbowL: [-0.9, 0, 0], handL: [0.9, 0, 0], two: 0 });
  c.relax = { type: 'fn', loop: true, fn: (out, t) => { out.set(RELAX); const b = Math.sin(t * 1.8); out[IDX.chest] += b * 0.02; out[IDX.armR + 2] -= b * 0.012; out[IDX.armL + 2] += b * 0.012; out[IDX.head + 1] = Math.sin(t * 0.6) * 0.12; } };
  c.intro = keys([[0, RELAX], [0.3, RELAX], [0.75, FLOURISH, 'io'], [1.0, FLOURISH], [1.45, IDLE]]);
  const WIN = P({
    hips: [-0.03, 0.05, 0], spine: [-0.06, 0, 0], chest: [-0.12, 0, 0], head: [-0.12, 0, 0],
    legL: [-0.05, 0.12, 0.1], kneeL: [0.05, 0, 0], legR: [0.03, -0.1, -0.1], kneeR: [0.05, 0, 0], footR: [-0.08, 0, 0],
    armR: [-2.7, 0, -0.32], elbowR: [-0.22, 0, 0], handR: [1.35, 0, 0], armL: [0.15, 0, 0.5], elbowL: [-1.55, 0.6, 0], handL: [0.8, 0, 0], two: 0,
  });
  const WIN2 = P(); WIN2.set(WIN); WIN2[IDX.armR] = -2.82; WIN2[IDX.chest] = -0.16;
  c.victory = keys([[0, IDLE], [0.45, WIN, 'o'], [0.62, WIN2], [0.85, WIN], [4, WIN]]);
  return c;
}

function CROUCHLITE(up) {
  return {
    hips: [0.45, -0.1, 0], spine: [0.25, 0, 0], chest: [0.1, 0, 0], head: [-0.3, 0, 0],
    legL: [-1.2, 0.1, 0.14], kneeL: [1.6, 0, 0], footL: [-0.4, 0, 0], legR: [-0.7, 0, -0.14], kneeR: [1.6, 0, 0], footR: [-0.9, 0, 0],
    armR: [-0.2, 0, -0.3], elbowR: [-0.9, 0, 0], handR: [1.2, 0, 0], armL: [-0.2, 0, 0.3], elbowL: [-0.9, 0, 0],
  };
}

const CLIPSETS = {};
export function clipsFor(weapon) { return CLIPSETS[weapon] || (CLIPSETS[weapon] = makeClips(weapon)); }

function sampleClip(clip, t, out, anim) {
  if (clip.type === 'fn') { clip.fn(out, t, anim); return; }
  const ks = clip.keys;
  if (clip.loop) t %= clip.dur;
  if (t <= ks[0].t) { out.set(ks[0].p); return; }
  const last = ks[ks.length - 1];
  if (t >= last.t) { out.set(last.p); return; }
  let i = 1;
  while (ks[i].t < t) i++;
  const a = ks[i - 1], b = ks[i];
  const u = b.e((t - a.t) / (b.t - a.t));
  const pa = a.p, pb = b.p;
  for (let j = 0; j < POSE_SIZE; j++) out[j] = pa[j] + (pb[j] - pa[j]) * u;
}

export class Animator {
  constructor(rig) {
    this.rig = rig;
    this.clips = clipsFor(rig.def.weapon);
    this.cur = new Float32Array(POSE_SIZE);
    this.from = new Float32Array(POSE_SIZE);
    this.tgt = new Float32Array(POSE_SIZE);
    this.name = '';
    this.clip = null;
    this.time = 0;
    this.speed = 1;
    this.blendT = 1; this.blendDur = 0;
    this.runPhase = 0;
    this.play('idle', { blend: 0 });
    this.update(0);
  }

  play(name, { blend = 0.1, speed = 1, at = 0, force = false } = {}) {
    const clip = this.clips[name];
    if (!clip) return;
    if (!force && this.name === name && (clip.loop || this.time < clip.dur)) { this.speed = speed; return; }
    this.from.set(this.cur);
    this.name = name; this.clip = clip; this.time = at; this.speed = speed;
    this.blendT = 0; this.blendDur = blend;
  }

  get done() { return !this.clip.loop && this.clip.type === 'keys' && this.time >= this.clip.dur; }

  /** Pose at an explicit time without blending (used for previews). */
  pose(name, t) {
    this.name = name; this.clip = this.clips[name]; this.time = t; this.blendT = 1; this.blendDur = 0;
    this.update(0);
  }

  update(dt) {
    this.time += dt * this.speed;
    sampleClip(this.clip, this.time, this.tgt, this);
    if (this.blendDur > 0 && this.blendT < this.blendDur) {
      this.blendT += dt;
      const u = EASE.io(Math.min(1, this.blendT / this.blendDur));
      const f = this.from, t = this.tgt, c = this.cur;
      for (let j = 0; j < POSE_SIZE; j++) c[j] = f[j] + (t[j] - f[j]) * u;
    } else {
      this.cur.set(this.tgt);
    }
    this.rig.applyPose(this.cur);
  }
}
