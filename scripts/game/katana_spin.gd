class_name KatanaSpin
extends Node2D
## Spinning katana blade — orbits the player clockwise, 3 rotations in 2.25s.
## One-shot kills any monster it touches.

signal monster_hit(monster: Monster)
signal finished

const ORBIT_RADIUS := 95.0
const ROTATION_SPEED := TAU / 0.75  ## 2x speed — 1 full rotation per 0.75s
const TOTAL_DURATION := 2.25        ## 3 rotations × 0.75s = 2.25s
const KATANA_DAMAGE := 99999.0

var _elapsed: float = 0.0
var _angle: float = 0.0
var _area: Area2D
var _player: Node2D
var _hit_ids: Dictionary = {}  ## Track already-hit monster instance IDs

func _ready() -> void:
	z_index = 7  # Above monsters (z=6)

	# Build collision area
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4  # Monsters (CharacterBody2D on layer 4)
	_area.monitoring = true
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)

	# Collision shape at orbit offset
	var shape := CircleShape2D.new()
	shape.radius = 67.0
	var shape_node := CollisionShape2D.new()
	shape_node.shape = shape
	shape_node.position = Vector2(ORBIT_RADIUS, 0)
	_area.add_child(shape_node)

	# Katana slash sprite at orbit offset
	# Texture has blade pointing UP — rotate PI/2 so blade faces outward (away from player)
	# Flip X scale so the cutting edge leads the clockwise spin
	var tex_path := "res://assets/sprites/items/katana_slash.svg"
	if ResourceLoader.exists(tex_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(tex_path)
		sprite.position = Vector2(ORBIT_RADIUS, 0)
		sprite.rotation = PI / 2.0  # Blade points outward, handle toward player
		var tex_size := sprite.texture.get_size()
		var sf := 157.0 / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(-sf, sf)  # Flip X — cutting edge faces clockwise direction
		_area.add_child(sprite)

func setup(player_ref: Node2D, start_angle: float = 0.0) -> void:
	_player = player_ref
	_angle = start_angle

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TOTAL_DURATION:
		finished.emit()
		queue_free()
		return

	# Follow player position
	if _player and is_instance_valid(_player):
		global_position = _player.global_position

	# Rotate the blade around the player
	_angle += ROTATION_SPEED * delta
	_area.rotation = _angle

	# The FINAL BOSS takes 10% from a katana swing (once per activation).
	for bz in get_tree().get_nodes_in_group("boss"):
		var bid: int = bz.get_instance_id()
		if _hit_ids.has(bid):
			continue
		if global_position.distance_to((bz as Node2D).global_position) < 300.0 + float(bz.get("size")) * 0.42:
			_hit_ids[bid] = true
			if bz.has_method("katana_hit"):
				bz.katana_hit()

func _on_body_entered(body: Node2D) -> void:
	if body is Monster:
		var monster := body as Monster
		var id := monster.get_instance_id()
		if _hit_ids.has(id):
			return  # Already hit this monster
		_hit_ids[id] = true
		monster_hit.emit(monster)
