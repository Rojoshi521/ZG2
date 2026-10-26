# Making a character sprite pack (ZG2, Godot 4)

Everything needed to go from "I have concept art" to "it walks around in Godot".
The Howler (`art/elites/howler/v3/`) is the worked example; copy it.

---

## 1. What a complete pack is

| Piece | Count | Where it lives |
|---|---|---|
| Body sheet 1 (idle, walk, attack, special) | 1 per drawn facing (SE, NE) | `source/<name>_se.png`, `source/<name>_ne.png` |
| Body sheet 2 (detection, recovery, hit, death) | 1 per drawn facing (SE, NE) | `source/<name>_se_2.png`, `source/<name>_ne_2.png` |
| VFX sheets (optional, per effect layer) | 1 per layer | `source/<effect>.png` |
| `pack.json` | 1 | pack folder |
| Character scene + script | 1 each | `<Name>.tscn`, `<Name>.gd` |

So a full character is **4 body sheets** (2 facings × 2 sheets), plus any effect sheets.
That's **8 animations × 6 frames × 2 facings = 96 frames**. SW and NW come free: Godot mirrors SE and NE.

> Mirroring only works for **symmetrical** characters. If one side carries something
> (the Warden's shield, the Breaker's fist), you need all four facings drawn: add SW and NW
> sheets and set `DRAWN` in the script so nothing is flipped.

---

## 2. Art spec (what to ask the image generator for)

Every body sheet must be:

- **1536 × 1024 PNG with a transparent background.** Not a painted backdrop; a coloured preview background is fine only if the file itself has real alpha.
- **A 6 × 4 grid**: 6 frames across, 4 animations down (one animation per row, in the order you list in `pack.json`). Each cell is 256 × 256.
- **One facing per sheet.** Never mix facings in a sheet; generators drift and you get SW frames inside an SE row.
  - **SE** = front-right: body turned toward the camera, facing screen-right.
  - **NE** = back-right: back to the camera, facing screen-right and away.
- **The same character size in every cell and on every sheet.** No per-frame zoom.
- **Full body in every cell, nothing cropped.** Limbs may poke a little past a cell line, but figures must **not touch** each other.
- **Feet on the same baseline** in standing frames.
- **No text, labels, arrows, grid lines, ground tiles or cast shadows.** Effects (scream waves, sparks) go on a separate VFX sheet, never baked into the body.
- **Same camera angle as the concept sheet** (isometric, ~30° down).

VFX sheets:

- Transparent PNG, frames **left to right**, **6 frames** growing or fading over time.
- **Every frame points right**, with the point it comes out of (mouth, hand, barrel) at the frame's **left edge**.
- Gaps between frames help; slight overlap is handled.
- Two layers work well: a crisp layer (shards) and a soft glow layer (rendered additively).

### Standard animation set

| Row | Animation | Loops | FPS | What it shows |
|---|---|---|---|---|
| Sheet 1, row 1 | `idle` | yes | 6 | Breathing, swaying in place. **The first sheet of each facing must have idle: it sets the scale.** |
| Sheet 1, row 2 | `walk` | yes | 8 | One full step cycle; frame 6 flows into frame 1 |
| Sheet 1, row 3 | `attack` | no | 10 | Wind-up, strike, follow-through, return |
| Sheet 1, row 4 | special (`scream` for the Howler) | no | 8 | The elite's signature ability |
| Sheet 2, row 1 | `detection` | no | 8 | Notices the player: head snaps up or turns |
| Sheet 2, row 2 | `recovery` | no | 8 | Comes back to idle after the special |
| Sheet 2, row 3 | `hit` | no | 12 | Recoil from damage and back |
| Sheet 2, row 4 | `death` | no | 8 | Standing → collapsed; the last frame is the corpse |

Rename the special row per elite (`charge` for the Breaker, `leap` for the Harrier...). Use the same name in `pack.json` and the script.

---

## 3. Generator prompts

