class_name LaserBeam
extends Node2D
## Instant laser beam — crosses entire map, kills everything in its path.
## Visual: thin beam sprite scaled to fill viewport in the aim direction.
## Default sprite direction is UP (Y-).
## Can be widened 3x by FMJ powerup.

signal monsters_hit(monsters: Array)  ## All monsters hit in one pass

const BASE_WIDTH := 90.0       ## Normal beam width (px) — 3x default
const FMJ_WIDTH_MULT := 3.0    ## Width multiplier when FMJ is active (= 270px)
const DAMAGE := 99999.0
const VISUAL_DURATION := 0.5   ## How long the beam visual stays on screen
const FLASH_DURATION := 0.1    ## Initial bright flash
const MUZZLE_OFFSET := 20.0    ## Beam starts this far in FRONT of the shooter (player edge)

var direction: Vector2 = Vector2.UP
var beam_width: float = BASE_WIDTH
var is_fmj: bool = false
var is_freeze: bool = false  ## Freeze Shot: beam deals NO damage, freezes monsters for life

var _sprite: Sprite2D
var _area: Area2D

func setup(pos: Vector2, dir: Vector2, fmj: bool = false) -> void:
	global_position = pos
	direction = dir.normalized()
	is_fmj = fmj
	if is_fmj:
		beam_width = BASE_WIDTH * FMJ_WIDTH_MULT

func _ready() -> void:
	z_index = 8  # Above everything
	_create_visual()
	_do_damage_pass()
	_animate_fadeout()

func _create_visual() -> void:
	_sprite = Sprite2D.new()
	var tex_path := "res://assets/sprites/items/laser_bullet.svg"
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	else:
		# Fallback: white rectangle texture
		var img := Image.create(4, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_sprite.texture = ImageTexture.create_from_image(img)

	# The sprite's default direction is UP. We need to extend it across
	# the entire viewport and rotate to match direction.
	var vp_size := get_viewport().get_visible_rect().size
	var beam_length := maxf(vp_size.x, vp_size.y) * 2.0  # Ensure covers entire screen

	var tex_size := _sprite.texture.get_size()
	# Scale X = beam_width / tex_width, Scale Y = beam_length / tex_height
	var sx := beam_width / tex_size.x
	var sy := beam_length / tex_size.y
	_sprite.scale = Vector2(sx, sy)

	# Rotate sprite so it points in the direction (sprite faces UP = -Y)
	_sprite.rotation = direction.angle() + PI / 2.0

	# The beam STARTS just in front of the player (at the sprite's edge) and extends
	# forward only — never behind or over the shooter.
	_sprite.position = direction * (beam_length / 2.0 + MUZZLE_OFFSET)

	add_child(_sprite)

func _do_damage_pass() -> void:
	# Use a raycast/area approach — check all monsters and see if they intersect the beam line
	var vp_size := get_viewport().get_visible_rect().size
	var beam_length := maxf(vp_size.x, vp_size.y) * 2.0
	var half_width := beam_width / 2.0

	# Build a perpendicular vector for width checking
	var perp := Vector2(-direction.y, direction.x)

	var hit_monsters: Array = []

	for m: Node in get_tree().get_nodes_in_group("monsters"):
		if not m is Monster:
			continue
		var monster := m as Monster
		if monster.is_spawning or monster.hp <= 0:
			continue

		# Project monster position onto beam axis
		var to_monster := monster.global_position - global_position
		var along := to_monster.dot(direction)
		var across := absf(to_monster.dot(perp))

		# Monster must be AHEAD of the player (the beam never reaches behind) and within
		# beam width + monster radius
		if along > 0.0 and along < beam_length and across <= half_width + monster.radius:
			hit_monsters.append(monster)
			# Freeze + Laser: no damage, freeze the monster SOLID for its whole life. The boss
			# is a separate "boss" node (handled below), so it's naturally excluded.
			if is_freeze:
				monster.apply_freeze(Monster.FREEZE_PERMANENT, 0.0)
			else:
				monster.take_damage(DAMAGE)

	# The beam also destroys any monster spawner it crosses.
	for sp: Node in get_tree().get_nodes_in_group("spawners"):
		if not (sp is Node2D and sp.has_method("blast_destroy")):
			continue
		var to_sp: Vector2 = (sp as Node2D).global_position - global_position
		var s_along := to_sp.dot(direction)
		var s_across := absf(to_sp.dot(perp))
		if s_along > 0.0 and s_along < beam_length and s_across <= half_width + 45.0:
			sp.blast_destroy()

	# … and any TURRET in its path (same treatment as spawners).
	for tr: Node in get_tree().get_nodes_in_group("turrets"):
		if not (tr is Node2D and tr.has_method("blast_destroy")):
			continue
		var to_tr: Vector2 = (tr as Node2D).global_position - global_position
		var t_along := to_tr.dot(direction)
		var t_across := absf(to_tr.dot(perp))
		if t_along > 0.0 and t_along < beam_length and t_across <= half_width + 45.0:
			tr.blast_destroy()

	# The FINAL BOSS is only hurt by lasers — the player's beam deals 15% of its max HP.
	for bz: Node in get_tree().get_nodes_in_group("boss"):
		if not (bz is Node2D and bz.has_method("player_laser_hit")):
			continue
		var brad: float = float(bz.get("size")) * 0.5
		var to_b: Vector2 = (bz as Node2D).global_position - global_position
		var b_along := to_b.dot(direction)
		var b_across := absf(to_b.dot(perp))
		if b_along > 0.0 and b_along < beam_length and b_across <= half_width + brad:
			bz.player_laser_hit(1.5 if is_fmj else 1.0)   # FMJ boosts boss damage 1.5x

	monsters_hit.emit(hit_monsters)

func _animate_fadeout() -> void:
	# Flash bright, then fade out. Freeze beam is icy blue instead of plain white.
	var base := Color(0.5, 0.8, 1.0, 1.0) if is_freeze else Color(1.0, 1.0, 1.0, 1.0)
	var flash := Color(1.6, 2.0, 2.4, 1.0) if is_freeze else Color(2.0, 2.0, 2.0, 1.0)
	if _sprite:
		_sprite.modulate = flash
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", base, FLASH_DURATION)
	tw.tween_property(_sprite, "modulate:a", 0.0, VISUAL_DURATION - FLASH_DURATION).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
