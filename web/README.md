# Halcyon Clash

A 3D academy-duel action RPG that runs in the browser. Enrol at one of four sky-city academies, climb your
school's **Register** (its twelve ranked seats) one sanctioned duel at a time, and carry your colors into the
**Crown Trials** against the other academies' aces.

It is an original game: its world, characters, names and art are its own, in the spirit of academy
tournament-battle anime.

## Play

```bash
npm install
npm run serve      # then open http://localhost:8080
```

The page loads the three.js engine from a CDN, so it needs an internet connection. `npm run build` bundles the
whole game into `dist/standalone.html`, a single file you can host anywhere.

## How it plays

- **Campus.** Walk the academy courtyard. Read the Register board, talk to Proctor Maren, visit the Training Hall,
  or walk up to a seat-holder and challenge them.
- **The Register.** Twelve seats, XII up to I. You may challenge up to three seats above your own. Win and the
  seat is yours; everyone between slides down one.
- **Growth.** Duels earn experience. Each level grants skill points for Power, Vitality, Agility and Focus, and
  the seats you reach unlock techniques (Keen Guard, Second Wind, Overdrive, Crownbearer's Mantle).
- **Crown Trials.** Hold Seat I and the Crown Gate opens: three rival Crownbearers, best of three rounds each.
- **Quick duel.** Any two duelists, straight into the ring.

| Action | Keyboard / mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | W A S D | Left stick | On-screen stick |
| Attack (press again to combo) | J / left click | X | ATTACK |
| Skill (costs a third of the Lumen gauge) | K / right click | Y | SKILL |
| Guard (tap just before a hit for a Perfect Guard) | L / Shift | RB | GUARD |
| Dash (briefly untouchable) | Space | A | DASH |
| Ultimate (full gauge) | I / Q | B | ULT |
| Talk / challenge / use | E | A | TALK |
| Pause / menu | Esc | Start | PAUSE |

## The duelists

| Duelist | Academy | Weapon | Style |
| --- | --- | --- | --- |
| Kaito Asher | Northwind Academy | Lumen saber | Fast all-rounder with a piercing dash |
| Sera Vale | Solcrest Institute | Lumen lance | Longest reach, guard-breaking lunge |
| Mira Quill | Arcline Polytechnic | Twin pistols | Ranged pressure, fragile up close |
| Drake Onyx | Ironreach Citadel | Lumen maul | Slow, armored, enormous hits |

## Under the hood

Everything is generated in code: there are no model, texture or audio files.

- `src/gfx.js` HDR pipeline: planar floor reflections, multi-level bloom, filmic tone mapping, grading
- `src/arena.js`, `src/campus.js` the Crown Arena and the academy courtyard
- `src/character.js`, `src/anim.js` procedural duelists, pose library, off-hand IK, cloth and hair follow-through
- `src/combat.js`, `src/control.js` fighters, moves, projectiles, hit resolution, rival AI
- `src/fx.js`, `src/audio.js` particles, trails and shockwaves; synthesized sound effects and music
- `src/rpg.js` academies, the Register, levels, skill points and the save file (browser local storage)
- `src/main.js`, `src/ui.js`, `src/camera.js`, `src/input.js` game flow, interface, camera direction, controls

`dev.html` and `tools/` are development helpers (a pose contact sheet and headless test drivers).
