class_name LevelButton
extends Area2D
## Floor button / pressure plate. When the player steps on it, it opens every LevelGate
## sharing the same `gate_id` (a remote locked door / bridge). One-shot (stays pressed).

const TEX_UP := "res://assets/sprites/levels/plate_up.svg"
const TEX_DOWN := "res://assets/sprites/levels/plate_down.svg"

@export var gate_id: String = "1"
@export var size: float = 84.0
## RANDOM PICK: buttons sharing a non-empty group register together on level load; ONE
## random member survives, the rest free themselves. Lets a level hide its button in a
## different room every run (L26). The pool is static — cleared when the pick resolves.
@export var random_pick_group: String = ""
static var _pick_pools: Dictionary = {}   ## group -> Array[LevelButton]

var _pressed: bool = false
var _sprite: Sprite2D

func _ready() -> void:
	z_index = 1
	collision_layer = 0
	collision_mask = 2          # detect the player
	_build_ring()               # dark halo behind the plate so it pops on the busy floor
	_build_visual(TEX_UP)
	_build_shape()
	body_entered.connect(_on_body)
	if random_pick_group != "":
		var pool: Array = _pick_pools.get_or_add(random_pick_group, [])
		pool.append(self)
		if pool.size() == 1:
			_resolve_pick.call_deferred(random_pick_group)   # after all siblings registered

## One frame after load: keep one random registered button, free the rest.
func _resolve_pick(group: String) -> void:
	await get_tree().process_frame
	var pool: Array = _pick_pools.get(group, [])
	_pick_pools.erase(group)
	var alive: Array = pool.filter(func(b): return is_instance_valid(b))
	if alive.is_empty():
		return
	var keep: LevelButton = alive.pick_random()
	for b: LevelButton in alive:
		if b != keep:
			b.queue_free()

## Dark circular backing drawn UNDER the plate (added before the sprite) to highlight it.
func _build_ring() -> void:
	var ring := Polygon2D.new()
	ring.color = Color(0.03, 0.03, 0.05, 0.62)
	var pts := PackedVector2Array()
	var rr: float = size * 0.74
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(Vector2(cos(a), sin(a)) * rr)
	ring.polygon = pts
	add_child(ring)

func _on_body(body: Node2D) -> void:
	if _pressed or not body.is_in_group("players"):
		return
	_pressed = true
	if _sprite and ResourceLoader.exists(TEX_DOWN):
		_sprite.texture = load(TEX_DOWN)
	for g in get_tree().get_nodes_in_group("gate_" + gate_id):
		if g.has_method("open"):
			g.open()
	AudioManager.play_sfx("button_click")

func _build_visual(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	var t: Vector2 = _sprite.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size)
	cs.shape = rect
	add_child(cs)
