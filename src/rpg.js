// The academy layer: enrolment, the Register (seat ranking), levels, skill points and the save file.
import { FIGHTERS, FIGHTER_BY_ID } from './fighters.js';

export const ACADEMIES = {
  northwind: {
    id: 'northwind', name: 'Northwind Academy', short: 'Northwind', motto: 'Still water cuts deepest.', hero: 'kaito', accent: 0x39c9ff, css: '#39c9ff',
    uniform: { jacket: 0xe8ecf5, skirt: 0xe8ecf5, dark: 0x1a2340, pants: 0x1a2340, boots: 0x0f1322, glove: 0x1a2340 },
  },
  solcrest: {
    id: 'solcrest', name: 'Solcrest Institute', short: 'Solcrest', motto: 'Rise before the sun does.', hero: 'sera', accent: 0xffb62e, css: '#ffb62e',
    uniform: { jacket: 0x24356a, skirt: 0xf3efe6, dark: 0x141d36, pants: 0x141d36, boots: 0xf3efe6, glove: 0xf3efe6 },
  },
  arcline: {
    id: 'arcline', name: 'Arcline Polytechnic', short: 'Arcline', motto: 'Measure twice. Fire once.', hero: 'mira', accent: 0xe14bff, css: '#e14bff',
    uniform: { jacket: 0x6a4fa3, skirt: 0x6a4fa3, dark: 0x1b1a26, pants: 0x1b1a26, boots: 0xe9e9f2, glove: 0x1b1a26 },
  },
  ironreach: {
    id: 'ironreach', name: 'Ironreach Citadel', short: 'Ironreach', motto: 'Stand. Then stand again.', hero: 'drake', accent: 0xff5a2a, css: '#ff5a2a',
    uniform: { jacket: 0x3a3e4a, skirt: 0x3a3e4a, dark: 0x23262e, pants: 0x444854, boots: 0x15161b, glove: 0x15161b },
  },
};
export const academyOfHero = (heroId) => Object.values(ACADEMIES).find((a) => a.hero === heroId);

