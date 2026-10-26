extends SceneTree
## Builds a character sprite pack from generated sheets, driven by the pack's pack.json.
## Run: godot --headless --path . --script res://tools/build_sprite_pack.gd -- res://art/elites/howler/v3
## Full workflow: docs/sprite-pack-guide.md
##
## Body sheets are COLS x rows grids (one animation per row) but limbs spill
## across cell lines, so figures are separated by connected alpha regions
## rather than by grid. Every frame of a facing shares one scale (set from its
## idle row), then sits in a frame with the feet at feet_y and the hips centred.
## "wide" animations (lying down) keep the body's back edge fixed instead, so
## the body falls forward rather than sliding to stay centred.
##
## VFX sheets are frames side by side, each pointing right with its origin
## (the point it emits from) at its leftmost solid pixel.

const ALPHA_KEEP := 0.03
const ALPHA_SOLID := 0.5
const VFX_PAD := 4

var cfg := {}
var out_dir := ""
var report := {}
var facing_scale := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the pack folder: ... --script res://tools/build_sprite_pack.gd -- res://art/<pack>")
		quit(1)
		return
	out_dir = args[0].trim_suffix("/") + "/"
	cfg = JSON.parse_string(FileAccess.get_file_as_string(out_dir + "pack.json"))
	if cfg == null:
		push_error("Could not read %spack.json" % out_dir)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir + "frames"))

	var body_anims := []
	for sheet in cfg["body_sheets"]:
		var counts := _build_body(sheet, _load(out_dir + "source/" + sheet["file"]))
		var totals := {}  # anim -> frames, summed over rows that share a name
		for r in sheet["rows"].size():
			totals[sheet["rows"][r]] = totals.get(sheet["rows"][r], 0) + counts[r]
		for anim in totals:
			var paths := []
			for i in totals[anim]:
				paths.append(out_dir + "frames/%s_%s_%02d.png" % [anim, sheet["facing"], i])
			body_anims.append([anim + "_" + sheet["facing"], paths, cfg["fps"][anim], anim in cfg["looping"]])
	_write_sprite_frames(out_dir + cfg["sprite_frames"], body_anims)

	if cfg.has("vfx"):
		var vfx: Dictionary = cfg["vfx"]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir + "vfx"))
		var vfx_anims := []
		for vfx_name in vfx["sheets"]:
			var count := _build_vfx(vfx_name, _load(out_dir + "source/" + vfx["sheets"][vfx_name]))
			var paths := []
			for i in count:
				paths.append(out_dir + "vfx/%s_%02d.png" % [vfx_name, i])
			vfx_anims.append([vfx_name, paths, vfx["fps"], false])
		_write_sprite_frames(out_dir + vfx["sprite_frames"], vfx_anims)

	var f := FileAccess.open(out_dir + "build_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report, "  "))
	quit()


## Writes a SpriteFrames .tres. Each anim is [name, texture paths, fps, loop].
func _write_sprite_frames(path: String, anims: Array) -> void:
	var ext := ""
	var entries := []
	var n := 0
	for anim in anims:
		var frames := []
		for tex in anim[1]:
			n += 1
			ext += '[ext_resource type="Texture2D" path="%s" id="%d"]\n' % [tex, n]
			frames.append('{"duration": 1.0, "texture": ExtResource("%d")}' % n)
		entries.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.1f}' % [", ".join(frames), "true" if anim[3] else "false", anim[0], anim[2]])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n[resource]\nanimations = [%s]\n' % [n + 1, ext, ",\n".join(entries)])


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## Labels 8-connected regions of alpha > ALPHA_KEEP. Returns [labels, region_info].
## `cuts` are polylines ([[x, y], ...] in sheet pixels) where figures drawn
## overlapping are separated; the 2 px line under them is dropped.
func _regions(img: Image, cuts: Array = []) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var labels := PackedInt32Array()
	labels.resize(w * h)
	labels.fill(-1)
	var keep := PackedByteArray()
	keep.resize(w * h)
	for y in h:
		for x in w:
			keep[y * w + x] = 1 if img.get_pixel(x, y).a > ALPHA_KEEP else 0
	for line in cuts:
		for i in range(1, line.size()):
			var a := Vector2(line[i - 1][0], line[i - 1][1])
			var b := Vector2(line[i][0], line[i][1])
			var steps := ceili(a.distance_to(b)) * 2
			for s in steps + 1:
				var p := Vector2i(a.lerp(b, float(s) / maxi(steps, 1)).round())
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var q: Vector2i = p + d
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
						keep[q.y * w + q.x] = 0
	var info := []
	var stack := PackedInt32Array()
	for start in w * h:
		if keep[start] == 0 or labels[start] != -1:
			continue
		var id := info.size()
		var min_x := w; var min_y := h; var max_x := 0; var max_y := 0
		var count := 0; var sum_x := 0.0; var sum_y := 0.0
		stack.append(start)
		labels[start] = id
		while stack.size() > 0:
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px := p % w
			var py := p / w
			count += 1; sum_x += px; sum_y += py
			min_x = mini(min_x, px); max_x = maxi(max_x, px)
			min_y = mini(min_y, py); max_y = maxi(max_y, py)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = px + dx
					var ny: int = py + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var q := ny * w + nx
					if keep[q] == 1 and labels[q] == -1:
						labels[q] = id
						stack.append(q)
		info.append({"rect": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1), "count": count, "centroid": Vector2(sum_x / count, sum_y / count)})
	return [labels, info]


