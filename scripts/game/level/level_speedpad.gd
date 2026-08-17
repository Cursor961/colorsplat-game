class_name LevelSpeedPad
extends Area2D
## A speed pad — flings the player in a fixed direction when stepped on. The launch
## briefly overrides movement input (see Player.launch), so it actually throws the
## player across the room. Set `launch_dir_deg` (0 = right, -90 = up) + `launch_speed`.

const TEX := "res://assets/sprites/levels/speedpad.svg"

@export var size: float = 100.0
@export var launch_dir_deg: float = -90.0   ## direction of the boost (0=right, -90=up)
@export var launch_speed: float = 1700.0
@export var launch_duration: float = 0.35   ## how long input is overridden by the boost
@export var cooldown: float = 0.4           ## min seconds between re-triggers

var _cooldown: float = 0.0

func _ready() -> void:
	z_index = 2                       # on the floor, under the player (z=5)
	collision_layer = 0
	collision_mask = 2               # detect the player
	_build_visual()
	_build_shape()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0 or not body.is_in_group("players"):
		return
	var p := body as Player
	if p == null or p.is_dead or not p.has_method("launch"):
		return
	var dir := Vector2.from_angle(deg_to_rad(launch_dir_deg))
	p.launch(dir * launch_speed, launch_duration)
	_cooldown = cooldown
	AudioManager.play_sfx("powerup_pickup")

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	var s := Sprite2D.new()
	s.texture = load(TEX)
	var t: Vector2 = s.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	s.scale = Vector2(sf, sf)
	# Point the pad art along the launch direction (art assumed to point up = -Y).
	s.rotation = deg_to_rad(launch_dir_deg + 90.0)
	add_child(s)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size * 0.5
	cs.shape = c
	add_child(cs)