// The twelve seat-holders a new student has to climb past. Index 0 holds Seat I.
export const STUDENTS = [
  { id: 'elara', name: 'Elara Wynn', epithet: 'The Crownbearer', weapon: 'spear', fem: true, outfit: 'skirt', height: 1.72, skin: 0xf1d0b5, hair: 0xf2f0ea, hairTip: 0xb9cdfb, hairStyle: 'ponytail', eye: 0x7fb6ff, accent: 0xcfe0ff, level: 19, ai: 3,
    taunt: 'Seat I is not a prize. It is a promise to every student below it. Show me you can keep one.', lose: 'Then the promise is yours. Carry our colors into the Trials.', win: 'Come back when you understand what you are asking for.' },
  { id: 'magnus', name: 'Magnus Thorne', epithet: 'The Rampart', weapon: 'hammer', bulk: 1.22, outfit: 'armor', height: 1.96, skin: 0xc98f6b, hair: 0x4b2f1c, hairTip: 0x7a5232, hairStyle: 'slick', eye: 0x8fd96b, accent: 0x7dff7a, level: 17, ai: 3,
    taunt: 'Nobody has moved me off this seat in two years. You are welcome to push.', lose: 'Hah! Moved. Good. Elara has been bored for too long.', win: 'Still standing. Try again when your arms stop shaking.' },
  { id: 'odette', name: 'Odette Varga', epithet: 'Glass Rain', weapon: 'pistol', fem: true, outfit: 'coat', height: 1.66, skin: 0xe8c3a6, hair: 0x2a2140, hairTip: 0x7b5cff, hairStyle: 'bob', eye: 0x8f6bff, accent: 0x8f7bff, level: 15, ai: 3,
    taunt: 'I counted your steps on the way over. Forty-one. You will not get that many in the ring.', lose: 'I miscounted. That almost never happens.', win: 'As calculated.' },
  { id: 'cassian', name: 'Cassian Roe', epithet: 'The Quiet Cut', weapon: 'saber', outfit: 'coat', height: 1.8, skin: 0xd9b08c, hair: 0x101418, hairTip: 0x2b3a4a, hairStyle: 'ponytail', eye: 0x56d8c8, accent: 0x4fe3d0, level: 13, ai: 2,
    taunt: '...Draw.', lose: '...Clean. Well cut.', win: '...Sloppy.' },
  { id: 'yui', name: 'Yui Arakawa', epithet: 'Needle of Dawn', weapon: 'spear', fem: true, outfit: 'hoodie', height: 1.58, skin: 0xf4d6c0, hair: 0xff8fb0, hairTip: 0xffd0dd, hairStyle: 'bob', eye: 0xff5f9a, accent: 0xff6fa8, level: 12, ai: 2,
    taunt: 'A challenge? Now? I have not even had breakfast! ...Fine. Make it quick.', lose: 'Ugh, breakfast AND my seat. Worst morning ever.', win: 'Done! Canteen is that way if you need to cry into some noodles.' },
  { id: 'gideon', name: 'Gideon Brask', epithet: 'Wrecking Bell', weapon: 'hammer', bulk: 1.18, outfit: 'armor', height: 1.9, skin: 0x8a5a3c, hair: 0xd8d2c4, hairTip: 0xffffff, hairStyle: 'spiky', eye: 0xffc04a, accent: 0xffc23a, level: 10, ai: 2,
    taunt: 'One good hit. That is all I ever need. Let us see if you can avoid it.', lose: 'You avoided it. Every time. Respect.', win: 'One good hit.' },
  { id: 'noor', name: 'Noor Halabi', epithet: 'Twin Comets', weapon: 'pistol', fem: true, outfit: 'skirt', height: 1.63, skin: 0xb9805a, hair: 0x1c1a22, hairTip: 0x38d0ff, hairStyle: 'ponytail', eye: 0x38d0ff, accent: 0x38d0ff, level: 9, ai: 2,
    taunt: 'Keep moving. Standing targets are no fun at all.', lose: 'You kept moving. Annoying. Impressive, but annoying.', win: 'Too slow.' },
  { id: 'ravi', name: 'Ravi Castellan', epithet: 'The Show-off', weapon: 'saber', outfit: 'hoodie', height: 1.76, skin: 0xa8734c, hair: 0x6b2bd6, hairTip: 0xe14bff, hairStyle: 'spiky', eye: 0xe14bff, accent: 0xff4fd8, level: 7, ai: 1,
    taunt: 'Smile! The whole courtyard is watching me win.', lose: 'Okay, nobody saw that. Nobody saw that, right?', win: 'And THAT is how it is done. Did everyone see?' },
  { id: 'tessa', name: 'Tessa Lindqvist', epithet: 'Long Reach', weapon: 'spear', fem: true, outfit: 'skirt', height: 1.74, skin: 0xf3d9c6, hair: 0xe8c66a, hairTip: 0xfff0b0, hairStyle: 'ponytail', eye: 0x5fb0ff, accent: 0xffe07a, level: 6, ai: 1,
    taunt: 'I keep my rivals at exactly one lance-length. You will learn the distance.', lose: 'You got inside my reach. I need to drill more.', win: 'One lance-length. Remember it.' },
  { id: 'bram', name: 'Bram Holloway', epithet: 'The Doorstop', weapon: 'hammer', bulk: 1.15, outfit: 'armor', height: 1.88, skin: 0xe2b594, hair: 0xb5482a, hairTip: 0xff7a3a, hairStyle: 'slick', eye: 0x6bd0a0, accent: 0xff8a3a, level: 4, ai: 1,
    taunt: 'They call me the Doorstop. Rookies stop here.', lose: 'Guess the door is open now.', win: 'Door stays shut.' },
  { id: 'juno', name: 'Juno Marsh', epithet: 'Quickdraw', weapon: 'pistol', fem: true, outfit: 'hoodie', height: 1.57, skin: 0xd8a47c, hair: 0x2f6b4a, hairTip: 0x7dffb0, hairStyle: 'bob', eye: 0x7dffb0, accent: 0x6dffa8, level: 3, ai: 0,
    taunt: 'First week and already challenging? I like you. I am still going to shoot you.', lose: 'Okay, okay! Seat is yours. Buy me lunch sometime.', win: 'Told you.' },
  { id: 'pell', name: 'Pell Okoro', epithet: 'The Eager', weapon: 'saber', outfit: 'coat', height: 1.7, skin: 0x6e4630, hair: 0x1a1414, hairTip: 0x3a2a22, hairStyle: 'slick', eye: 0xffb62e, accent: 0xffd24a, level: 2, ai: 0,
    taunt: 'A challenger! Finally! I only got this seat last month, so... please go easy?', lose: 'That was amazing! I am going to train twice as hard!', win: 'I won? I WON! Sorry! But also, yes!' },
];
export const STUDENT_BY_ID = Object.fromEntries(STUDENTS.map((s) => [s.id, s]));