## Copies only the pixels whose region id is in `ids` into a tight image.
func _extract(img: Image, labels: PackedInt32Array, ids: Array, rect: Rect2i) -> Image:
	var w := img.get_width()
	var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var id_set := {}
	for i in ids:
		id_set[i] = true
	for y in rect.size.y:
		for x in rect.size.x:
			var sx := rect.position.x + x
			var sy := rect.position.y + y
			if id_set.has(labels[sy * w + sx]):
				out.set_pixel(x, y, img.get_pixel(sx, sy))
	return out


## Solid bounding box, plus the hip line's centre x (mean of solid pixels 55-75% down).
func _measure(img: Image) -> Dictionary:
	var min_x := img.get_width(); var min_y := img.get_height(); var max_x := -1; var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > ALPHA_SOLID:
				min_x = mini(min_x, x); max_x = maxi(max_x, x)
				min_y = mini(min_y, y); max_y = maxi(max_y, y)
	var top := min_y + int((max_y - min_y) * 0.55)
	var bottom := min_y + int((max_y - min_y) * 0.75)
	var sum := 0.0; var n := 0
	for y in range(top, bottom + 1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > ALPHA_SOLID:
				sum += x; n += 1
	return {"bbox": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1), "hip_x": sum / maxi(n, 1)}


## Free-form sheets ("layout": "rows"): any number of frames per row, no grid.
## Big regions are split into rows at the largest vertical gaps between their
## bottom edges (rows can overlap, feet lines don't), ordered left to right, and
## merged when they overlap in x (a detached hand). Specks join the nearest figure, or are dropped if far away.
## Returns [cells {Vector2i(frame, row): ids}, counts per row].
func _row_layout(info: Array, row_count: int) -> Array:
	var largest := 0
	for r in info:
		largest = maxi(largest, r["count"])
	var big := []
	var specks := []
	for id in info.size():
		(big if info[id]["count"] >= largest * 0.1 else specks).append(id)
	big.sort_custom(func(a, b): return info[a]["rect"].end.y < info[b]["rect"].end.y)
	var gaps := []
	for i in range(1, big.size()):
		gaps.append([info[big[i]]["rect"].end.y - info[big[i - 1]]["rect"].end.y, i])
	gaps.sort_custom(func(a, b): return a[0] > b[0])
	var splits := [0, big.size()]
	for g in gaps.slice(0, row_count - 1):
		splits.append(g[1])
	splits.sort()

	var cells := {}
	var counts := []
	var rects := {}
	for r in row_count:
		var row: Array = big.slice(splits[r], splits[r + 1])
		row.sort_custom(func(a, b): return info[a]["centroid"].x < info[b]["centroid"].x)
		var c := -1
		var rect := Rect2i()
		for id in row:
			var ir: Rect2i = info[id]["rect"]
			var overlap := mini(rect.end.x, ir.end.x) - maxi(rect.position.x, ir.position.x)
			if c >= 0 and overlap > mini(rect.size.x, ir.size.x) * 0.5:
				cells[Vector2i(c, r)].append(id)
				rect = rect.merge(ir)
			else:
				c += 1
				cells[Vector2i(c, r)] = [id]
				rect = ir
			rects[Vector2i(c, r)] = rect
		counts.append(c + 1)
	for id in specks:
		var p: Vector2 = info[id]["centroid"]
		var best = null
		var best_d := 48.0
		for key in rects:
			var rr: Rect2i = rects[key]
			var d := p.distance_to(p.clamp(Vector2(rr.position), Vector2(rr.end)))
			if d < best_d:
				best_d = d
				best = key
		if best != null:
			cells[best].append(id)
	return [cells, counts]


