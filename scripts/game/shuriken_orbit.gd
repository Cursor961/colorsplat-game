class_name ShurikenOrbit
extends Node2D
## Spinning shuriken — orbits the player continuously for 30s.
## Circular spinning object that damages monsters on contact.
## Rotates like powerup glow (self-spin) while also orbiting the player.

signal monster_hit(monster: Monster)

const ORBIT_RADIUS := 80.0
const ORBIT_SPEED := TAU / 2.0     ## 1 full orbit per 2 seconds
const SELF_SPIN_SPEED := TAU / 0.5  ## Self-rotation: 2 full spins per second
const SHURIKEN_DAMAGE := 99999.0
const SHURIKEN_SIZE := 50.0         ## Diameter in pixels

var _elapsed: float = 0.0
var _orbit_angle: float = 0.0
var _area: Area2D
var _sprite: Sprite2D
var _player: Node2D
var _hit_cooldowns: Dictionary = {}  ## monster instance_id -> cooldown timer
const HIT_COOLDOWN := 0.5            ## Can re-hit same monster after 0.5s

func _ready() -> void:
	z_index = 7  # Above monsters (z=6), same as katana

	# Build collision area
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4  # Monsters (CharacterBody2D on layer 4)
	_area.monitoring = true
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)

	# Collision shape at orbit offset
	var shape := CircleShape2D.new()
	shape.radius = SHURIKEN_SIZE / 2.0
	var shape_node := CollisionShape2D.new()
	shape_node.shape = shape
	shape_node.position = Vector2(ORBIT_RADIUS, 0)
	_area.add_child(shape_node)

	# Shuriken sprite at orbit offset
	var tex_path := "res://assets/sprites/powerups/shuriken_item.svg"
	if ResourceLoader.exists(tex_path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(tex_path)
		_sprite.position = Vector2(ORBIT_RADIUS, 0)
		var tex_size := _sprite.texture.get_size()
		var sf := SHURIKEN_SIZE / maxf(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(sf, sf)
		_area.add_child(_sprite)

func setup(player_ref: Node2D, start_angle: float = 0.0) -> void:
	_player = player_ref
	_orbit_angle = start_angle

func _physics_process(delta: float) -> void:
	_elapsed += delta

	# Follow player position
	if _player and is_instance_valid(_player):
		global_position = _player.global_position

	# Orbit rotation
	_orbit_angle += ORBIT_SPEED * delta
	_area.rotation = _orbit_angle

	# Self-spin of the shuriken sprite (independent of orbit)
	if _sprite:
		_sprite.rotation += SELF_SPIN_SPEED * delta

	# Update hit cooldowns
	var expired: Array = []
	for id: int in _hit_cooldowns:
		_hit_cooldowns[id] -= delta
		if _hit_cooldowns[id] <= 0.0:
			expired.append(id)
	for id: int in expired:
		_hit_cooldowns.erase(id)

func _on_body_entered(body: Node2D) -> void:
	if body is Monster:
		var monster := body as Monster
		var id := monster.get_instance_id()
		if _hit_cooldowns.has(id):
			return  # On cooldown
		if monster.is_spawning or monster.hp <= 0:
			return
		_hit_cooldowns[id] = HIT_COOLDOWN
		monster_hit.emit(monster)

## Clean removal with fade.
func remove() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