export const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
export const seatName = (idx) => (idx < 0 ? 'Unseated' : `Seat ${ROMAN[idx]}`);
export function tierName(idx) {
  if (idx < 0) return 'Unseated';
  if (idx === 0) return 'Crownbearer';
  if (idx <= 2) return 'Zenith';
  if (idx <= 5) return 'Paragon';
  if (idx <= 8) return 'Vanguard';
  return 'Registered';
}

export const STATS = [
  { id: 'power', name: 'Power', desc: '+5% damage per point', max: 8 },
  { id: 'vitality', name: 'Vitality', desc: '+6% sigil integrity (HP) per point', max: 8 },
  { id: 'agility', name: 'Agility', desc: '+2.5% speed, faster dash recovery', max: 8 },
  { id: 'focus', name: 'Focus', desc: '+8% Lumen gain per point', max: 8 },
];

// Techniques granted by the seat you have reached.
export const PERKS = [
  { id: 'keen', seat: 8, name: 'Keen Guard', desc: 'The perfect-guard window is 40% longer.' },
  { id: 'wind', seat: 5, name: 'Second Wind', desc: 'Once per round, dropping below 25% restores 20% of your sigil.' },
  { id: 'over', seat: 2, name: 'Overdrive', desc: 'Start every round with half your Lumen gauge.' },
  { id: 'mantle', seat: 0, name: "Crownbearer's Mantle", desc: 'All of your attacks deal 10% more damage.' },
];

const hexCss = (n) => `#${n.toString(16).padStart(6, '0')}`;

export const xpToNext = (level) => 100 + 45 * (level - 1);
export const xpReward = (foeLevel, won) => Math.round((70 + 22 * foeLevel) * (won ? 1 : 0.25));

/** Fighter definition for a seat-holder, wearing the given academy's uniform. */
export function studentDef(s, academy) {
  const base = FIGHTERS.find((f) => f.weapon === s.weapon);
  const armor = s.outfit === 'armor';
  return {
    ...base,
    id: `npc-${s.id}`, name: s.name.toUpperCase(), short: s.name.split(' ')[0].toUpperCase(), title: s.epithet,
    accent: s.accent, css: hexCss(s.accent),
    look: {
      height: s.height, fem: !!s.fem, bulk: s.bulk, skin: s.skin, hair: s.hair, hairTip: s.hairTip, hairStyle: s.hairStyle, eye: s.eye,
      outfit: s.outfit, sleeves: armor ? 'none' : 'long', gauntlets: armor, kneeGuards: armor, legs: s.fem ? 'tights' : undefined,
      bootHeight: s.fem ? 0.3 : 0.25, browTilt: s.fem ? 2 : 6, blush: s.fem ? 0.18 : 0.05, glowSoles: s.outfit === 'hoodie',
      ...academy.uniform,
    },
    stats: scaleStats(base.stats, s.level),
    level: s.level, ai: s.ai, npc: s,
  };
}

function scaleStats(st, level) {
  return { ...st, hp: Math.round(st.hp * (1 + 0.035 * (level - 1))), power: st.power * (1 + 0.025 * (level - 1)) };
}

/** A rival academy's ace, as faced in the Crown Trials. */
export function aceDef(heroId, level) {
  const base = FIGHTER_BY_ID[heroId];
  return { ...base, stats: scaleStats(base.stats, level), level, ai: 3, ace: true };
}

