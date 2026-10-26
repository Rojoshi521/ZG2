# Grabber

Built from `source/chart/grabber_chart.png` in two steps (see docs/sprite-pack-guide.md):

1. `res://tools/keyed_chart_to_sheets.gd -- art/zombies/grabber/source/chart/grabber_chart.png art/zombies/grabber/source grabber`
   writes `source/grabber_se.png` and `source/grabber_ne.png`. The chart's panels have a dark checker
   background baked in, so this tool keys it out (the Twitcher's chart tool only handles transparent panels).
2. `res://tools/build_sprite_pack.gd -- res://art/zombies/grabber` builds the frames from `pack.json`.

- `Grabber.tscn` uses the shared `res://art/zombies/ZombieSprite.gd` (body only, no effects).
- Drawn facings: **SE** and **NE**; SW and NW are mirrored.
- States (chart order): idle, walk, hit, detection (the chart's "notice"), reach, recovery, grab, shuffle, death.
- Frame counts (SE / NE): idle 6, walk 8, hit 4, detection 6, reach 6/7, recovery 4, grab 6, shuffle 9, death 9.
  The chart labels say shuffle and death have 8, but 9 are drawn.

Missing / could be better:
- The source frames are small (about 100 px tall), so they're scaled up slightly and look a little soft.
- The dark back leg is close to the background colour, so its edge is a bit ragged in some frames.
- A few reach frames have the hand cut off where the chart cell clipped it.
