# Crawler

Built from the sheets in `source/` by `res://tools/build_sprite_pack.gd` using `pack.json`
(see docs/sprite-pack-guide.md).

- `Crawler.tscn` uses the shared `res://art/zombies/ZombieSprite.gd` (body only, no effects).
- Drawn facings: **SE** (`crawler_se.png`) and **NE** (`crawler_ne.png`); SW and NW are mirrored.
- Free-form rows, 6 frames each: idle, detection, walk (crawl), attack (claw swipes), lunge (rear up and grab).
- `target_height` is 72 because it moves on all fours (a standing zombie is about 120).
- The frames overlap on the sheets, so `expect` asks for 6 per row and cuts them apart.

Missing / could be better:
- No hit, recovery or death rows yet.
- A stray toe from the next frame shows behind NE walk frame 1.