/** The player's fighter with level growth, allocated skill points and seat techniques applied. */
export function playerDef(save) {
  const base = FIGHTER_BY_ID[save.hero], a = save.alloc, L = save.level;
  const perks = activePerks(save);
  return {
    ...base,
    stats: {
      ...base.stats,
      hp: Math.round(base.stats.hp * (1 + 0.03 * (L - 1)) * (1 + 0.06 * a.vitality)),
      power: base.stats.power * (1 + 0.02 * (L - 1)) * (1 + 0.05 * a.power) * (perks.mantle ? 1.1 : 1),
      speed: base.stats.speed * (1 + 0.025 * a.agility),
      dashCd: 1 - 0.045 * a.agility,
      focus: 1 + 0.08 * a.focus,
    },
    perks, level: L, isPlayer: true,
  };
}

export function activePerks(save) {
  const out = {};
  for (const p of PERKS) if (save.best >= 0 && save.best <= p.seat) out[p.id] = true;
  return out;
}

// ---- save file
const KEY = 'halcyon-clash-save-v1';

export function newSave(heroId) {
  return {
    v: 1, hero: heroId, academy: academyOfHero(heroId).id,
    level: 1, xp: 0, points: 0, alloc: { power: 0, vitality: 0, agility: 0, focus: 0 },
    ladder: STUDENTS.map((s) => s.id),      // seat order; 'player' is inserted when a seat is won
    best: -1,                               // best seat index ever held (-1 = none)
    wins: 0, losses: 0, day: 1, trials: 0, champion: false, intro: false,
  };
}

export function loadSave() {
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return null;
    const s = JSON.parse(raw);
    if (!s || s.v !== 1 || !FIGHTER_BY_ID[s.hero] || !Array.isArray(s.ladder)) return null;
    return s;
  } catch (e) { return null; }
}
export function storeSave(save) { try { window.localStorage.setItem(KEY, JSON.stringify(save)); return true; } catch (e) { return false; } }
export function clearSave() { try { window.localStorage.removeItem(KEY); } catch (e) { /* storage unavailable */ } }

export const playerSeat = (save) => save.ladder.indexOf('player');

/** Which seats the player may challenge right now: up to three places above their own. */
export function canChallenge(save, idx) {
  const me = playerSeat(save);
  if (save.ladder[idx] === 'player') return false;
  if (me < 0) return idx >= save.ladder.length - 3;
  return idx < me && idx >= me - 3;
}

export function ladderView(save) {
  const academy = ACADEMIES[save.academy];
  return save.ladder.map((id, idx) => {
    if (id === 'player') { const h = FIGHTER_BY_ID[save.hero]; return { idx, player: true, name: h.name, epithet: h.title, weapon: h.weapon, level: save.level, css: h.css }; }
    const s = STUDENT_BY_ID[id];
    return { idx, id, student: s, name: s.name, epithet: s.epithet, weapon: s.weapon, level: s.level, css: hexCss(s.accent), can: canChallenge(save, idx), academy };
  });
}

/** The player beat the holder of seat `idx`: take the seat, everyone between slides down one. */
export function takeSeat(save, idx) {
  const before = playerSeat(save);
  const ladder = save.ladder.filter((id) => id !== 'player');
  ladder.splice(idx, 0, 'player');
  save.ladder = ladder.slice(0, 12);
  const newPerks = PERKS.filter((p) => idx <= p.seat && !(save.best >= 0 && save.best <= p.seat));
  if (save.best < 0 || idx < save.best) save.best = idx;
  return { before, after: idx, newPerks };
}

export function grantXp(save, amount) {
  save.xp += amount;
  let gained = 0;
  while (save.xp >= xpToNext(save.level)) { save.xp -= xpToNext(save.level); save.level++; save.points += 2; gained++; }
  return gained;
}

export function trialOrder(save) { return FIGHTERS.filter((f) => f.id !== save.hero).map((f) => f.id); }
export const TRIAL_LEVELS = [20, 21, 23];

export function nextGoal(save) {
  const me = playerSeat(save);
  if (save.champion) return 'You hold the Crown of Halcyon. Defend your name in the ring.';
  if (me === 0) return `Enter the Crown Gate: ${3 - save.trials} rival ace${3 - save.trials === 1 ? '' : 's'} stand between you and the Crown.`;
  if (me < 0) return 'Challenge a seat-holder to enter the Register. Seats X to XII will accept.';
  return `You hold ${seatName(me)}. Challenge up to three seats above you. Seat I opens the Crown Trials.`;
}
