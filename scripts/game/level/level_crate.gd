class_name LevelCrate
extends RigidBody2D
## A pushable crate for logic puzzles. The player shoves it by walking into it, and
## bullets knock it back. It slides and settles (linear damp), stops at walls, and
## doesn't rotate. Self-contained — drop into a level scene and set `size`.

const TEX := "res://assets/sprites/levels/crate_movable.svg"

@export var size: float = 84.0
@export var push_force: float = 2600.0     ## force applied while the player pushes it
@export var bullet_impulse: float = 240.0  ## shove per bullet hit

func _ready() -> void:
	z_index = 4
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 6.0
	mass = 1.2
	contact_monitor = true
	max_contacts_reported = 6
	collision_layer = 1 | 4 | 16      # blocks player (1) + monsters (bit 16); 4 = bullet hits
	collision_mask = 1 | 16           # collides with walls / arena bounds / other solids
	_build_visual()
	_build_shape()

func _physics_process(_delta: float) -> void:
	# Shove the crate in the direction a touching player is moving.
	for b in get_colliding_bodies():
		if b and b.is_in_group("players"):
			var pv: Vector2 = b.velocity
			if pv.length() > 12.0:
				apply_central_force(pv.normalized() * push_force)

## Called by Bullet when one strikes the crate (generic level-object hook).
func hit_by_bullet(bullet: Node) -> void:
	var dir := Vector2.ZERO
	if bullet and "direction" in bullet:
		dir = bullet.direction
	if dir == Vector2.ZERO and bullet is Node2D:
		dir = (global_position - (bullet as Node2D).global_position).normalized()
	if dir != Vector2.ZERO:
		apply_central_impulse(dir * bullet_impulse)

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	var s := Sprite2D.new()
	s.texture = load(TEX)
	var t: Vector2 = s.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	s.scale = Vector2(sf, sf)
	add_child(s)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size) * 0.86
	cs.shape = rect
	add_child(cs)
