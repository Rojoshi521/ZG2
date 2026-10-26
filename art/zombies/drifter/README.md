# Drifter

Built from the sheets in `source/` by `res://tools/build_sprite_pack.gd` using `pack.json`
(see docs/sprite-pack-guide.md).

- `Drifter.tscn` uses the shared `res://art/zombies/ZombieSprite.gd`.
- Drawn facings: **SE** (`drifter_se.png`) and **NE** (`drifter_ne.png`); SW and NW are mirrored.
- Rows: idle, walk, attack, hit, then death across the last **two** rows (listed twice in `rows`).
- Frame counts (SE / NE): idle 8/8, walk 8/8, attack 6/6, hit 7/7, death 10/9.
- No detection animation; `set_state("detection")` is ignored.
- Sheet fixes in `pack.json`:
  - `expect` per row: the last death row's frames touch, so they're cut apart to 6 (SE) / 5 (NE).
  - `cuts` (NE): the first death frame's boot overlaps the crawling frame below it; a cut line separates them.
