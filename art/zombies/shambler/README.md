# Shambler

Built from the sheets in `source/` by `res://tools/build_sprite_pack.gd` using `pack.json`
(see docs/sprite-pack-guide.md).

- `Shambler.tscn` uses the shared `res://art/zombies/ZombieSprite.gd` (body only, no effects).
  Same API as the elites: `set_facing`, `set_facing_from_screen_vector`, `set_state`, `action_finished`.
- Drawn facings: **SE** (`shambler_se.png`) and **NE** (`shambler_ne.png`); SW and NW are mirrored.
- One sheet per facing, free-form rows (`"layout": "rows"`): idle, detection, walk, attack, hit, death.
- Frame counts (SE / NE): idle 6/6, detection 6/6, walk 8/8, attack 8/7, hit 6/3, death 7/7.
- NE death frames 4 and 5 touch on the sheet; `"expect": {"death": 7}` cuts them apart.
- Death frames are 288 px wide, because the body falls a long way forward.

Missing / could be better:
- NE hit has only 3 frames (SE has 6), so it's a quick flinch from behind.
- No recovery row; hit returns to whatever the game sets next.
