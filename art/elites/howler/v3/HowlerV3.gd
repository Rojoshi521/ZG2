extends Node2D
## Howler, V3 art. Only SE and NE are drawn; SW and NW are those mirrored.
## Same API as HowlerIso (V2): set_facing, set_facing_from_screen_vector, set_state.

signal action_finished(state: String)

const STATES := ["idle", "walk", "detection", "scream", "attack", "hit", "recovery", "death"]
## facing -> [drawn facing, mirrored]
const DRAWN := {"se": ["se", false], "sw": ["se", true], "ne": ["ne", false], "nw": ["ne", true]}
## Mouth position relative to the feet, and blast angle, for each drawn facing.
const MOUTH := {"se": Vector2(35, -120), "ne": Vector2(27, -121)}
## The source blast already fans ~20 degrees upward, so these tilt it back down
## toward the facing's screen direction (SE is +26.6 degrees, NE is -26.6).
const BLAST_ANGLE := {"se": 50.0, "ne": -5.0}
const BLAST_SIZE := 0.6
const SCREAM_VFX_FRAME := 1  # body frame where the mouth is open

@onready var body: AnimatedSprite2D = $Body
@onready var scream_vfx: Node2D = $ScreamVFX
@onready var glow: AnimatedSprite2D = $ScreamVFX/Glow
@onready var shards: AnimatedSprite2D = $ScreamVFX/Shards

var facing: String = "se"
var state: String = "idle"


func _ready() -> void:
	scream_vfx.visible = false
	shards.animation_finished.connect(func() -> void: scream_vfx.visible = false)
	body.frame_changed.connect(_on_body_frame_changed)
	body.animation_finished.connect(func() -> void: action_finished.emit(state))
	_play_body()


func set_facing_from_screen_vector(motion: Vector2) -> void:
	if motion.length_squared() < 0.0001:
		return
	# Screen-space quadrants; Godot +Y is down.
	if motion.x >= 0.0:
		set_facing("se" if motion.y >= 0.0 else "ne")
	else:
		set_facing("sw" if motion.y >= 0.0 else "nw")


func set_facing(direction: String) -> void:
	if DRAWN.has(direction) and direction != facing:
		facing = direction
		_play_body()


func set_state(new_state: String) -> void:
	if not new_state in STATES or new_state == state:
		return
	state = new_state
	scream_vfx.visible = false
	_play_body()
	if state == "hit":
		body.modulate = Color(1.0, 0.45, 0.45)
		create_tween().tween_property(body, "modulate", Color.WHITE, 0.25)


func _play_body() -> void:
	var drawn: Array = DRAWN[facing]
	var anim_name := "%s_%s" % [state, drawn[0]]
	body.flip_h = drawn[1]
	if body.animation != anim_name or not body.is_playing():
		body.play(anim_name)


func _on_body_frame_changed() -> void:
	if state != "scream" or body.frame != SCREAM_VFX_FRAME:
		return
	var drawn: Array = DRAWN[facing]
	var side := -1.0 if drawn[1] else 1.0
	scream_vfx.position = MOUTH[drawn[0]] * Vector2(side, 1.0)
	scream_vfx.rotation = deg_to_rad(BLAST_ANGLE[drawn[0]]) * side
	scream_vfx.scale = Vector2(side, 1.0) * BLAST_SIZE
	scream_vfx.visible = true
	glow.play("scream_glow")
	shards.play("scream_shards")