## Two figures drawn touching come out as one wide region. Cuts the widest
## figure in row r at its emptiest column (middle half only) into two.
func _split_widest(sheet: Image, labels: PackedInt32Array, info: Array, cells: Dictionary, clips: Dictionary, r: int, count: int) -> void:
	var w := sheet.get_width()
	var widest := 0
	var widest_rect := Rect2i()
	for c in count:
		var rect := _figure_rect(info, cells, clips, Vector2i(c, r))
		if rect.size.x > widest_rect.size.x:
			widest = c
			widest_rect = rect
	var ids := {}
	for id in cells[Vector2i(widest, r)]:
		ids[id] = true
	var a := widest_rect.position.x
	var b := widest_rect.end.x
	var cut := a + (b - a) / 2
	var best := 1 << 30
	for x in range(a + (b - a) / 4, b - (b - a) / 4):
		var n := 0
		for y in range(widest_rect.position.y, widest_rect.end.y):
			if ids.has(labels[y * w + x]) and sheet.get_pixel(x, y).a > ALPHA_SOLID:
				n += 1
		if n < best:
			best = n
			cut = x
	for c in range(count - 1, widest, -1):
		cells[Vector2i(c + 1, r)] = cells[Vector2i(c, r)]
		if clips.has(Vector2i(c, r)):
			clips[Vector2i(c + 1, r)] = clips[Vector2i(c, r)]
		else:
			clips.erase(Vector2i(c + 1, r))
	cells[Vector2i(widest + 1, r)] = cells[Vector2i(widest, r)].duplicate()
	clips[Vector2i(widest, r)] = Rect2i(a, widest_rect.position.y, cut - a, widest_rect.size.y)
	clips[Vector2i(widest + 1, r)] = Rect2i(cut, widest_rect.position.y, b - cut, widest_rect.size.y)


func _figure_rect(info: Array, cells: Dictionary, clips: Dictionary, key: Vector2i) -> Rect2i:
	if clips.has(key):
		return clips[key]
	var ids: Array = cells[key]
	var rect: Rect2i = info[ids[0]]["rect"]
	for id in ids:
		rect = rect.merge(info[id]["rect"])
	return rect


