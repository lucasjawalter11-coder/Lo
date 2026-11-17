# Halcyon Clash (Roblox)

An academy duel game for Roblox: four rival schools, each with a whole district of its own, around a central
tower that carries the Sky Arena, on a city of islands in a lake.

## Put it in Roblox Studio

1. Download `HalcyonClash.rbxl` from this repository.
2. Open it in Roblox Studio (File → Open from File).
3. Press Play to walk around, or File → Publish to Roblox to put it on your account.

The world is already inside the place file, so nothing has to be imported by hand.

## What is in it so far

- **The hub when you join**: the camera circles the central spire while you choose
  **Start Game** or **Customize**. First-time players pick a school on a screen that flies the camera to
  each school's tower; then they spawn at their school district's arrival station. In game, the **≡ MENU** button at the top
  (or **M** / D-pad up) brings the hub back, where you can resume, customize, or change school.
- **Customize**: uniform style (long coat, pleated uniform, hoodie, light armour), hair style (8),
  hair colour (12), eye colour (8) and skin tone (8), with a spinning live preview. Your school sets the
  uniform colours. Or switch on "Wear my Roblox avatar" to keep your own avatar with a school sash.
  Looks and school are saved (turn on *Game Settings → Security → Enable Studio Access to API Services*
  to save while testing in Studio).

- **Nine islands on a lake, joined by bridges** (about 7,700 studs across):
  - **Crown Plaza** in the middle: the **Halcyon Spire**, an 820-stud glass tower carrying the
    **Sky Arena** (a stadium half again bigger than a duel arena) where the tournaments are held. Step on the
    **Skylift** pad at the foot of the tower to ride up, and on the pad up top to ride down. A monorail
    loops around the plaza.
  - **Four school districts**, one per school, each a whole town of its own: a central Register plaza with
    the school's **twelve seat-holders**, an arrival station where its students spawn, a training hall, a
    shop street, gardens, city blocks in the school's colours, and on the far side the walled campus with
    the school's tower.
  - **Four city districts** between the schools: Lakeside Ward, Sunrise Market, Lantern Row and Gearworks,
    each with a downtown grid of neon high-rises, shop streets, plazas, canals and courts.
- **Transit gates** in every district (and at the foot of the Spire) open a travel menu, so you can jump
  between districts instead of walking for minutes.
- **Each school campus** has a gate with the school's name, two dormitories, its own duel court and rank
  board, classroom wings, a sports lawn, and a different ground and tower:
  - Northwind Academy: twin ice-glass spires on snow
  - Solcrest Institute: a stepped sun tower on sandstone
  - Arcline Polytechnic: a round research tower wrapped in glowing rings
  - Ironreach Citadel: a fortress tower with forge chimneys on basalt
- **74 NPCs**: 48 seat-holders (twelve per school), the four school aces, school guides, staff, students
  and city people. Walk up and press **E** (keyboard), **D-pad down** (controller) or tap the prompt
  (mobile) to talk.
- Golden-hour lighting, bloom and clouds; streaming is on so phones only load what is near them.

- **Fighting** (see below): six weapons, combos, air juggles, guards, perfect guards, skills and ultimates.
  Talk to any seat-holder or school champion and press **Challenge** to duel them in a private arena.
  Train on the dummies in the Training Hall, and fight other players freely in the Sky Arena and on each
  school's duel court.

Not built yet: per-school rank leaderboards (beat rank 1 to become rank 1), and the shop menu with
coins and cosmetics. Duels already pay out coins.

## Fighting

| Action | PC | Controller | Mobile |
| --- | --- | --- | --- |
| Light attack (press again to chain, 4 hits) | Left click | X | ATK |
| Heavy attack (hold to charge) | R | Y | HVY |
| Dash (briefly untouchable; also works in the air) | Q | B | DASH |
| Guard (tap just before a hit for a Perfect Guard) | F (hold) | RB (hold) | GRD |
| Skills 1, 2, 3 | 1, 2, 3 | RT, LT, LB | 1, 2, 3 |
| Ultimate (full Lumen gauge) | G | R3 | ULT |
| Pursuit jump (right after a launcher) | Space | A | Jump |
| Talk / use | E | D-pad down | Tap the prompt |

- **Chains:** light, light, light, light; or light, light, then heavy for a **launcher** that throws the rival
  into the air. Follow with a pursuit jump and air attacks, which keep you hanging in the air.
- **Dash** out of the end of any swing to keep pressure, or right before a hit to slip through it. A light
  attack straight out of a dash is a **dash strike**.
- **Perfect Guard** staggers the attacker and opens a counter: press light to riposte.
- **Break Away:** caught in a long combo? Dash while stunned to spend 25 Lumen and escape.
- **Lumen** fills as you deal and take hits. Skills cost Lumen and have cooldowns; the ultimate takes a full gauge.

| Weapon | Style | Skills · Ultimate |
| --- | --- | --- |
| Lumen Saber | Balanced | Comet Step (dash through) · Frost Crescent (slash wave) · Glacier Parry (counter stance) · *Skyfall Requiem* |
| Solar Lance | Reach | Sunpiercer (guard-breaking lunge) · Wheel of Dawn (spin) · Pole Vault (dive strike) · *Helios Rain* |
| Ember Maul | Power, armoured swings | Faultline (ground shockwave) · Iron Will (armour buff) · Comet Drop (leaping slam) · *Meteor Verdict* |
| Twin Pistols | Ranged | Scatter Vault (backflip fan shot) · Railspike (piercing rail) · Bullet Dance (spinning barrage) · *Starline Overdrive* |
| **Eclipse Scythe** (unique) | Control | Reaping Hook (pulls the rival in) · Moon Cyclone (spinning advance) · Phase Step (blink behind) · *Black Eclipse* |
| **Orbit Discs** (unique) | Tricks | Ricochet (boomerang) · Orbit Shield (discs circle you) · Twin Snare (holding zone) · *Saturn Ring* |

Each school starts with its own weapon (Northwind saber, Solcrest lance, Arcline pistols, Ironreach maul).
Equip any of the six from the rack in the Training Hall.


## Working on the code

The game is a [Rojo](https://rojo.space) project. Source lives in `src/`:

- `src/server/` builds the world (`Campus`, `Npcs`, `Arena`, `Atmos`) and runs the server
- `src/client/` is the player's side: the hub (`Hub`) and the dialogue box
- `src/shared/` holds config, the NPC roster, customisation (`Looks`, `Appearance`), weapons (`Weapons`), every move
  with its poses and hitboxes (`Moves`), and the R15 rig builder (`Rig`)
- `src/server/Combat`, `Ai`, `Duels` run fights; `src/client/CombatClient`, `Animator`, `Fx` are the player's side

To rebuild the place file after changing code (needs `rojo` and `lune`):

```bash
rojo build default.project.json -o build/base.rbxl
lune run tools/lune/bake.luau          # writes HalcyonClash.rbxl
node tools/lune/lint.mjs               # Luau lint
node tools/preview/shot.mjs --scene build/scene.json --out build/shots   # preview renders
lune run tools/lune/sim-duel.luau saber maul 3 3    # AI-vs-AI duel through the real combat code
lune run tools/lune/pose-sheet.luau scythe l1,s2    # render a move as a contact sheet
```

`web/` holds the earlier browser prototype.
