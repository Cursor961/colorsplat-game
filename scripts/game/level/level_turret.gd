class_name LevelTurret
extends StaticBody2D
## Auto-turret: rotates to face the player and fires small white bullets at a QUARTER of the
## player's fire rate (4x slower cadence). Bullets are ~2x smaller than the player's.
## Destructible — `max_hits` bullet hits and it's gone. Solid (blocks player + monsters).

const TEX := "res://assets/sprites/levels/turret.svg"

@export var size: float = 110.0
@export var max_hits: int = 5
@export var fire_interval: float = 1.2     ## overwritten in _ready to 4x the player's interval
@export var bullet_speed: float = 285.0     ## 25% slower than the old 380 (bigger, lazier shots)
@export var bullet_diameter: float = 40.0   ## 2× the old 20 (~the player's bullet size)
@export var fire_range: float = 1200.0     ## only fire when the player is within range

var _hits: int = 0
var _timer: float = 0.0
var _dead: bool = false
var _sprite: Sprite2D
var _gw: Node = null

func _ready() -> void:
	z_index = 6
	add_to_group("turrets")
	collision_layer = 1 | 4 | 16   # solid + bullet-detectable (bullets call hit_by_bullet)
	collision_mask = 0
	_gw = get_tree().get_first_node_in_group("game_world")
	_build_visual()
	_build_shape()
	var p := get_tree().get_first_node_in_group("players")
	if p and "fire_rate" in p and p.fire_rate > 0.0:
		fire_interval = (1.0 / p.fire_rate) * 4.0   # 4x slower cadence (halved again per balance pass)
	_timer = fire_interval * randf()

func _physics_process(delta: float) -> void:
	if _dead or GameManager.time_stopped:
		return
	var p := get_tree().get_first_node_in_group("players")
	if p == null or p.is_dead:
		return
	var to: Vector2 = p.global_position - global_position
	if _sprite:
		_sprite.rotation = to.angle() + PI / 2.0   # SVG points up
	if to.length() > fire_range:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = fire_interval
		_fire(to.normalized())

func _fire(dir: Vector2) -> void:
	if _gw and _gw.has_method("spawn_enemy_projectile"):
		# White ball with a black outline (outlined=true swaps in the ring texture).
		# Last arg: turret shots damage MONSTERS caught in their path too.
		_gw.spawn_enemy_projectile(global_position + dir * (size * 0.45), dir, bullet_speed, 50.0, bullet_diameter, Color.WHITE, true, true)
	AudioManager.play_sfx_at("bullet_fire", global_position.x, 0.5)

## Bullet strike — dies after `max_hits`.
func hit_by_bullet(_bullet: Node) -> void:
	if _dead:
		return
	_hits += 1
	_flash()
	if _hits >= max_hits:
		_destroy()

func _destroy() -> void:
	_dead = true
	var fp := get_tree().get_first_node_in_group("floor_paint")
	if fp and fp.has_method("add_splat"):
		fp.add_splat(global_position, Color(0.2, 0.2, 0.2), 2.5)
	# Explode like a grenade on death — kills nearby monsters + spawners, hurts the player.
	if _gw and _gw.has_method("explode_at"):
		_gw.explode_at(global_position, 1.0)
	elif _gw and "particles" in _gw and _gw.particles:
		_gw.particles.spawn_death_particles(global_position, Color(0.3, 0.3, 0.3), 20)
	queue_free()

## Destroyed by an external blast (grenade / barrel / exploding monster / decoy).
func blast_destroy() -> void:
	if _dead:
		return
	_destroy()

func _flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(2.0, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.16)

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
	c.radius = size * 0.42
	cs.shape = c
	add_child(cs)
