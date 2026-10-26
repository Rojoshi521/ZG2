extends Node2D
## Godot 4: four isometric diagonal facings and separate scream effect.
@onready var body: AnimatedSprite2D = $Body
@onready var scream_vfx: AnimatedSprite2D = $ScreamVFX

var facing: String = "se"
var state: String = "idle"

func _ready() -> void:
    scream_vfx.visible = false
    scream_vfx.animation_finished.connect(func() -> void: scream_vfx.visible = false)
    _play_body()

func set_facing_from_screen_vector(motion: Vector2) -> void:
    if motion.length_squared() < 0.0001:
        return
    var angle := rad_to_deg(motion.angle())
    # Screen-space compass; Godot positive Y is down.
    if angle >= 0.0 and angle < 90.0:
        facing = "se"
    elif angle >= 90.0 and angle <= 180.0:
        facing = "sw"
    elif angle < 0.0 and angle >= -90.0:
        facing = "ne"
    else:
        facing = "nw"
    _play_body()

func set_facing(direction: String) -> void:
    if direction in ["se", "sw", "ne", "nw"]:
        facing = direction
        _play_body()

func set_state(new_state: String) -> void:
    if not new_state in ["idle", "walk", "detection", "scream", "attack", "hit", "recovery", "death"]:
        return
    if state == new_state:
        return
    state = new_state
    _play_body()
    if state == "scream":
        scream_vfx.visible = true
        scream_vfx.position = {"se": Vector2(30,-118), "sw": Vector2(-30,-118), "ne": Vector2(20,-125), "nw": Vector2(-20,-125)}[facing]
        scream_vfx.play("scream_" + facing)
    else:
        scream_vfx.stop()
        scream_vfx.visible = false

func _play_body() -> void:
    var anim_name := state + "_" + facing
    if body.sprite_frames != null and body.sprite_frames.has_animation(anim_name):
        if body.animation != anim_name or not body.is_playing():
            body.play(anim_name)
