# Rusher

Built from the sheets in `source/` by `res://tools/build_sprite_pack.gd` using `pack.json`
(see docs/sprite-pack-guide.md).

- `Rusher.tscn` uses the shared `res://art/zombies/ZombieSprite.gd` (body only, no effects).
- Drawn facings: **SE** (`rusher_se.png`) and **NE** (`rusher_ne.png`); SW and NW are mirrored.
- Free-form rows (sheet order): idle 6, detection 3, attack 6 (sprinting lunge), hit 3, walk 8 (the run cycle),
  recovery 4 (getting up from a crouch), death 6. Same counts in both facings.
- The run row is named `walk` so the game's movement state uses it; it plays at 12 fps.
- `expect` gives every row's count because several frames touch side by side.
- On the NE sheet the rows touch each other too, so `seams` cuts between them
  (attack/hit, hit/run, run/recovery, recovery/death).

Missing / could be better:
- A stray hand from the previous frame shows behind NE attack frame 5, and a small speck sits beside NE death frame 3.
