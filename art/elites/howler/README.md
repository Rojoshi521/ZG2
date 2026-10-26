# Howler ISO V2 — Godot 4 keyframe prototype

The pack contains actual alpha-transparent, equal-size PNG sprite frames and Godot import resources. **Not final production art:** Frames come from separately drawn image-generator cells. They are not model-rigged motion, and small details may wobble between frames; review and hand-polish before shipping.

## Improvements
- Four **isometric diagonal** facings: **SE, SW, NE, NW**, not down/left/up/right.
- Eight actual image-based animation states: idle, walk, detection, scream, attack, hit, recovery, death.
- Every slot comes from a different illustrated source pose rather than copied/mirrored sprites. The SHA-256 audit catches byte-identical images; it cannot promise every illustrated pose looks maximally different, especially idle.
- 192×192 RGBA frames; entire extracted silhouette fitted within a consistent transparent frame. A few occluded/tightly spaced source limbs may already be clipped in the source art; do not assume manual sprite QA is complete.
- VFX isolated into a **separate transparent sheet**, plus direction-specific effect frames. No redundant special state.
- Maintains gritty textured low-res art, enlarged with nearest-neighbor sampling for crisp pixels.

## Godot import
1. Place the `Howler_Isometric_V2` folder unchanged at the root of your Godot project (`res://art/elites/howler/`).
2. Open/instance `HowlerIso.tscn`. It contains `Body` and separate `ScreamVFX` nodes.
3. Call `set_facing("se"|"sw"|"ne"|"nw")`, or `set_facing_from_screen_vector(Vector2)` for screen-space vectors.
4. Call `set_state("idle"|"walk"|"detection"|"scream"|"attack"|"hit"|"recovery"|"death")`.
5. Adjust `Body.offset` and `ScreamVFX.position` to match your camera and collision point.
6. Keep nearest filtering for the gritty pixels.

## Notes
- `manifest.json`: counts/FPS/frame layout, details of duplicate exact hashes.
- `frames/*.png`: individual 192×192 RGBA body frames; `sheets/*.png`: action atlases and separate scream VFX.
- `frame_audit.json`: original cell positions and alpha area for checking extraction.
- These are still **artist-reviewed prototype sprites**, not guaranteed production-ready, seamless animated keyframes; manually check each transition in Godot.