## Returns the number of frames found in each row.
func _build_body(sheet_cfg: Dictionary, sheet: Image) -> Array:
	var facing: String = sheet_cfg["facing"]
	var rows: Array = sheet_cfg["rows"]
	var cols := int(cfg["cols"])
	var cell := int(cfg["cell"])
	var frame := int(cfg["frame"])
	var feet_y := int(cfg["feet_y"])
	var wide: Dictionary = cfg.get("wide", {})
	var result := _regions(sheet, sheet_cfg.get("cuts", []))
	var labels: PackedInt32Array = result[0]
	var info: Array = result[1]
	var cells := {}
	var clips := {}  # figure key -> rect, for figures cut out of a shared region
	var counts := []
	if sheet_cfg.get("layout", "grid") == "rows":
		var layout := _row_layout(info, rows.size())
		cells = layout[0]
		counts = layout[1]
		# "expect" splits touching figures until a row has that many: {"death": 7} by
		# name, or a list with one count per row (0 = leave as found).
		var expect = sheet_cfg.get("expect", {})
		for r in rows.size():
			var want := int(expect[r]) if expect is Array else int(expect.get(rows[r], 0))
			while counts[r] < want:
				_split_widest(sheet, labels, info, cells, clips, r, counts[r])
				counts[r] += 1
	else:
		# Each region belongs to the cell holding its centroid; small specks ride along.
		for id in info.size():
			var c: Vector2 = info[id]["centroid"]
			var key := Vector2i(clampi(int(c.x) / cell, 0, cols - 1), clampi(int(c.y) / cell, 0, rows.size() - 1))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(id)
		for r in rows.size():
			counts.append(cols)

	var figures := {}
	var warnings := []
	for r in rows.size():
		for c in counts[r]:
			var ids: Array = cells.get(Vector2i(c, r), [])
			if ids.is_empty():
				warnings.append("empty cell %s %d" % [rows[r], c])
				continue
			var rect := _figure_rect(info, cells, clips, Vector2i(c, r))
			if rect.size.x > cell * 1.6:
				warnings.append("%s %d: %dpx wide, figures may be touching" % [rows[r], c, rect.size.x])
			var img := _extract(sheet, labels, ids, rect)
			figures[Vector2i(c, r)] = {"img": img, "m": _measure(img)}

	# The first sheet listed for a facing must include an idle row; later sheets reuse its scale.
	if not facing_scale.has(facing):
		var idle_row := rows.find("idle")
		if idle_row == -1:
			push_error("%s: first sheet for facing '%s' needs an idle row to set the scale" % [sheet_cfg["file"], facing])
			return counts
		var idle_heights := []
		for c in counts[idle_row]:
			if figures.has(Vector2i(c, idle_row)):
				idle_heights.append(figures[Vector2i(c, idle_row)]["m"]["bbox"].size.y)
		idle_heights.sort()
		facing_scale[facing] = float(cfg["target_height"]) / float(idle_heights[idle_heights.size() / 2])
	var scale: float = facing_scale[facing]

	# A name listed on several rows is one animation continuing across them.
	var start := []
	for r in rows.size():
		var n := 0
		for prev in r:
			if rows[prev] == rows[r]:
				n += counts[prev]
		start.append(n)

	var probe: String = cfg.get("emitter_probe", "")
	var heights := {}
	var emitters := []
	for key in figures:
		var fig: Dictionary = figures[key]
		var img: Image = fig["img"]
		var m: Dictionary = fig["m"]
		var anim: String = rows[key.y]
		var index: int = start[key.y] + key.x
		var width: int = int(wide.get(anim, frame))
		var scaled := img.duplicate()
		scaled.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		var feet: float = (m["bbox"].end.y) * scale
		var dst := Vector2i(roundi(width / 2.0 - m["hip_x"] * scale), roundi(feet_y - feet))
		if wide.has(anim):
			# Pin the back edge where the first (standing) frame has it.
			var first: Dictionary = figures[Vector2i(0, rows.find(anim))]["m"]
			var back_edge: float = width / 2.0 - (first["hip_x"] - first["bbox"].position.x) * scale
			dst.x = roundi(back_edge - m["bbox"].position.x * scale)
		var out := Image.create(width, frame, false, Image.FORMAT_RGBA8)
		out.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), dst)
		if scaled.get_used_rect().size.x + maxi(dst.x, 0) > width or dst.x < -2:
			warnings.append("%s %d: clipped at frame edge" % [anim, index])
		out.save_png(ProjectSettings.globalize_path(out_dir + "frames/%s_%s_%02d.png" % [anim, facing, index]))
		if not heights.has(anim):
			heights[anim] = []
		heights[anim].append(roundi(m["bbox"].size.y * scale))
		if anim == probe:
			# Emitter guess (mouth, hand...): front-most solid pixel in the top 12% of the body.
			var bb: Rect2i = m["bbox"]
			var best := Vector2(-1, 0)
			for y in range(bb.position.y, bb.position.y + int(bb.size.y * 0.12)):
				for x in range(bb.end.x - 1, bb.position.x, -1):
					if img.get_pixel(x, y).a > ALPHA_SOLID:
						if x > best.x:
							best = Vector2(x, y)
						break
			emitters.append([index, Vector2(dst) + best * scale - Vector2(width / 2.0, feet_y)])
	report[sheet_cfg["file"]] = {"scale": scale, "frames": str(counts), "heights": heights, "emitter_offsets_from_feet": str(emitters), "warnings": warnings, "regions": info.size()}
	return counts


