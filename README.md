# Halcyon Clash (Roblox)

An academy duel game for Roblox: four rival schools, each with its own tower, district and rank ladder,
on a floating island next to Halcyon City.

## Put it in Roblox Studio

1. Download `HalcyonClash.rbxl` from this repository.
2. Open it in Roblox Studio (File → Open from File).
3. Press Play to walk around, or File → Publish to Roblox to put it on your account.

The world is already inside the place file, so nothing has to be imported by hand.

## What is in it so far

- **Academy Island**: the Register plaza and spire in the centre, the Skydock spawn, the Training Hall,
  the Crown Arena gate, gardens, ponds and lookouts around the rim.
- **Four school districts**, each with its own ground and its own high-rise tower:
  - Northwind Academy: twin ice-glass spires on snow
  - Solcrest Institute: a stepped sun tower on sandstone
  - Arcline Polytechnic: a round research tower wrapped in glowing rings
  - Ironreach Citadel: a fortress tower with forge chimneys on basalt
- **Halcyon City** across the Skybridge: a street grid of neon high-rises, shop signs, a central square
  with a clock tower and fountains, and parked hover cars.
- **38 NPCs**: seat-holders, the four school aces, school guides, staff and city people. Walk up and
  press **E** (keyboard), **X** (controller) or tap the prompt (mobile) to talk.
- A duel arena template in ServerStorage (not used yet), plus golden-hour lighting, bloom and clouds.

Not built yet: school selection and character customisation on join, per-school rank leaderboards,
combat and weapons, and the shop menu.

## Working on the code

The game is a [Rojo](https://rojo.space) project. Source lives in `src/`:

- `src/server/` builds the world (`Campus`, `Npcs`, `Arena`, `Atmos`) and runs the server
- `src/client/` is the player's side (the dialogue box so far)
- `src/shared/` holds config and the NPC roster

To rebuild the place file after changing code (needs `rojo` and `lune`):

```bash
rojo build default.project.json -o build/base.rbxl
lune run tools/lune/bake.luau          # writes HalcyonClash.rbxl
node tools/lune/lint.mjs               # Luau lint
node tools/preview/shot.mjs --scene build/scene.json --out build/shots   # preview renders
```

`web/` holds the earlier browser prototype.