Attach the concept sheet as a reference with each prompt. Make **one request per sheet**.

**Body sheet 1 (repeat for NE, replacing the facing line):**

> Sprite sheet of [CHARACTER NAME] from the attached concept art, for a 2D isometric game.
> 1536×1024 PNG, fully transparent background. A 6-column × 4-row grid of 256×256 cells, one animation per row:
> row 1 idle (6 frames, subtle breathing), row 2 walk cycle (6 frames, looping),
> row 3 attack (6 frames), row 4 [SPECIAL] (6 frames).
> Every frame shows the character facing **south-east: three-quarter front view, turned toward the camera, facing screen-right**.
> Isometric camera ~30° down, the same as the concept art. Same size and same baseline in every cell. Full body visible, nothing cropped, figures not touching.
> No text, labels, grid lines, shadows, ground or effects. Match the concept art's style, palette and detail exactly.

NE facing line: *"facing **north-east: three-quarter back view, back to the camera, facing screen-right and away**"*.

**Body sheet 2:** same prompt, with rows *"row 1 detection (notices the player), row 2 recovery (returns to idle after [SPECIAL]), row 3 hit reaction, row 4 death (collapses; final frame lying on the ground)"*. Add: *"Same scale as the first sheet."*

**VFX sheet:**

> 6-frame effect animation of [EFFECT, e.g. a red sonic scream blast] for a 2D isometric game, frames left to right on one transparent PNG, each frame growing larger.
> Every frame points to the right and starts from a point at its left edge. No character, no background, no text.

### Getting the images out of ChatGPT

`blob:https://chatgpt.com/...` links only work inside that browser tab. **Right-click the image → Save image as…** and save the actual file to `Downloads`.

---

## 4. Folder layout

```
art/elites/<name>/
  pack.json            # build settings (below)
  <Name>.tscn          # character scene
  <Name>.gd            # character script
  README.md            # what's in the pack, what's missing
  source/              # the generator's sheets, renamed
    <name>_se.png  <name>_ne.png  <name>_se_2.png  <name>_ne_2.png
    <effect>.png ...
  frames/  vfx/        # GENERATED: don't edit by hand
  <Name>Frames.tres    # GENERATED SpriteFrames for the body
  <Name>Vfx.tres       # GENERATED SpriteFrames for effects
  build_report.json    # GENERATED: check it after every build
```

---

## 5. `pack.json`

Copy `art/elites/howler/v3/pack.json` and edit it.

| Field | Meaning |
|---|---|
| `sprite_frames` | Output SpriteFrames file name for the body |
| `cols`, `cell` | Grid columns and cell size of the source sheets (6, 256) |
| `frame`, `feet_y` | Output frame size and where the feet land (192, 184). Keep these the same for every character |
| `target_height` | Idle height in pixels. 126 for a human-sized elite; scale up for big ones (Breaker, Revenant ~170) |
| `fps`, `looping` | Per-animation speed and which ones loop |
| `wide` | Animations that need a wider frame because the body lies down (`{"death": 256}`) |
| `emitter_probe` | Optional: the animation where an effect is emitted. The build reports where the mouth or hand is, for the script |
| `body_sheets` | `[{facing, file, rows}]`. List each facing's idle sheet first |
| `body_sheets[].layout` | Optional. `"grid"` (default) is the 6 × 4 grid. `"rows"` takes a free-form sheet: any number of rows and any number of frames per row, with no grid. Frame counts can differ per row and per facing (see the Shambler) |
| `body_sheets[].rows` (repeats) | The same name on several rows makes one animation continue across them, e.g. `[..., "death", "death"]` for a death drawn over two rows (Drifter) |
| `body_sheets[].expect` | Optional, `rows` layout only. If two frames touch and come out as one, the tool cuts the widest figure at its emptiest column until the row has the right count. Either `{"death": 7}` (by name) or a list with one count per row, `[0, 0, 0, 0, 4, 6]` (0 = leave as found). Use the list when a name repeats |
| `body_sheets[].cuts` | Optional: polylines `[[[x, y], [x, y], ...]]` in sheet pixels, for figures drawn **overlapping** (e.g. one zombie's boot over another's back). A 2 px line is dropped along each one so they separate. Find the spot by viewing the sheet zoomed in |
| `body_sheets[].seams` | Optional: `[[y0, y1], ...]` bands where two **rows** touch. In each band the tool finds the least opaque path across the sheet (it goes around figures where it can) and cuts along it. Find bands by looking for the rows' narrowest point; one or two figures touching is enough to swap pieces between rows |
| `body_sheets[].erase` | Optional: `[[x, y, w, h], ...]` rects cleared before anything else, for row labels drawn on the sheet (otherwise a label near a frame gets attached to it) |
| `vfx` | Optional: `sprite_frames`, `scale`, `frames`, `fps`, and `sheets` mapping animation name → file |

