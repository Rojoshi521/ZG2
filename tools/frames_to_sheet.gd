extends SceneTree
## Turns a pack of pre-cut frames (frames/<facing>/<anim>_NN.png, one figure per
## 256 px canvas) into one "rows" sheet for build_sprite_pack.gd: one row per
## animation, frames in name order. Also strips leftover chart border lines
## (runs of 30+ px that are at most 3 px thick).
## Run: godot --headless --path . --script res://tools/frames_to_sheet.gd -- <frames dir> <out.png> idle walk ...

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var anims := a.slice(2)
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	var out := Image.create(256 * 9, 256 * anims.size(), false, Image.FORMAT_RGBA8)
	var removed := 0
	for r in anims.size():
		var c := 0
		for n in names:
			if n.begins_with(anims[r] + "_") and n.ends_with(".png"):
				var f := Image.load_from_file(dir + "/" + n); f.convert(Image.FORMAT_RGBA8)
				removed += _strip_lines(f)
				out.blit_rect(f, Rect2i(0, 0, 256, 256), Vector2i(c * 256, r * 256))
				c += 1
	out.save_png(a[1])
	print("removed line pixels: ", removed)
	quit()

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
