# Halcyon Clash (Roblox)

An academy duel game for Roblox: four rival schools, each with its own tower and walled campus,
spread across one big landscape with Halcyon City and a central plaza.

## Put it in Roblox Studio

1. Download `HalcyonClash.rbxl` from this repository.
2. Open it in Roblox Studio (File → Open from File).
3. Press Play to walk around, or File → Publish to Roblox to put it on your account.

The world is already inside the place file, so nothing has to be imported by hand.

## What is in it so far

- **The hub when you join**: the camera circles the central spire while you choose
  **Start Game** or **Customize**. First-time players pick a school on a screen that flies the camera to
  each school's tower; then they spawn inside that school's gate. In game, the **≡ MENU** button at the top
  (or **M** / D-pad up) brings the hub back, where you can resume, customize, or change school.
- **Customize**: uniform style (long coat, pleated uniform, hoodie, light armour), hair style (8),
  hair colour (12), eye colour (8) and skin tone (8), with a spinning live preview. Your school sets the
  uniform colours. Or switch on "Wear my Roblox avatar" to keep your own avatar with a school sash.
  Looks and school are saved (turn on *Game Settings → Security → Enable Studio Access to API Services*
  to save while testing in Studio).

- **A hexagonal island city on a lake**, about 2,700 studs across: paved streets with a sea-wall
  promenade around the edge, the lake all around, green hills and mountains on the far shore. Grass is kept
  to parks and gardens.
- **City blocks** fill the land between the districts: white high-rises with glass faces and glowing floor
  bands, shop streets, hex-tiled plazas with hologram screens, canals with footbridges, parks and courts.
- **An elevated monorail loop** around the centre, with two trains.
- **The Halcyon Spire** in the middle: a 600-stud hexagonal glass tower carrying the **Sky Arena**, a full
  stadium where the tournaments will be held. Step on the **Skylift** pad at the tower's foot to ride up,
  and on the pad up top to ride back down.
- **The central hub** around the tower: the Register boards and the ring of twelve seats, the arrival
  station where new players spawn, the Training Hall, the Crown Arena, the market street and gardens.
- **Four school campuses**, each on its own walled land about 600 studs from the centre, joined to the hub
  by its own road. Every campus has a gate with the school's name, two dormitories, its own duel court and
  rank board, classroom wings, a sports lawn, and a different ground and tower:
  - Northwind Academy: twin ice-glass spires on snow
  - Solcrest Institute: a stepped sun tower on sandstone
  - Arcline Polytechnic: a round research tower wrapped in glowing rings
  - Ironreach Citadel: a fortress tower with forge chimneys on basalt
- **Halcyon City** down the city road to the west: a street grid of neon high-rises, shop signs, a central
  square with a clock tower and fountains, and parked hover cars.
- **38 NPCs**: seat-holders, the four school aces, school guides, staff and city people. Walk up and
  press **E** (keyboard), **X** (controller) or tap the prompt (mobile) to talk.
- A duel arena template in ServerStorage (not used yet), plus golden-hour lighting, bloom and clouds.

Not built yet: per-school rank leaderboards, combat and weapons, and the shop menu.

## Working on the code

The game is a [Rojo](https://rojo.space) project. Source lives in `src/`:

- `src/server/` builds the world (`Campus`, `Npcs`, `Arena`, `Atmos`) and runs the server
- `src/client/` is the player's side: the hub (`Hub`) and the dialogue box
- `src/shared/` holds config, the NPC roster, customisation options (`Looks`) and the dresser (`Appearance`)

To rebuild the place file after changing code (needs `rojo` and `lune`):

```bash
rojo build default.project.json -o build/base.rbxl
lune run tools/lune/bake.luau          # writes HalcyonClash.rbxl
node tools/lune/lint.mjs               # Luau lint
node tools/preview/shot.mjs --scene build/scene.json --out build/shots   # preview renders
```

`web/` holds the earlier browser prototype.