---

## 6. Build

From the project folder, in Git Bash:

```bash
G="/c/Users/shibi/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --script res://tools/build_sprite_pack.gd -- res://art/elites/<name>
"$G" --headless --path . --import
```

The first command builds the frames and `.tres` files; the second makes Godot import them. Opening the editor also imports them.

Then open `build_report.json` and check:

- **`warnings` is empty in every sheet.** `empty cell` means the generator drew fewer than 6 frames; `figures may be touching` means two frames merged; `clipped at frame edge` means a frame is too big for its box, so raise its `wide` value or lower `target_height`.
- **`scale` is about the same for SE and NE.** A big difference means the generator drew one sheet bigger, so compare the heights.
- **The `heights` make sense.** Idle should be close to `target_height`. Specials and detection can be taller (head thrown back); death shrinks to a lying height.
- **`emitter_offsets_from_feet`** gives the mouth or hand position for the script's `MOUTH` constant.
- **`vfx_*` → `origin`**: set each VFX sprite to `centered = false` and `offset = -origin`.

---

## 7. Character scene and script

Copy `HowlerV3.tscn` and `HowlerV3.gd`, rename them, and fix the paths inside the `.tscn`. Then adjust:

- **`Body`**: `sprite_frames` = your `<Name>Frames.tres`, `offset = (0, -88)` (puts the feet on the node origin), `texture_filter = Linear` for painterly art (use Nearest for crisp pixel art).
- **`STATES`**: your eight animation names (rename `scream` to your special).
- **`DRAWN`**: leave it as is for mirrored characters; for asymmetric ones map each facing to itself with `false`.
- **Effects**: `MOUTH` (from the build report), `BLAST_ANGLE` (tilt so the effect points the way the character faces: SE is +26.6° on screen, NE is −26.6°), `BLAST_SIZE`, and which body frame triggers it (`SCREAM_VFX_FRAME`). A glow layer uses a `CanvasItemMaterial` with blend mode **Add**.
- The API stays the same for every character: `set_facing("se"|"sw"|"ne"|"nw")`, `set_facing_from_screen_vector(v)`, `set_state(name)`, the `facing` / `state` vars, and the `action_finished(state)` signal.

---

## 8. Test it

1. Open the project in Godot. Select the root of `tests/sprite_test.tscn` and set **Character** in the Inspector to your new scene.
2. Press **F6** to run that scene (**F5** runs the main scene, which is this test).
3. Keys **1–8** pick a state (in `STATES` order), **A** toggles auto-cycling, **R** replays, **left-click** moves the walker, and the **mouse wheel** zooms.

### Final QA checklist

- [ ] All four facings point the right way, and the mirrored ones too (walk the walker in a full square).
- [ ] Walk doesn't slide: the feet stay planted, and there's no size pulsing between frames.
- [ ] Nothing is cropped (watch arms in attack and the head in the special).
- [ ] Death ends lying down, falls forward, and doesn't slide back.
- [ ] The effect comes out of the right spot, points the right way in all four facings, and disappears when it's done.
- [ ] Size next to other characters looks right at normal zoom.
- [ ] `build_report.json` has no warnings.
- [ ] The pack's README lists anything still missing.

