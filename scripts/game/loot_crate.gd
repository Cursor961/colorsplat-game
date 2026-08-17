class_name LootCrate
extends Area2D
## Destructible loot crate — spawns on map, destroyed by bullets/lasers/grenades.
## Drops loot on destruction: 40% random item, 40% random powerup, 20% rare powerup.
## Shrinks with each hit as visual feedback. No despawn timer — stays until destroyed.

signal destroyed(crate: LootCrate)

const MAX_HP := 5.0              ## 5 normal bullet hits to destroy
const NORMAL_BULLET_DMG := 1.0   ## Regular bullet deals 1 HP
const FMJ_BULLET_DMG := 3.0      ## FMJ bullet deals 3 HP (2 shots to destroy)
const LASER_DMG := 5.0           ## Laser one-shots
const GRENADE_DMG := 5.0         ## Grenade one-shots

## Loot drop chances (must sum to 1.0)
const LOOT_ITEM_CHANCE := 0.40
const LOOT_POWERUP_CHANCE := 0.40
## Remaining 0.20 = rare powerup

enum LootType { ITEM, POWERUP, RARE_POWERUP }

var hp: float = MAX_HP
var _initial_scale: Vector2 = Vector2.ONE
var _sprite: Sprite2D
## -1 = random loot (default); else force a LootType (0=ITEM, 1=POWERUP, 2=RARE_POWERUP).
var forced_loot: int = -1

func _ready() -> void:
	z_index = 4  # Same layer as pickups
	add_to_group("lootcrates")
	collision_layer = 64   ## Layer 7: lootcrates (bullets mask this)
	collision_mask = 0     ## Crate doesn't detect anything itself

	# Create sprite
	_sprite = Sprite2D.new()
	var tex_path := "res://assets/sprites/lootcrate/crate.svg"
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
		# Scale to ~70px diameter
		var tex_size := _sprite.texture.get_size()
		var sf := 70.0 / maxf(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)

	# Collision shape for bullet detection
	var shape := CircleShape2D.new()
	shape.radius = 35.0
	var shape_node := CollisionShape2D.new()
	shape_node.shape = shape
	add_child(shape_node)

	# Store initial scale for shrink effect
	_initial_scale = Vector2.ONE

	# Spawn animation: scale 0 -> 1
	var target_scale := scale
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", target_scale, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Take damage from a bullet, laser, or grenade. Returns true if crate was destroyed.
func take_hit(damage: float) -> bool:
	if hp <= 0:
		return false
	hp -= damage
	# Hit thunk while it survives (a destroying hit plays the break sound in _break instead).
	if hp > 0.0:
		AudioManager.play_sfx_at("lootcratehit", global_position.x)
	# Shrink proportionally to remaining HP
	var hp_ratio := clampf(hp / MAX_HP, 0.0, 1.0)
	var shrink_scale := lerpf(0.5, 1.0, hp_ratio)  # Scale from 100% to 50% as HP drops
	var target := _initial_scale * shrink_scale
	var tw := create_tween()
	# Quick "hit" bounce: scale down slightly then to target
	tw.tween_property(self, "scale", target * 0.85, 0.05)
	tw.tween_property(self, "scale", target, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Hit flash on sprite
	if _sprite:
		var ftw := create_tween()
		ftw.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0), 0.0)  # Bright flash
		ftw.tween_interval(0.06)
		ftw.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

	if hp <= 0:
		_break()
		return true
	return false

## Roll loot type when destroyed (or return the forced type if one was set at spawn).
func get_loot_type() -> LootType:
	if forced_loot >= 0:
		return forced_loot as LootType
	var roll := randf()
	if roll < LOOT_ITEM_CHANCE:
		return LootType.ITEM
	elif roll < LOOT_ITEM_CHANCE + LOOT_POWERUP_CHANCE:
		return LootType.POWERUP
	else:
		return LootType.RARE_POWERUP

func _break() -> void:
	AudioManager.play_sfx_at("lootcratedestroy", global_position.x)
	destroyed.emit(self)
	# Break animation: quick scale + fade
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.3, 0.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
