extends SceneTree
## Turns a generator "chart" (labelled panels, one animation per panel, SE on the
## top half and NE on the bottom) into one "rows" sheet per facing for
## build_sprite_pack.gd.
##
## - Faint haze (alpha < HAZE) is cleared and the rest stretched to fully opaque,
##   so no glow box shows around the figures in game.
## - Panels are the large fully transparent areas; labels, borders and titles
##   outside them are dropped.
## - Each half's panels are stacked as rows in column-major reading order (down
##   the first column, then the next), so list `rows` in pack.json in that order.
## - Leftover border lines (thin straight runs) are stripped.
##
## Run: godot --headless --path . --script res://tools/chart_to_sheets.gd -- <chart.png> <out dir> <name>
## Writes <out dir>/<name>_se.png and <name>_ne.png and prints each panel's rect.

const HAZE := 0.08
const SOLID := 0.95
const MIN_PANEL_AREA := 20000
const INSET := 3  # px trimmed off each panel edge (border antialiasing)
const ROW_GAP := 40


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: ... -- <chart.png> <out dir> <name>")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			c.a = clampf((c.a - HAZE) / (SOLID - HAZE), 0.0, 1.0)
			img.set_pixel(x, y, c)

	var panels := _transparent_areas(img)
	# A figure touching a panel border cuts its transparent area short, so widen
	# each panel to its whole column (shared left edge) and row (shared top edge).
	var fixed := []
	for p in panels:
		var r: Rect2i = p
		for q in panels:
			if (q.get_center().y < h / 2) != (p.get_center().y < h / 2):
				continue
			if absi(q.position.x - p.position.x) <= 20 or absi(q.end.x - p.end.x) <= 20:
				r = r.merge(Rect2i(q.position.x, r.position.y, q.size.x, 1))
			if absi(q.position.y - p.position.y) <= 20 or absi(q.end.y - p.end.y) <= 20:
				r = r.merge(Rect2i(r.position.x, q.position.y, 1, q.size.y))
		fixed.append(r)
	panels = fixed
	var halves := {"se": [], "ne": []}
	for p in panels:
		halves["se" if p.get_center().y < h / 2 else "ne"].append(p)
	for facing in halves:
		var list: Array = halves[facing]
		# Column-major: group by left edge (panels in a column share it within ~20 px).
		list.sort_custom(func(a, b):
			if absi(a.position.x - b.position.x) > 20:
				return a.position.x < b.position.x
			return a.position.y < b.position.y)
		var width := 0
		var height := 0
		for p in list:
			width = maxi(width, p.size.x)
			height += p.size.y + ROW_GAP
		var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
		var y := 0
		for i in list.size():
			var p: Rect2i = list[i]
			out.blit_rect(img, p, Vector2i(0, y))
			print("%s row %d: panel %s" % [facing, i, p])
			y += p.size.y + ROW_GAP
		print("%s: removed %d border line pixels" % [facing, _strip_lines(out)])
		out.save_png(args[1].path_join("%s_%s.png" % [args[2], facing]))
	quit()


## Bounding boxes (inset) of 4-connected fully transparent areas big enough to be panels.
func _transparent_areas(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var rects := []
	var stack := PackedInt32Array()
	for start in w * h:
		if seen[start] == 1 or img.get_pixel(start % w, start / w).a > 0.0:
			continue
		var min_x := w; var min_y := h; var max_x := 0; var max_y := 0
		var area := 0
		seen[start] = 1
		stack.append(start)
		while stack.size() > 0:
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px := p % w
			var py := p / w
			area += 1
			min_x = mini(min_x, px); max_x = maxi(max_x, px)
			min_y = mini(min_y, py); max_y = maxi(max_y, py)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = px + d.x
				var ny: int = py + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var q := ny * w + nx
				if seen[q] == 0 and img.get_pixel(nx, ny).a <= 0.0:
					seen[q] = 1
					stack.append(q)
		if area >= MIN_PANEL_AREA:
			rects.append(Rect2i(min_x + INSET, min_y + INSET, max_x - min_x + 1 - INSET * 2, max_y - min_y + 1 - INSET * 2))
	return rects


## Leftover panel border lines: runs of 30+ px that are at most 3 px thick.
func _run(img: Image, x: int, y: int, dx: int, dy: int) -> int:
	var n := 0
	var px := x; var py := y
	while px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() and img.get_pixel(px, py).a > 0.03:
		n += 1; px += dx; py += dy
	return n

func _strip_lines(img: Image) -> int:
	var kill := []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a <= 0.03:
				continue
			var horiz := _run(img, x, y, 1, 0) + _run(img, x, y, -1, 0) - 1
			var vert := _run(img, x, y, 0, 1) + _run(img, x, y, 0, -1) - 1
			if (horiz <= 3 and vert >= 30) or (vert <= 3 and horiz >= 30):
				kill.append(Vector2i(x, y))
	for p in kill:
		img.set_pixelv(p, Color(0, 0, 0, 0))
	return kill.size()
