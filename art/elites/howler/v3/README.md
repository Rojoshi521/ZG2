# Howler V3

Built from the sheets in `source/` by `res://tools/build_sprite_pack.gd` using `pack.json`.
Re-run it (see docs/sprite-pack-guide.md) after replacing a source sheet; it regenerates `frames/`, `vfx/`,
both `.tres` files and `build_report.json`.

- `HowlerV3.tscn` / `HowlerV3.gd`: drop-in replacement for V2's `HowlerIso` (same API),
  plus an `action_finished(state)` signal when a one-shot animation ends.
- Drawn facings: **SE** (`howler_se.png`, `howler_se_2.png`) and **NE** (`howler_ne.png`,
  `howler_ne_2.png`). SW and NW are mirrored in-engine.
- All eight states, 6 frames each: idle, walk, attack, scream (sheet 1) and
  detection, recovery, hit, death (sheet 2). Hit also flashes red.
- Death frames are 256 px wide; the body's back edge stays put so it falls forward.
- Scream VFX: `scream_shards` plus an additive `scream_glow`, spawned at the mouth on body frame 1.
  Tune position, angle and size with `MOUTH`, `BLAST_ANGLE` and `BLAST_SIZE` in `HowlerV3.gd`.
