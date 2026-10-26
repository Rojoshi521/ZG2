# Harrier

Built from the sheets in `source/` by `res://tools/build_sprite_pack.gd` using `pack.json`
(see docs/sprite-pack-guide.md).

- `Harrier.tscn` uses the shared `res://art/zombies/ZombieSprite.gd` (body only, no effects).
- Drawn facings: **SE** (`harrier_se.png`, from harrier1) and **NE** (`harrier_ne.png`, from harrier2); SW and NW are mirrored.
- Rows follow the sheet labels: idle 6, detection 4, leap_prep 4, leap 6 (the sheet's LEAP_CAST),
  recovery 5 (LAND_RECOVERY), walk 8 (SPRINT, at 12 fps so movement uses it), hit 3, death 6. Same in both facings.
- The red row labels are cleared with `erase`; the rows touch each other, so `seams` cuts between every pair,
  and `expect` splits frames that touch side by side.
- Leap and death frames are 384 px wide (the body stretches far forward).
