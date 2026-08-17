class_name LevelSaw
extends Area2D
## A spinning saw blade — instantly kills the player on contact. Always spins; if
## `patrol_offset` is non-zero it also slides back and forth between its start position
## and start+offset (a moving hazard). Self-contained.

const TEX := "res://assets/sprites/levels/saw.svg"

@export var size: float = 120.0          ## visual + hitbox diameter (px)
@export var hit_fraction: float = 0.42
@export var spin_speed: float = 12.0     ## blade spin (rad/s)
## If non-zero, the saw patrols between its start and start+patrol_offset.
@export var patrol_offset: Vector2 = Vector2.ZERO
@export var move_speed: float = 160.0    ## patrol speed along the path (px/s)
## Screensaver mode: the saw flies in a straight line and bounces off the arena edges.
@export var fly: bool = false
@export var fly_speed: float = 360.0

var _sprite: Sprite2D
var _start: Vector2
var _t: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _arena: Vector2 = Vector2(1920, 1080)

func _ready() -> void:
	z_index = 7
	add_to_group("level_saws")       # near-miss haptics scan
	collision_layer = 0
	collision_mask = 2               # detect the player
	_start = position
	_build_visual()
	_build_shape()
	body_entered.connect(_on_body_entered)
	if fly:
		var gw := get_tree().get_first_node_in_group("game_world")
		if gw:
			_arena = Vector2(gw.arena_width, gw.arena_height)
		# Random launch direction biased away from the axes (so it actually crosses).
		var ang := randf_range(0.6, 0.9) * (PI / 2.0)
		ang += (PI / 2.0) * float(randi() % 4)
		_vel = Vector2.from_angle(ang) * fly_speed

func _physics_process(delta: float) -> void:
	if _sprite:
		_sprite.rotation += spin_speed * delta
	if fly:
		_fly_step(delta)
		return
	var len := patrol_offset.length()
	if len > 1.0 and move_speed > 0.0:
		_t += delta * move_speed / len            # _t counts "trips" along the offset
		var ph := fmod(_t, 2.0)
		var tri := ph if ph <= 1.0 else 2.0 - ph  # 0→1→0 triangle (ping-pong)
		position = _start + patrol_offset * tri

## Screensaver bounce: move + reflect off the arena bounds (kept inside by the radius).
func _fly_step(delta: float) -> void:
	position += _vel * delta
	var r := size * 0.5
	if position.x < r:
		position.x = r; _vel.x = absf(_vel.x)
	elif position.x > _arena.x - r:
		position.x = _arena.x - r; _vel.x = -absf(_vel.x)
	if position.y < r:
		position.y = r; _vel.y = absf(_vel.y)
	elif position.y > _arena.y - r:
		position.y = _arena.y - r; _vel.y = -absf(_vel.y)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	var p := body as Player
	if p and not p.is_dead:
		p.take_zone_damage(999999.0)   # death splat sfx comes from the death handler

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	var t: Vector2 = _sprite.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size * hit_fraction
	cs.shape = c
	add_child(cs)
