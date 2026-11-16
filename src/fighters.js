// The roster: four original duelists of the Halcyon academies, their looks, stats and move sets.

const melee = (o) => ({ kind: 'melee', arc: 2.0, energy: 7, ...o });

export const FIGHTERS = [
  {
    id: 'kaito', name: 'KAITO ASHER', short: 'KAITO', title: 'The Azure Edge', academy: 'Northwind Academy',
    weapon: 'saber', weaponName: 'Lumen Saber “Glacier Line”', accent: 0x39c9ff, css: '#39c9ff',
    blurb: 'A calm all-rounder whose blade leaves frost-bright arcs. Fast combos, a piercing dash, no real weakness.',
    look: {
      height: 1.75, skin: 0xf0c8ad, hair: 0xd9e2f2, hairTip: 0x7fcfff, hairStyle: 'spiky', eye: 0x2e9bff,
      jacket: 0xe8ecf5, dark: 0x1a2340, pants: 0x1a2340, boots: 0x0f1322, glove: 0x1a2340,
      outfit: 'coat', sleeves: 'long', bootHeight: 0.26, browTilt: 5,
    },
    stats: { hp: 1000, speed: 6.8, power: 1.0, guard: 1.0 },
    bars: { power: 3, speed: 4, range: 3, defense: 3 },
    range: 2.1,
    combo: [
      melee({ clip: 'slashH', speed: 1.25, dur: 0.4, hit: [0.13, 0.22], reach: 2.35, dmg: 46, stun: 0.42, push: 2.4, lunge: [0.04, 0.2, 6.5], chain: 0.24 }),
      melee({ clip: 'slashBack', speed: 1.25, dur: 0.4, hit: [0.12, 0.2], reach: 2.35, dmg: 50, stun: 0.42, push: 2.4, lunge: [0.03, 0.18, 6.5], chain: 0.24 }),
      melee({ clip: 'overhead', speed: 1.2, dur: 0.56, hit: [0.19, 0.27], reach: 2.5, arc: 1.5, dmg: 78, stun: 0.5, push: 7, launch: true, lunge: [0.06, 0.24, 8], energy: 10 }),
    ],
    special: { name: 'Comet Step', cost: 30, kind: 'rush', clip: 'thrust', speed: 1.0, dur: 0.6, hit: [0.14, 0.34], reach: 2.3, arc: 2.4, dmg: 110, stun: 0.55, push: 6, launch: true, rush: [0.12, 0.34, 26], through: true, energy: 0 },
    ultimate: { name: 'Skyfall Requiem', kind: 'flurry', dmg: 330 },
  },
  {
    id: 'sera', name: 'SERA VALE', short: 'SERA', title: 'The Solar Lance', academy: 'Solcrest Institute',
    weapon: 'spear', weaponName: 'Lumen Lance “Daybreak”', accent: 0xffb62e, css: '#ffb62e',
    blurb: 'Keeps rivals at the tip of her lance. The longest reach on the roster and a guard-piercing lunge.',
    look: {
      height: 1.68, fem: true, skin: 0xd9a37e, hair: 0x1d3038, hairTip: 0x2f8f8a, hairStyle: 'ponytail', eye: 0xffa521,
      jacket: 0x24356a, skirt: 0xf3efe6, dark: 0x141d36, pants: 0x141d36, boots: 0xf3efe6, glove: 0xf3efe6,
      outfit: 'skirt', sleeves: 'long', legs: 'tights', bootHeight: 0.34, browTilt: 3, blush: 0.16,
    },
    stats: { hp: 950, speed: 6.5, power: 1.0, guard: 1.0 },
    bars: { power: 3, speed: 3, range: 5, defense: 2 },
    range: 2.9,
    combo: [
      melee({ clip: 'thrust', speed: 1.2, dur: 0.42, hit: [0.14, 0.24], reach: 3.3, arc: 0.9, dmg: 48, stun: 0.42, push: 3.2, lunge: [0.05, 0.2, 6], chain: 0.26 }),
      melee({ clip: 'slashH', speed: 1.1, dur: 0.46, hit: [0.15, 0.26], reach: 3.1, arc: 2.6, dmg: 52, stun: 0.42, push: 3, lunge: [0.04, 0.2, 5], chain: 0.3 }),
      melee({ clip: 'overhead', speed: 1.1, dur: 0.6, hit: [0.2, 0.3], reach: 3.3, arc: 1.3, dmg: 80, stun: 0.5, push: 7.5, launch: true, lunge: [0.06, 0.25, 7], energy: 10 }),
    ],
    special: { name: 'Sunpiercer', cost: 30, kind: 'rush', clip: 'thrust', speed: 0.85, dur: 0.7, hit: [0.16, 0.36], reach: 3.6, arc: 1.2, dmg: 120, stun: 0.6, push: 9, launch: true, rush: [0.14, 0.34, 20], guardBreak: true, energy: 0 },
    ultimate: { name: 'Helios Rain', kind: 'rain', dmg: 340 },
  },
  {
    id: 'mira', name: 'MIRA QUILL', short: 'MIRA', title: 'The Violet Tempest', academy: 'Arcline Polytechnic',
    weapon: 'pistol', weaponName: 'Twin Lumen Pistols “Hush & Holler”', accent: 0xe14bff, css: '#e14bff',
    blurb: 'A tinkerer who fights from range with twin pistols. Fragile up close, relentless from across the ring.',
    look: {
      height: 1.6, fem: true, skin: 0xf6d3bd, hair: 0xcdb6ff, hairTip: 0x8f5bff, hairStyle: 'bob', eye: 0xc04dff,
      jacket: 0x6a4fa3, dark: 0x1b1a26, pants: 0x1b1a26, boots: 0xe9e9f2, glove: 0x1b1a26,
      outfit: 'hoodie', sleeves: 'long', legs: 'tights', bootHeight: 0.16, glowSoles: true, browTilt: 1, blush: 0.26, smile: 71,
    },
    stats: { hp: 880, speed: 7.2, power: 0.95, guard: 0.9 },
    bars: { power: 2, speed: 5, range: 5, defense: 2 },
    range: 8,
    combo: [
      { kind: 'shot', clip: 'shootR', speed: 1.3, dur: 0.3, fire: [[0.06, 'R']], dmg: 34, stun: 0.3, push: 1.5, chain: 0.17, energy: 5 },
      { kind: 'shot', clip: 'shootL', speed: 1.3, dur: 0.3, fire: [[0.06, 'L']], dmg: 34, stun: 0.3, push: 1.5, chain: 0.17, energy: 5 },
      { kind: 'shot', clip: 'shootBoth', speed: 1.1, dur: 0.46, fire: [[0.09, 'R'], [0.09, 'L']], dmg: 40, stun: 0.42, push: 5, launch: true, energy: 6, heavy: true },
    ],
    special: { name: 'Scatter Vault', cost: 30, kind: 'vault', clip: 'shootBoth', speed: 0.9, dur: 0.62, fire: [[0.14, 'fan']], dmg: 34, stun: 0.45, push: 5, energy: 0 },
    ultimate: { name: 'Starline Overdrive', kind: 'beam', dmg: 330 },
  },
  {
    id: 'drake', name: 'DRAKE ONYX', short: 'DRAKE', title: 'The Ember Titan', academy: 'Ironreach Citadel',
    weapon: 'hammer', weaponName: 'Lumen Maul “Kiln”', accent: 0xff5a2a, css: '#ff5a2a',
    blurb: 'Slow, heavy and nearly impossible to stagger mid-swing. One clean hit from the maul changes a round.',
    look: {
      height: 1.93, bulk: 1.24, skin: 0xa5663f, hair: 0x14110f, hairTip: 0x2a1c16, accentHair: 0xff5a2a, hairStyle: 'slick', eye: 0xff7a2a,
      jacket: 0x3a3e4a, dark: 0x23262e, pants: 0x444854, boots: 0x15161b, glove: 0x15161b, metal: 0x8b8f9a,
      outfit: 'armor', sleeves: 'none', gauntlets: true, kneeGuards: true, bootHeight: 0.24, browTilt: 8, blush: 0, smile: 62,
    },
    stats: { hp: 1150, speed: 5.6, power: 1.0, guard: 1.1 },
    bars: { power: 5, speed: 2, range: 3, defense: 5 },
    range: 2.5,
    combo: [
      melee({ clip: 'slashH', speed: 0.8, dur: 0.66, hit: [0.23, 0.36], reach: 2.9, arc: 2.6, dmg: 92, stun: 0.55, push: 5, lunge: [0.08, 0.3, 5], chain: 0.42, armor: [0.1, 0.4], energy: 11, heavy: true }),
      melee({ clip: 'overhead', speed: 0.85, dur: 0.78, hit: [0.28, 0.38], reach: 3.0, arc: 1.5, dmg: 128, stun: 0.6, push: 8, launch: true, lunge: [0.1, 0.32, 6], armor: [0.1, 0.42], energy: 14, heavy: true, quake: true }),
    ],
    special: { name: 'Faultline', cost: 30, kind: 'leap', dmg: 140, stun: 0.6, push: 9, launch: true, guardBreak: true, radius: 3.4, energy: 0 },
    ultimate: { name: 'Meteor Verdict', kind: 'meteor', dmg: 360 },
  },
];

export const FIGHTER_BY_ID = Object.fromEntries(FIGHTERS.map((f) => [f.id, f]));
