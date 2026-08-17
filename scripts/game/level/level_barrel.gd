class_name LevelBarrel
extends StaticBody2D
## Explosive barrel — solid (blocks player + monsters), takes `hits_to_explode` bullet
## hits, then detonates with a grenade-style blast (kills nearby monsters, hurts the
## player if close, and chain-detonates other barrels in range). Bullets reach it via
## Bullet's generic `hit_by_bullet` hook; explosions reach it via the "barrels" group.

const TEX := "res://assets/sprites/levels/explosionbarel.svg"

@export var size: float = 84.0
@export var hits_to_explode: int = 2
@export var explosion_radius_mult: float = 1.0

var _hits: int = 0
var _exploded: bool = false
var _sprite: Sprite2D

func _ready() -> void:
	z_index = 4
	add_to_group("barrels")
	collision_layer = 1 | 4 | 16     # solid to player (1) + monsters (bit 16); 4 = bullet hits
	collision_mask = 0
	_build_visual()
	_build_shape()

## Called by Bullet when one strikes the barrel (generic level-object hook).
func hit_by_bullet(_bullet: Node) -> void:
	if _exploded:
		return
	_hits += 1
	_flash()
	if _hits >= hits_to_explode:
		_explode()

## Caught in another explosion's blast (called via the "barrels" group, deferred).
func chain_explode() -> void:
	if not _exploded:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw and gw.has_method("explode_at"):
		gw.explode_at(global_position, explosion_radius_mult)
	queue_free()

func _flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(2.2, 1.2, 0.6)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)

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
