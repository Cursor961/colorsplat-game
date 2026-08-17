class_name Grenade
extends Area2D
## Grenade projectile — thrown with realistic deceleration (fast start, slows down).
## Explodes on monster contact, wall hit, or fuse expiry.
## One-shot kills all monsters in blast radius. Player takes 60% max HP if too close.

signal exploded(grenade: Grenade)

const FUSE_TIME := 4.0            ## Safety fuse if nothing is hit
const INITIAL_SPEED := 900.0      ## Fast throw start
const DRAG := 3.0                 ## Exponential drag — speed = INITIAL * e^(-DRAG * t)
const EXPLOSION_RADIUS := 150.0
const DAMAGE := 99999.0
const PLAYER_DAMAGE_PERCENT := 0.60

var direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
var _has_exploded: bool = false

## Combo flags — set by game_world before add_child
var is_fmj: bool = false     ## FMJ: red tint, 2x radius, no explode on monster contact
var is_cleaner: bool = false ## Cleaner: light blue, cleaner decals on explosion
var is_freeze: bool = false  ## Freeze Shot: blast deals NO damage, freezes monsters for life

func _ready() -> void:
	z_index = 5
	# Apply visual tint based on combo (freeze wins the tint — it's the icy one).
	if is_freeze:
		modulate = Color(0.4, 0.75, 1.0)  # Icy blue tint
	elif is_fmj:
		modulate = Color(1.0, 0.3, 0.3)  # Red tint
	elif is_cleaner:
		modulate = Color(0.4, 0.8, 1.0)  # Light blue tint

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return
	_elapsed += delta
	# Exponential deceleration — fast throw that slows to a crawl
	var speed := INITIAL_SPEED * exp(-DRAG * _elapsed)
	global_position += direction * speed * delta
	# Spin sprite — slows down with the grenade
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.rotation += delta * 8.0 * (speed / INITIAL_SPEED)
	# Fuse countdown (safety fallback)
	if _elapsed >= FUSE_TIME:
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if _has_exploded:
		return
	if body.is_in_group("walls"):
		_explode()
	elif body is Monster:
		# FMJ grenades don't explode on monster contact — only fuse/wall
		if not is_fmj:
			_explode()

func setup(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direction = dir.normalized()
	# Scale sprite to ~40px diameter
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		var tex_size := sprite.texture.get_size()
		var sf := 40.0 / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(sf, sf)

func _explode() -> void:
	_has_exploded = true
	exploded.emit(self)
	queue_free()
