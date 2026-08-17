class_name LevelMetin
extends StaticBody2D
## "Metin stone" — a high-HP stationary totem. It's solid (blocks player + monsters) and
## ONLY spits enemies when it takes damage (never on its own). Spawned monsters grow in
## with a scale/fade-in. When destroyed it drops `drop_count` loot rolls (40% item / 40%
## powerup / 20% rare) and reports to the LevelManager (target_destroyed) for scoring.
## Used both in the "Totem" challenge and (random colour) as an endless-mode loot piñata.

const TEX_BY_COLOR := {
	"blue": "res://assets/sprites/levels/metinstone_blue.svg",
	"green": "res://assets/sprites/levels/metinstone_green.svg",
	"red": "res://assets/sprites/levels/metinstone_red.svg",
}
## Equal-chance monster pool for `random_type` (every type, BASIC..TANKBOMBER).
const RANDOM_POOL := [0, 1, 2, 3, 4, 5, 6, 7, 8]   ## BASIC..GHOST + TANKBOMBER (8)
const SPAWN_FREEZE := 0.5     ## scale/fade-in spawn duration of monsters it spits

@export_enum("blue", "green", "red") var color: String = "red"
@export var size: float = 160.0
@export var max_hp: float = 1000.0
@export var spawn_type: MonsterTypes.Type = MonsterTypes.Type.BASIC
@export var random_type: bool = false        ## pick a random monster each burst (equal chance)
@export var spawn_count: int = 3             ## monsters per damage-triggered burst
@export var spawn_per_damage: float = 350.0  ## spit a burst each time this much damage lands
@export var drop_count: int = 1              ## loot rolls dropped when destroyed
## If set ("blue"/"green"/"red"), destroying the totem also drops a KEY of that colour — make
## it guard the key needed to open the exit (a Doom-style "kill the boss for the key").
@export var drop_key_color: String = ""
## When false the metin does NOT count toward goal_clear_targets (boss-raised healing metins).
@export var count_as_target: bool = true

var _hp: float
var _dmg_accum: float = 0.0
var _dead: bool = false
var _last_hit_sfx: float = -1.0   ## throttle the metin-hit sfx under rapid fire
var _sprite: Sprite2D
var _shape: CollisionShape2D

func _ready() -> void:
	z_index = 6
	add_to_group("metins")
	collision_layer = 1 | 4 | 16     # solid to player (1) + monsters (bit 16); 4 = bullet hits
	collision_mask = 0
	_hp = max_hp
	_build_visual()
	_build_shape()
	var lm := get_tree().get_first_node_in_group("level_manager")
	if count_as_target and lm and lm.has_method("register_target"):
		lm.register_target()
	# Spawn pop: grow the VISUAL from nothing. Never scale the StaticBody2D root —
	# bodies colliding with a scaled shape can solve NaN positions ("Vector2 cannot
	# be normalized" console spam). Collision switches on once the pop lands.
	if _shape:
		_shape.disabled = true
	if _sprite:
		var full_scale := _sprite.scale
		_sprite.scale = full_scale * 0.05
		var stw := create_tween()
		stw.tween_property(_sprite, "scale", full_scale, 0.35) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stw.tween_callback(_enable_shape)
	else:
		_enable_shape()

## Bullet strike (generic level-object hook). Damages the totem + spits bursts.
func hit_by_bullet(bullet: Node) -> void:
	if _dead:
		return
	var dmg := 100.0
	if bullet and "damage" in bullet:
		dmg = float(bullet.damage)
	_hp -= dmg
	_dmg_accum += dmg
	_flash()
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_hit_sfx >= 0.08:   # avoid machine-gun spam on rapid fire
		_last_hit_sfx = now
		AudioManager.play_sfx_at("metinhit", global_position.x)
	while _dmg_accum >= spawn_per_damage:
		_dmg_accum -= spawn_per_damage
		_spawn_burst()
	if _hp <= 0.0:
		_destroy()

## Spawn `spawn_count` monsters in a ring just outside the totem (scaling in).
func _spawn_burst() -> void:
	if _dead:
		return
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw == null or not gw.has_method("level_spawn_monster"):
		return
	var ring := size * 0.6 + 70.0
	var base := randf() * TAU
	for i in maxi(spawn_count, 1):
		var ang := base + i * (TAU / float(maxi(spawn_count, 1)))
		var pos := global_position + Vector2.from_angle(ang) * ring
		var t: int = int(spawn_type)
		if random_type:
			t = int(RANDOM_POOL.pick_random())
		gw.call_deferred("level_spawn_monster", t, pos, 1, 20.0, SPAWN_FREEZE)  # deferred: we're inside a bullet-hit flush