## Returns the number of frames written.
func _build_vfx(vfx_name: String, sheet: Image) -> int:
	var vfx: Dictionary = cfg["vfx"]
	var vfx_scale := float(vfx["scale"])
	var expected := int(vfx["frames"])
	# Frames sit side by side; split on empty column gaps.
	var w := sheet.get_width()
	var h := sheet.get_height()
	var occupied := PackedByteArray()
	occupied.resize(w)
	for x in w:
		for y in range(0, h, 2):
			if sheet.get_pixel(x, y).a > ALPHA_KEEP:
				occupied[x] = 1
				break
	var spans := []
	var x0 := -1
	var gap := 0
	for x in w:
		if occupied[x] == 1:
			if x0 == -1:
				x0 = x
			gap = 0
		elif x0 != -1:
			gap += 1
			if gap > 20:
				spans.append([x0, x - gap])
				x0 = -1
	if x0 != -1:
		spans.append([x0, w - 1])
	# Overlapping frames merge into one span: cut the widest span at its emptiest column.
	var column_alpha := PackedFloat32Array()
	column_alpha.resize(w)
	for x in w:
		for y in range(0, h, 2):
			column_alpha[x] += sheet.get_pixel(x, y).a
	while spans.size() < expected:
		var widest := 0
		for i in spans.size():
			if spans[i][1] - spans[i][0] > spans[widest][1] - spans[widest][0]:
				widest = i
		var a: int = spans[widest][0]
		var b: int = spans[widest][1]
		var cut := a + (b - a) / 2
		for x in range(a + (b - a) / 4, b - (b - a) / 4):
			if column_alpha[x] < column_alpha[cut]:
				cut = x
		spans[widest] = [a, cut]
		spans.insert(widest + 1, [cut + 1, b])

	# Origin = leftmost solid column, mean solid y in the first 8 columns.
	var frames := []
	var max_right := 0.0; var max_up := 0.0; var max_down := 0.0
	for span in spans:
		var region := sheet.get_region(Rect2i(span[0], 0, span[1] - span[0] + 1, h))
		var tip_x := -1
		for x in region.get_width():
			for y in h:
				if region.get_pixel(x, y).a > ALPHA_SOLID:
					tip_x = x
					break
			if tip_x != -1:
				break
		var sum := 0.0; var n := 0
		for x in range(tip_x, mini(tip_x + 8, region.get_width())):
			for y in h:
				if region.get_pixel(x, y).a > ALPHA_SOLID:
					sum += y; n += 1
		var tip := Vector2(tip_x, sum / maxi(n, 1)) * vfx_scale
		region.resize(maxi(1, roundi(region.get_width() * vfx_scale)), maxi(1, roundi(h * vfx_scale)), Image.INTERPOLATE_LANCZOS)
		var used := region.get_used_rect()
		max_right = maxf(max_right, used.end.x - tip.x)
		max_up = maxf(max_up, tip.y - used.position.y)
		max_down = maxf(max_down, used.end.y - tip.y)
		frames.append([region, tip])

	var size := Vector2i(ceili(max_right) + VFX_PAD * 2, ceili(max_up + max_down) + VFX_PAD * 2)
	var origin := Vector2(VFX_PAD, VFX_PAD + ceili(max_up))
	for i in frames.size():
		var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var dst := Vector2i((origin - frames[i][1]).round())
		out.blit_rect(frames[i][0], Rect2i(Vector2i.ZERO, frames[i][0].get_size()), dst)
		out.save_png(ProjectSettings.globalize_path(out_dir + "vfx/%s_%02d.png" % [vfx_name, i]))
	# Set the AnimatedSprite2D to centered = false, offset = -origin.
	report["vfx_" + vfx_name] = {"frames": frames.size(), "frame_size": str(size), "origin": str(origin)}
	return frames.size()
