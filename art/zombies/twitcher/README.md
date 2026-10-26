# Twitcher

Built from `source/chart/twitcher_chart.png` (a generator chart: labelled panels, SE on top, NE below).
`res://tools/chart_to_sheets.gd` turned it into `source/twitcher2_se.png` / `twitcher2_ne.png`:
it clears the chart's faint brown haze (the "glow" behind the figures, alpha under 8%), makes the
figures fully opaque, drops labels and borders and stacks the panels as rows. Then
`res://tools/build_sprite_pack.gd` built the pack from `pack.json`.

- `Twitcher.tscn` uses the shared `res://art/zombies/ZombieSprite.gd`.
- States (SE / NE frames): idle 6/6, detection 6/6 (the chart's "alert"), crouch 6/6,
  walk 7/8, attack 6/6 (the chart's "lunge"), skitter 8/8 (fast run, loops), hit 4/4,
  recovery 4/4, death 7/7 (touching frames split with `expect`).
- No twitch animation in this chart.

Rebuild:
    godot --headless --path . --script res://tools/chart_to_sheets.gd -- <abs path to chart> <abs path to source/> twitcher2
    godot --headless --path . --script res://tools/build_sprite_pack.gd -- res://art/zombies/twitcher
