class_name LevelBreakableWall
extends StaticBody2D
## A wall that LOOKS solid (blocks player + monsters + bullets) but the player can shoot
## it down (`max_hits`). Destroying it opens a passage — put a secret (powerup) behind it.

const TEX := "res://assets/sprites/levels/breakablewall.svg"

@export var wall_size: Vector2 = Vector2(96, 96)
@export var max_hits: int = 4

var _hits: int = 0
var _dead: bool = false
var _sprite: Sprite2D

func _ready() -> void:
	z_index = 2
	add_to_group("walls")            # bullets treat it as a wall (hit) + it blocks
	collision_layer = 1 | 4 | 16     # player(1) + bullets(4) + monsters(16)
	collision_mask = 0
	_build_visual()
	_build_shape()

## Bullet strike — chips away; opens after `max_hits`.
func hit_by_bullet(_bullet: Node) -> void:
	if _dead:
		return
	_hits += 1
	if _sprite:
		var k := 1.0 - float(_hits) / float(max_hits) * 0.5
		_sprite.scale = _base_scale * k          # visibly crumble
		_sprite.modulate = Color(1.6, 1.4, 1.2)
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.14)
	if _hits >= max_hits:
		_destroy()

func _destroy() -> void:
	_dead = true
	var fp := get_tree().get_first_node_in_group("floor_paint")
	if fp and fp.has_method("add_splat"):
		fp.add_splat(global_position, Color(0.45, 0.32, 0.2), 2.0)
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw and "particles" in gw and gw.particles:
		gw.particles.spawn_death_particles(global_position, Color(0.5, 0.4, 0.3), 26)   # dust
	if gw and gw.has_method("_add_shake"):
		gw._add_shake(7.0)                       # punchy impact (respects the shake setting)
	_spawn_destruction()
	AudioManager.play_sfx("crate_break")
	queue_free()

## TOTAL DESTRUCTION burst: the wall breaks into a grid of TEXTURED chunks that blast outward
## in every direction (spinning, shrinking, fading), wrapped in a quick dust shockwave ring.
## Everything is parented to the LEVEL (get_parent), never `self` — the wall queue_frees this
## same frame, so debris must outlive it.
func _spawn_destruction() -> void:
	var host := get_parent()
	if host == null:
		return
	var tex: Texture2D = null
	if _sprite and _sprite.texture:
		tex = _sprite.texture
	elif ResourceLoader.exists(TEX):
		tex = load(TEX)
	var tsize: Vector2 = tex.get_size() if tex else Vector2(64.0, 64.0)

	# --- Dust shockwave ring: a faint disc that snaps outward and fades. ---
	var ring := Polygon2D.new()
	ring.color = Color(0.62, 0.5, 0.38, 0.5)
	var rpts := PackedVector2Array()
	var rr: float = maxf(wall_size.x, wall_size.y) * 0.5
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		rpts.append(Vector2(cos(a), sin(a)) * rr)
	ring.polygon = rpts
	ring.global_position = global_position
	ring.z_index = 3
	host.add_child(ring)
	var rtw := ring.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.32).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.32)
	rtw.chain().tween_callback(ring.queue_free)

	# --- Wall shards: slice the texture into a COLS×ROWS grid; every cell flies out from its
	# own spot in the wall, so the break reads as the actual wall coming apart. ---
	var cols := 4
	var rows := 4
	var cw: float = tsize.x / float(cols)
	var ch: float = tsize.y / float(rows)
	for gy in rows:
		for gx in cols:
			var piece := Sprite2D.new()
			if tex:
				piece.texture = tex
				piece.region_enabled = true
				piece.region_rect = Rect2(gx * cw, gy * ch, cw, ch)
				piece.scale = _base_scale       # same on-screen scale the intact wall used
			else:
				piece.modulate = Color(0.5, 0.4, 0.3)
			piece.self_modulate = Color(1.15, 1.05, 0.95)
			piece.z_index = 3
			# Start at this cell's real position inside the wall (offset from the centre).
			var off := Vector2(
				((gx + 0.5) / float(cols) - 0.5) * wall_size.x,
				((gy + 0.5) / float(rows) - 0.5) * wall_size.y)
			piece.global_position = global_position + off
			host.add_child(piece)
			# Fly AWAY from the centre (all directions) + jitter; centre cells pick a random one.
			var dir := off.normalized() if off.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
			dir = dir.rotated(randf_range(-0.3, 0.3))
			var dist := randf_range(110.0, 280.0)
			var life := randf_range(0.5, 0.8)
			var tw := piece.create_tween()
			tw.set_parallel(true)
			tw.tween_property(piece, "global_position", piece.global_position + dir * dist, life).set_ease(Tween.EASE_OUT)
			tw.tween_property(piece, "rotation", randf_range(-TAU, TAU), life)
			tw.tween_property(piece, "scale", piece.scale * 0.25, life).set_ease(Tween.EASE_IN)
			tw.tween_property(piece, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(piece.queue_free)

var _base_scale: Vector2 = Vector2.ONE

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	var t: Vector2 = _sprite.texture.get_size()
	_sprite.scale = Vector2(wall_size.x / t.x, wall_size.y / t.y)
	_base_scale = _sprite.scale
	add_child(_sprite)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = wall_size
	cs.shape = rect
	add_child(cs)