---

## 9. Problems we hit (and how to spot them)

| Problem | Seen in | Fix |
|---|---|---|
| Flat concept sheets with painted backgrounds, not frames | Elite concept zip | Ask for sprite sheets with the spec above |
| Straight front/back/side views instead of isometric diagonals | Howler V1 | Ask for SE / NE by the descriptions in section 2 |
| "Animation" made by nudging one pose; legs never move | Howler V1 front/back | Ask for 6 distinct poses per row |
| Duplicate frames, or one animation copied as another | Howler V1 (`special` = `scream`) | Check with the build report and the test scene |
| Art cropped inside the frame by a hard straight edge | Howler V1 | Full body, nothing cropped |
| Effect baked into the body and flickering | Howler V1 | Effects on their own sheet |
| Facings mixed up within one animation | Howler V2 | One facing per sheet; mirror the west facings |
| Size pulsing because each frame was scaled separately | Howler V2 | Same scale in every cell; the build tool scales a whole sheet at once |
| Limbs and heads crossing into the neighbouring cell | Howler V3 | Handled: the tool separates figures by shape, not by grid |
| VFX frames overlapping each other | Howler V3 glow | Handled: the tool splits at the emptiest column |
| One sheet with uneven rows (6, 8, 3... frames) instead of the grid | Shambler | Handled: `"layout": "rows"` |
| Two frames touching and merging into one | Shambler NE death | `"expect": {"death": 7}` on that sheet |
| Corpse falls so far forward it's clipped | Shambler SE death | Raise `wide` (`{"death": 288}`) |
| One animation drawn over two rows | Drifter death | List the name twice in `rows` |
| Rows overlapping vertically, figures overlapping each other | Drifter NE death | Rows are grouped by feet line (handled); overlapping figures need a `cuts` line |
| Rows touching each other (a boot touches the head below), so pieces land in the wrong row and `expect` splits junk | Rusher NE | Build once without `expect` to see the real counts, then add `seams` bands between the touching rows |
| A zip of pre-cut frames instead of sheets | Twitcher | `tools/frames_to_sheet.gd` packs them into a `rows` sheet (and strips chart border lines), then build as usual |
| Frames cut from labelled charts with painted backgrounds, mixing two charts | Twitcher V1 zip | Unusable: two different bodies, low resolution, pale fringe. Use a single chart instead |
| A labelled chart (panels, SE top / NE bottom) with a faint glow "haze" behind the figures | Twitcher | `tools/chart_to_sheets.gd` clears the haze, drops labels/borders and stacks panels as rows (column-major order). Without it, a brown box shows around the zombie in game |
| A labelled chart whose panels have a dark checker background baked in (opaque, not transparent) | Grabber | `tools/keyed_chart_to_sheets.gd` finds each frame cell from the grey divider lines, keys the background out (lighter/warmer than the cell edge, plus the chart's own soft alpha silhouette for dark legs) and writes panels as rows in reading order (left to right, then down). Check the printed row order against `rows` |
| A state missing from the sheet | Drifter (no detection) | Fine: `ZombieSprite` ignores it and the test scene leaves it out of the 1–N keys |

---

## 10. Regular zombies

Regular zombies (`art/zombies/<name>/`) are the same process without effects, so they share one script: `res://art/zombies/ZombieSprite.gd`.
Its `STATES` are idle, walk, shuffle, skitter, detection, crouch, twitch, attack, reach, grab, lunge, hit, recovery and death; each zombie only needs the ones it has (missing ones are ignored). Add a name there if a new zombie brings a new animation. Copy `art/zombies/shambler/` (`pack.json` and `Shambler.tscn`), rename it and point the scene at your `<Name>Frames.tres`.
One sheet per facing with all six rows is enough. The test scene reads `STATES` from the character's script, so the number keys match whatever states the character has.
