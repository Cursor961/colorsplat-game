class_name LevelIceTile
extends Area2D
## Slippery ice floor. While the player overlaps it, their friction drops sharply so they
## keep sliding. Tile several, or use one big tile for a whole ice arena. Self-contained.

const TEX := "res://assets/sprites/levels/ice_floor.png"   ## pixelart ice slab (chamfered corners, dark outline)
const TEX_FALLBACK := "res://assets/sprites/levels/icetile.svg"

@export var size: Vector2 = Vector2(480, 480)   ## slab size (the level tiles are squares)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2               # detect the player
	# Bake the ice into the FLOOR canvas (above the dark bg, under splats) — a plain child
	# sprite would sit either over the splats (hiding them) or behind the opaque floor.
	# The level loads in the SAME frame the host resizes the paint canvas (set_arena_size on
	# big levels), and that resize race can swallow this first bake — so also re-stamp once the
	# canvas has settled a few frames later.
	_stamp_floor()
	_restamp_when_settled()
	_build_shape()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _stamp_floor() -> void:
	var path := TEX if ResourceLoader.exists(TEX) else TEX_FALLBACK
	if not ResourceLoader.exists(path):
		return
	var fp := get_tree().get_first_node_in_group("floor_paint")
	if fp and fp.has_method("stamp_floor"):
		fp.stamp_floor(load(path), global_position, size)

## Re-stamp after the paint canvas resize (set_arena_size) has settled — the load-frame bake
## can be lost to the resize race, leaving the ice invisible on big levels.
func _restamp_when_settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self) and is_inside_tree():
		_stamp_floor()

func _on_enter(body: Node2D) -> void:
	if body.is_in_group("players") and body.has_method("enter_ice"):
		body.enter_ice()

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("players") and body.has_method("exit_ice"):
		body.exit_ice()

func _build_shape() -> void:
	# RECT collision matching the square slab art (slightly inside the dark outline),
	# so the slippery area is exactly where the ice looks to be.
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size * 0.92
	cs.shape = r
	add_child(cs)
