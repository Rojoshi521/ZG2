extends Node2D
## Regular (non-elite) zombie: body only, no effects. Only SE and NE are drawn;
## SW and NW are those mirrored. Same API as the elites: set_facing,
## set_facing_from_screen_vector, set_state, and action_finished.

signal action_finished(state: String)

const STATES := ["idle", "walk", "skitter", "detection", "crouch", "twitch", "attack", "hit", "recovery", "death"]
## Each zombie has only some of these (the Drifter has no detection, only the
## Twitcher has skitter, crouch and twitch); the missing ones are ignored.
## facing -> [drawn facing, mirrored]
const DRAWN := {"se": ["se", false], "sw": ["se", true], "ne": ["ne", false], "nw": ["ne", true]}

@onready var body: AnimatedSprite2D = $Body

var facing: String = "se"
var state: String = "idle"


func _ready() -> void:
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
	if not new_state in STATES or new_state == state or not has_state(new_state):
		return
	state = new_state
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


func has_state(state_name: String) -> bool:
	return body.sprite_frames.has_animation(state_name + "_se")
