extends Node2D
## Isometric test bed for a character sprite pack (set `character` in the Inspector).
## One copy patrols a square (exercising all four facings, and y-sort as it
## passes the others); four more stand still, one per facing, cycling states.

const TILE := Vector2(128, 64)
const GRID := 14
const FACINGS := ["se", "sw", "ne", "nw"]
const WALK_SPEED := 70.0
const CYCLE_SECONDS := 2.2

## Any character scene with set_facing / set_facing_from_screen_vector / set_state.
@export var character: PackedScene = preload("res://art/zombies/twitcher/Twitcher.tscn")

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $HUD/Label

var walker: Node2D
var patrol: Array[Vector2] = []
var patrol_index := 0
var click_target = null  # Vector2 while walking to a clicked point
var showcase: Array[Node2D] = []
var states: Array = []
var state_index := 0
var auto_cycle := true
var cycle_timer := 0.0


func iso(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE.x * 0.5, (cell.x + cell.y) * TILE.y * 0.5)


func _ready() -> void:
	for cell in [Vector2(3, 3), Vector2(10, 3), Vector2(10, 10), Vector2(3, 10)]:
		patrol.append(iso(cell))
	walker = character.instantiate()
	states = walker.get_script().get_script_constant_map().get("STATES", ["idle", "walk"])
	world.add_child(walker)
	if walker.has_method("has_state"):
		states = states.filter(func(s): return walker.has_state(s))
	walker.position = patrol[0]
	walker.set_state("walk")

	var cells := [Vector2(4, 10), Vector2(6, 8), Vector2(8, 6), Vector2(10, 4)]
	for i in FACINGS.size():
		var h: Node2D = character.instantiate()
		h.position = iso(cells[i])
		world.add_child(h)
		h.set_facing(FACINGS[i])
		var tag := Label.new()
		tag.text = FACINGS[i].to_upper()
		tag.position = Vector2(-12, 8)
		h.add_child(tag)
		showcase.append(h)

	camera.position = iso(Vector2(GRID, GRID) * 0.5)
	_apply_state()


func _process(delta: float) -> void:
	_move_walker(delta)
	if auto_cycle:
		cycle_timer += delta
		if cycle_timer >= CYCLE_SECONDS:
			cycle_timer = 0.0
			state_index = (state_index + 1) % states.size()
			_apply_state()
	_update_hud()


func _move_walker(delta: float) -> void:
	var target: Vector2 = click_target if click_target != null else patrol[patrol_index]
	var to_target := target - walker.position
	if to_target.length() <= WALK_SPEED * delta:
		walker.position = target
		if click_target != null:
			click_target = null
		else:
			patrol_index = (patrol_index + 1) % patrol.size()
		return
	walker.set_facing_from_screen_vector(to_target)
	walker.position += to_target.normalized() * WALK_SPEED * delta


func _apply_state() -> void:
	for h in showcase:
		h.set_state("idle")  # set_state ignores repeats; reset so one-shots replay
		h.set_state(states[state_index])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 1-9 pick states 1-9, 0 picks the tenth.
		var pick: int = 9 if event.keycode == KEY_0 else event.keycode - KEY_1
		if event.keycode >= KEY_0 and event.keycode <= KEY_9 and pick < states.size():
			auto_cycle = false
			state_index = pick
			_apply_state()
		elif event.keycode == KEY_A:
			auto_cycle = not auto_cycle
			cycle_timer = 0.0
		elif event.keycode == KEY_R:
			_apply_state()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				click_target = get_global_mouse_position()
			MOUSE_BUTTON_WHEEL_UP:
				camera.zoom = (camera.zoom * 1.15).clamp(Vector2(0.4, 0.4), Vector2(4, 4))
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom = (camera.zoom / 1.15).clamp(Vector2(0.4, 0.4), Vector2(4, 4))


func _update_hud() -> void:
	hud.text = "Showcase state: %s  (%s)\nWalker facing: %s\n\n%s pick state   A toggle auto-cycle   R replay\nLeft-click move walker   Wheel zoom (%.2fx)" % [
		states[state_index].to_upper(),
		"auto" if auto_cycle else "manual",
		walker.facing.to_upper(),
		"1-9, 0" if states.size() > 9 else "1-%d" % states.size(),
		camera.zoom.x,
	]


func _draw() -> void:
	var half := TILE * 0.5
	for x in GRID:
		for y in GRID:
			var c := iso(Vector2(x, y))
			var diamond := PackedVector2Array([c + Vector2(0, -half.y), c + Vector2(half.x, 0), c + Vector2(0, half.y), c + Vector2(-half.x, 0)])
			var shade := Color(0.16, 0.17, 0.18) if (x + y) % 2 == 0 else Color(0.13, 0.14, 0.15)
			draw_colored_polygon(diamond, shade)
			diamond.append(diamond[0])
			draw_polyline(diamond, Color(0.22, 0.23, 0.25), 1.0)
