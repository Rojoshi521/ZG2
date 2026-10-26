extends SceneTree
## Turns a generator "chart" whose panels have a dark background baked in (not
## transparent) into one "rows" sheet per facing for build_sprite_pack.gd.
##
## - Panels are the large opaque areas; each panel's frame box and the cells in it
##   are found from the thin grey divider lines, and the label above is dropped.
## - In each cell the background colour is sampled from the cell's edge and keyed
##   out by colour distance; only the figure (pieces touching its largest blob)
##   is kept and small holes in it are filled.
## - SE is the top half, NE the bottom. Panels are written as rows in reading
##   order (left to right, then down), each cell separated by a gap, so list
##   `rows` in pack.json in the printed order.
##
## Run: godot --headless --path . --script res://tools/keyed_chart_to_sheets.gd -- <chart.png> <out dir> <name>

const LIGHT_MARGIN := 0.05  # how much lighter than the background edge counts as figure
const DARK_MARGIN := 0.05   # how much darker (outlines; the art has a dark halo, so keep this high)
const WARM_MARGIN := 0.07   # how much warmer (skin, blood, boots)
const MIN_LIGHT := 0.22   # floors, for cells whose edge is darker than the background by the figure
const MIN_WARM := 0.1
const MATTE := 0.965       # the chart's alpha is a soft silhouette: ~0.98 on the figure, lower on the background
const MATTE_MARGIN := 0.015 # above the cell edge's alpha (it varies between panels)
const MATTE_SHRINK := 2     # px the blurred silhouette is shrunk by
const CLOSE := 2            # px gap closed between figure pieces
const MIN_PANEL := Vector2i(200, 100)
const GAP := 24
const ROW_GAP := 40
const MAX_HOLE := 40    # enclosed background areas up to this many px are filled


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: ... -- <chart.png> <out dir> <name>")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var h := img.get_height()
	# Panels that touch come out as one area, so collect frame boxes, not panels.
	var boxes := []
	for p in _opaque_areas(img):
		boxes.append_array(_boxes(img, p))
	boxes.sort_custom(func(a, b):
		if absi(a[0].position.y - b[0].position.y) > 20:
			return a[0].position.y < b[0].position.y
		return a[0].position.x < b[0].position.x)
	# A box whose top line wasn't found starts at the label; trim it to the usual height.
	var heights := boxes.map(func(b): return b[0].size.y)
	heights.sort()
	var usual: int = heights[heights.size() / 2]
	for cells in boxes:
		for i in cells.size():
			var c: Rect2i = cells[i]
			if c.size.y > usual + 6:
				cells[i] = Rect2i(c.position.x, c.end.y - usual + 3, c.size.x, usual - 3)  # skip the missed line
	var halves := {"se": [], "ne": []}
	for cells in boxes:
		halves["se" if cells[0].position.y < h / 2 else "ne"].append(cells)
	for facing in halves:
		var rows: Array = halves[facing]
		var width := 0
		var height := 0
		for cells in rows:
			var w := 0
			var ch := 0
			for c in cells:
				w += c.size.x + GAP
				ch = maxi(ch, c.size.y)
			width = maxi(width, w)
			height += ch + ROW_GAP
		var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
		var y := 0
		for i in rows.size():
			var cells: Array = rows[i]
			var x := 0
			var ch := 0
			for c in cells:
				out.blit_rect(_key(img, c), Rect2i(Vector2i.ZERO, c.size), Vector2i(x, y))
				x += c.size.x + GAP
				ch = maxi(ch, c.size.y)
			print("%s row %d: %d cells at %s" % [facing, i, cells.size(), cells[0].position])
			y += ch + ROW_GAP
		out.save_png(args[1].path_join("%s_%s.png" % [args[2], facing]))
	quit()


