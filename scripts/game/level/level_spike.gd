class_name LevelSpike
extends Area2D
## Floor spikes — instantly kill the player on contact. Drop one into a level scene and
## set `size`; the sprite + hitbox are built in code. Self-contained (no LevelManager
## needed). The player is on physics layer 2, so we detect that.

const TEX := "res://assets/sprites/levels/spike.svg"

@export var size: float = 72.0           ## visual + hitbox diameter (px)
@export var hit_fraction: float = 0.40   ## hitbox radius as a fraction of `size`
## Direction the spike tips point (deg; 0=right, 90=down, -90=up, 180=left). The SVG
## triangle points up, so the sprite is rotated by (face_deg + 90). Used to mount spikes
## on a wall facing away from it.
@export var face_deg: float = -90.0

func _ready() -> void:
	z_index = 1
	collision_layer = 0
	collision_mask = 2               # detect the player (player body is on layer 2)
	_build_visual()
	_build_shape()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	var p := body as Player
	if p and not p.is_dead:
		# Bypasses brief i-frames; only the Invincibility powerup can save the player.
		p.take_zone_damage(999999.0)   # death splat sfx comes from the death handler

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	var s := Sprite2D.new()
	s.texture = load(TEX)
	var t: Vector2 = s.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	s.scale = Vector2(sf, sf)
	s.rotation = deg_to_rad(face_deg + 90.0)   # SVG points up by default
	add_child(s)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size * hit_fraction
	cs.shape = c
	add_child(cs)