func _destroy() -> void:
	if _dead:
		return
	_dead = true
	var lm := get_tree().get_first_node_in_group("level_manager")
	if count_as_target and lm and lm.has_method("target_destroyed"):
		lm.target_destroyed()
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw and gw.has_method("drop_metin_loot"):
		gw.drop_metin_loot(global_position, drop_count)
	if drop_key_color != "" and gw:
		var key := LevelKey.new()
		key.color = drop_key_color
		key.key_id = drop_key_color
		key.position = global_position       # drop AT the metin (always reachable — the player is right here)
		# Tag it so a level reset / restart wipes leftover dropped keys (authored keys live in
		# the level layout and re-spawn on their own; these dropped ones have no spawn point,
		# so without this they'd linger into the next life / next level).
		key.add_to_group("dropped_keys")
		gw.call_deferred("add_child", key)   # deferred: we're inside the bullet-hit flush
	if gw and "particles" in gw and gw.particles:
		gw.particles.spawn_death_particles(global_position, Color(0.8, 0.5, 0.3), 30)   # dust
	if gw and gw.has_method("_add_shake"):
		gw._add_shake(9.0)                       # chunky impact (respects the shake setting)
	_spawn_destruction()
	AudioManager.play_sfx_at("metindestroy", global_position.x)
	queue_free()

## TOTAL DESTRUCTION burst (same epic effect as the breakable wall): the metin shatters into a
## 4×4 grid of TEXTURED stone chunks that blast outward in every direction (spinning, shrinking,
## fading), wrapped in a dust shockwave ring. Parented to the LEVEL (get_parent), never `self`
## (this node queue_frees the same frame), so the debris outlives it. Debris is pure visuals
## (no collision), so it's safe to add during the bullet-hit flush.
func _spawn_destruction() -> void:
	var host := get_parent()
	if host == null:
		return
	var tex: Texture2D = null
	if _sprite and _sprite.texture:
		tex = _sprite.texture
	else:
		var path: String = TEX_BY_COLOR.get(color, TEX_BY_COLOR["red"])
		if ResourceLoader.exists(path):
			tex = load(path)
	var tsize: Vector2 = tex.get_size() if tex else Vector2(64.0, 64.0)
	var base_scale: Vector2 = _sprite.scale if _sprite else Vector2(size / tsize.x, size / tsize.y)

	# --- Dust shockwave ring: an earthy disc that snaps outward and fades. ---
	var ring := Polygon2D.new()
	ring.color = Color(0.6, 0.42, 0.3, 0.5)
	var rpts := PackedVector2Array()
	var rr: float = size * 0.5
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		rpts.append(Vector2(cos(a), sin(a)) * rr)
	ring.polygon = rpts
	ring.global_position = global_position
	ring.z_index = 7
	host.add_child(ring)
	var rtw := ring.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.34).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.34)
	rtw.chain().tween_callback(ring.queue_free)

	# --- Stone shards: slice the texture into a 4×4 grid; every cell flies out from its own
	# spot in the totem, so the break reads as the actual stone coming apart. ---
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
				piece.scale = base_scale       # same on-screen scale the intact metin used
			else:
				piece.modulate = Color(0.6, 0.42, 0.3)
			piece.self_modulate = Color(1.15, 1.05, 0.95)
			piece.z_index = 7
			# Start at this cell's real position inside the metin (offset from the centre).
			var off := Vector2(
				((gx + 0.5) / float(cols) - 0.5) * size,
				((gy + 0.5) / float(rows) - 0.5) * size)
			piece.global_position = global_position + off
			host.add_child(piece)
			# Fly AWAY from the centre (all directions) + jitter; centre cells pick a random one.
			var dir := off.normalized() if off.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
			dir = dir.rotated(randf_range(-0.3, 0.3))
			var dist := randf_range(140.0, 340.0)
			var life := randf_range(0.55, 0.85)
			var tw := piece.create_tween()
			tw.set_parallel(true)
			tw.tween_property(piece, "global_position", piece.global_position + dir * dist, life).set_ease(Tween.EASE_OUT)
			tw.tween_property(piece, "rotation", randf_range(-TAU, TAU), life)
			tw.tween_property(piece, "scale", piece.scale * 0.25, life).set_ease(Tween.EASE_IN)
			tw.tween_property(piece, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(piece.queue_free)

func _flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(2.0, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.16)

func _build_visual() -> void:
	var path: String = TEX_BY_COLOR.get(color, TEX_BY_COLOR["red"])
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
	var c := CircleShape2D.new()
	c.radius = size * 0.42
	cs.shape = c
	add_child(cs)
	_shape = cs

## Collision pops in with the stone (deferred — never toggle shapes mid-physics-flush).
func _enable_shape() -> void:
	if _shape:
		_shape.set_deferred("disabled", false)