## Bounding boxes of 4-connected opaque (alpha > 0.76) areas big enough to be panels.
func _opaque_areas(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var rects := []
	var stack := PackedInt32Array()
	for start in w * h:
		if seen[start] == 1 or img.get_pixel(start % w, start / w).a <= 0.76:
			continue
		var r := Rect2i(start % w, start / w, 1, 1)
		seen[start] = 1
		stack.append(start)
		while stack.size() > 0:
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px := p % w
			var py := p / w
			r = r.expand(Vector2i(px, py))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = px + d.x
				var ny: int = py + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var q := ny * w + nx
				if seen[q] == 0 and img.get_pixel(nx, ny).a > 0.76:
					seen[q] = 1
					stack.append(q)
		r.size += Vector2i.ONE
		if r.size.x >= MIN_PANEL.x and r.size.y >= MIN_PANEL.y:
			rects.append(r)
	return rects


## Thin grey divider pixel: light, unsaturated.
func _is_line(c: Color) -> bool:
	return c.v > 0.19 and c.v < 0.7 and c.s < 0.12


## Runs of consecutive indices where `hits` is true, as [start, end) pairs.
func _runs(hits: Array) -> Array:
	var out := []
	var i := 0
	while i < hits.size():
		if hits[i]:
			var j := i
			while j < hits.size() and hits[j]:
				j += 1
			out.append(Vector2i(i, j))
			i = j
		else:
			i += 1
	return out


## Each frame box in a panel (the space between two horizontal lines at least
## MIN_PANEL.y * 0.6 apart; labels sit in the narrower gaps), as an array of cells.
func _boxes(img: Image, p: Rect2i) -> Array:
	var rows_hit := []
	for y in range(p.position.y, p.end.y):
		var n := 0
		for x in range(p.position.x, p.end.x):
			if _is_line(img.get_pixel(x, y)):
				n += 1
		rows_hit.append(n > p.size.x * 0.6)
	var hlines := _runs(rows_hit)
	var out := []
	for i in hlines.size() - 1:
		var top: int = p.position.y + hlines[i].y
		var bottom: int = p.position.y + hlines[i + 1].x
		if bottom - top >= MIN_PANEL.y * 0.6:
			var cells := _cells(img, p, top, bottom)
			if not cells.is_empty():
				out.append(cells)
	return out


## The cells of one frame box, split at the vertical dividers. A cell about twice
## the usual width (a divider hidden behind a figure) is split evenly.
func _cells(img: Image, p: Rect2i, top: int, bottom: int) -> Array:
	var cols_hit := []
	for x in range(p.position.x, p.end.x):
		var n := 0
		for y in range(top, bottom):
			if _is_line(img.get_pixel(x, y)):
				n += 1
		cols_hit.append(n > (bottom - top) * 0.5)
	var vlines := _runs(cols_hit)
	var cells := []
	for i in vlines.size() - 1:
		var x0: int = p.position.x + vlines[i].y + 1
		var x1: int = p.position.x + vlines[i + 1].x - 1
		if x1 - x0 > 20:
			cells.append(Rect2i(x0, top + 1, x1 - x0, bottom - top - 2))
	if cells.is_empty():
		return cells
	var widths := cells.map(func(c): return c.size.x)
	widths.sort()
	var usual: int = widths[widths.size() / 2]
	var split := []
	for c in cells:
		var n := maxi(1, roundi(float(c.size.x) / usual))
		for k in n:
			var x0: int = c.position.x + c.size.x * k / n
			var x1: int = c.position.x + c.size.x * (k + 1) / n
			split.append(Rect2i(x0, c.position.y, x1 - x0, c.size.y))
	return split


## The cell with its background keyed out. The background is dark, grey and
## textured, and the figure's shadows are as dark as it, so colour distance alone
## can't tell them apart. Instead the figure is seeded from pixels the background
## never has (lighter, darker or warmer than its edge ring), plus the chart's own
## soft alpha silhouette (shrunk so its blur doesn't add a halo), which catches the
## dark legs. Then small gaps are closed and enclosed background is filled.
func _key(img: Image, cell: Rect2i) -> Image:
	var ring := []
	for x in range(cell.position.x, cell.end.x):
		ring.append(img.get_pixel(x, cell.position.y))
		ring.append(img.get_pixel(x, cell.end.y - 1))
	for y in range(cell.position.y, cell.end.y):
		ring.append(img.get_pixel(cell.position.x, y))
		ring.append(img.get_pixel(cell.end.x - 1, y))
	var values := ring.map(func(c): return c.v)
	values.sort()
	var warmth := ring.map(func(c): return c.r - c.b)
	warmth.sort()
	var light: float = maxf(values[int(values.size() * 0.9)] + LIGHT_MARGIN, MIN_LIGHT)
	var dark: float = values[int(values.size() * 0.03)] - DARK_MARGIN
	var warm: float = maxf(warmth[int(warmth.size() * 0.9)] + WARM_MARGIN, MIN_WARM)
	var opacity := ring.map(func(c): return c.a)
	opacity.sort()
	var matte: float = maxf(opacity[int(opacity.size() * 0.9)] + MATTE_MARGIN, MATTE)
	var w := cell.size.x
	var h := cell.size.y
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	var silhouette := PackedFloat32Array()
	silhouette.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(cell.position.x + x, cell.position.y + y)
			alpha[y * w + x] = 1.0 if c.v > light or c.v < dark or c.r - c.b > warm else 0.0
			silhouette[y * w + x] = 1.0 if c.a > matte else 0.0
	silhouette = _erode(silhouette, w, h, MATTE_SHRINK)
	for i in w * h:
		alpha[i] = maxf(alpha[i], silhouette[i])
	alpha = _erode(_dilate(alpha, w, h, CLOSE), w, h, CLOSE)
	_keep_figure(alpha, w, h)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(cell.position.x + x, cell.position.y + y)
			c.a = alpha[y * w + x]
			out.set_pixel(x, y, c)
	return out


func _dilate(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var v := 0.0
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var nx := x + dx
					var ny := y + dy
					if dx * dx + dy * dy <= r * r and nx >= 0 and ny >= 0 and nx < w and ny < h:
						v = maxf(v, a[ny * w + nx])
			out[y * w + x] = v
	return out


func _erode(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var inv := PackedFloat32Array()
	inv.resize(w * h)
	for i in w * h:
		inv[i] = 1.0 - a[i]
	inv = _dilate(inv, w, h, r)
	for i in w * h:
		inv[i] = 1.0 - inv[i]
	return inv


func _median(colors: Array, channel: int) -> float:
	var v := colors.map(func(c): return c[channel])
	v.sort()
	return v[v.size() / 2]


## Labels 8-connected pixels where `solid(i)` is true; returns [labels, sizes].
func _label(w: int, h: int, solid: Callable) -> Array:
	var labels := PackedInt32Array()
	labels.resize(w * h)
	labels.fill(-1)
	var sizes := []
	var stack := PackedInt32Array()
	for start in w * h:
		if labels[start] != -1 or not solid.call(start):
			continue
		var id := sizes.size()
		var n := 0
		labels[start] = id
		stack.append(start)
		while stack.size() > 0:
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			n += 1
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = p % w + dx
					var ny: int = p / w + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var q := ny * w + nx
					if labels[q] == -1 and solid.call(q):
						labels[q] = id
						stack.append(q)
		sizes.append(n)
	return [labels, sizes]


## Drops blobs that aren't part of the figure and fills small holes in it.
func _keep_figure(alpha: PackedFloat32Array, w: int, h: int) -> void:
	var solid := _label(w, h, func(i): return alpha[i] > 0.5)
	var labels: PackedInt32Array = solid[0]
	var sizes: Array = solid[1]
	if sizes.is_empty():
		return
	var biggest: int = sizes.max()
	# Keep big blobs (a separated arm or foot) and drop specks and texture noise.
	var keep := {}
	for id in sizes.size():
		if sizes[id] >= biggest * 0.04:
			keep[id] = true
	# Faint edge pixels count only next to a kept blob.
	var near := PackedByteArray()
	near.resize(w * h)
	for i in w * h:
		if labels[i] != -1 and keep.has(labels[i]):
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx: int = i % w + dx
					var ny: int = i / w + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						near[ny * w + nx] = 1
	for i in w * h:
		if labels[i] != -1:
			if not keep.has(labels[i]):
				alpha[i] = 0.0
		elif near[i] == 0:
			alpha[i] = 0.0
	# Holes: background areas not touching the cell edge.
	var empty := _label(w, h, func(i): return alpha[i] <= 0.5)
	var elabels: PackedInt32Array = empty[0]
	var esizes: Array = empty[1]
	var edge := {}
	for x in w:
		edge[elabels[x]] = true
		edge[elabels[(h - 1) * w + x]] = true
	for y in h:
		edge[elabels[y * w]] = true
		edge[elabels[y * w + w - 1]] = true
	for i in w * h:
		var id := elabels[i]
		if id != -1 and not edge.has(id) and esizes[id] <= MAX_HOLE:
			alpha[i] = 1.0
