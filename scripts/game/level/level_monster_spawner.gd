class_name LevelMonsterSpawner
extends StaticBody2D
## A destructible monster spawner. Its texture spins constantly (saw-like), it spits a
## random monster every `spawn_interval` seconds, and the player can destroy it with
## `max_hits` bullets — on death it drops a red splat on the floor. Solid (blocks the
## player + monsters); bullets reach it via Bullet's generic `hit_by_bullet` hook.

const TEX := "res://assets/sprites/levels/monsterspawner_default.svg"
## Equal-chance monster pool (BASIC..GHOST; excludes TANKBOMBER).
const RANDOM_POOL := [0, 1, 2, 3, 4, 5, 6, 7, 8]   ## every type incl. TANKBOMBER (8)
const SPAWN_FREEZE := 0.5     ## scale/fade-in time of spawned monsters

@export var size: float = 112.0           ## 25% smaller than the old 150
@export var max_hits: int = 10            ## bullets to destroy it
@export var spawn_interval: float = 3.0   ## seconds between spawns
@export var spawn_count: int = 1          ## monsters per spawn
@export var max_spawns: int = 0           ## 0 = endless; else stop after N spawns (no respawn)
@export var spin_speed: float = 6.0       ## texture spin (rad/s)
@export var random_type: bool = true      ## random monster each spawn (equal chance)
@export var spawn_type: MonsterTypes.Type = MonsterTypes.Type.BASIC

const OFFSCREEN_MAX_SPAWNS := 3   ## if the player never sees it, it may spawn at most this many

var _hits: int = 0
var _timer: float = 0.0
var _spawns_done: int = 0
var _dead: bool = false
var _sprite: Sprite2D
var _seen_on_screen: bool = false   ## true once it has ever been on the player's screen

func _ready() -> void:
	z_index = 4
	add_to_group("spawners")
	collision_layer = 1 | 4 | 16     # solid to player (1) + monsters (bit 16); 4 = bullet hits
	collision_mask = 0
	_timer = spawn_interval
	_build_visual()
	_build_shape()
	# Track whether the player has ever seen it: off-screen spawners are capped, seen ones spawn
	# forever (even after the player wanders away).
	var notif := VisibleOnScreenNotifier2D.new()
	notif.rect = Rect2(-size * 0.5, -size * 0.5, size, size)
	notif.screen_entered.connect(func() -> void: _seen_on_screen = true)
	add_child(notif)
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm and lm.has_method("register_target"):
		lm.register_target()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _sprite:
		_sprite.rotation += spin_speed * delta   # constant spin (saw-like)
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		var within_hard_cap: bool = (max_spawns <= 0 or _spawns_done < max_spawns)
		# Off-screen (never seen) spawners stop after OFFSCREEN_MAX_SPAWNS; once seen, endless.
		var within_seen_cap: bool = (_seen_on_screen or _spawns_done < OFFSCREEN_MAX_SPAWNS)
		if within_hard_cap and within_seen_cap:
			_spawn()
			_spawns_done += 1

## Big AoE (player laser / barrel-grenade explosion) destroys it outright.
func blast_destroy() -> void:
	if not _dead:
		_destroy()

## Bullet strike (generic level-object hook): 1 hit each; dies after `max_hits`.
func hit_by_bullet(_bullet: Node) -> void:
	if _dead:
		return
	_hits += 1
	_flash()
	if _hits >= max_hits:
		_destroy()

## Spit `spawn_count` random monsters in a ring just outside the spawner (scaling in).
func _spawn() -> void:
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw == null or not gw.has_method("level_spawn_monster"):
		return
	var t: int = int(spawn_type)
	if random_type:
		t = int(RANDOM_POOL.pick_random())
	# Monsters appear IN THE CENTRE of the spawner (not in a ring beside it like the metin).
	gw.call_deferred("level_spawn_monster", t, global_position, maxi(spawn_count, 1), 24.0, SPAWN_FREEZE)  # deferred: bullet-hit flush

func _destroy() -> void:
	if _dead:
		return
	_dead = true
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm and lm.has_method("target_destroyed"):
		lm.target_destroyed()
	# Red splat on the ground where it stood.
	var fp := get_tree().get_first_node_in_group("floor_paint")
	if fp and fp.has_method("add_splat"):
		fp.add_splat(global_position, Color(0.9, 0.15, 0.15), 3.0)
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw and "particles" in gw and gw.particles:
		gw.particles.spawn_death_particles(global_position, Color(0.9, 0.2, 0.2), 30)   # dust
	if gw and gw.has_method("_add_shake"):
		gw._add_shake(8.0)                       # chunky impact (respects the shake setting)
	_spawn_destruction()
	AudioManager.play_sfx("spawnerdead", 3.0)   # 3x louder (the source wav is quiet)
	queue_free()

## TOTAL DESTRUCTION burst (same epic effect as the breakable wall + metin): the spawner
## shatters into a 4×4 grid of TEXTURED chunks that blast outward in every direction (spinning,
## shrinking, fading), wrapped in a dust shockwave ring. Parented to the LEVEL (get_parent),
## never `self` (this node queue_frees the same frame), so the debris outlives it. Debris is
## pure visuals (no collision), so it's safe to add during the bullet-hit flush.
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
	var base_scale: Vector2 = _sprite.scale if _sprite else Vector2(size / tsize.x, size / tsize.y)

	# --- Dust shockwave ring: a reddish disc that snaps outward and fades. ---
	var ring := Polygon2D.new()
	ring.color = Color(0.72, 0.32, 0.3, 0.5)
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

	# --- Shards: slice the texture into a 4×4 grid; every cell flies out from its own spot in
	# the spawner, so the break reads as the actual object coming apart. ---
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
				piece.scale = base_scale       # same on-screen scale the intact spawner used
			else:
				piece.modulate = Color(0.9, 0.2, 0.2)
			piece.self_modulate = Color(1.15, 1.05, 0.95)
			piece.z_index = 7
			# Start at this cell's real position inside the spawner (offset from the centre).
			var off := Vector2(
				((gx + 0.5) / float(cols) - 0.5) * size,
				((gy + 0.5) / float(rows) - 0.5) * size)
			piece.global_position = global_position + off
			host.add_child(piece)
			# Fly AWAY from the centre (all directions) + jitter; centre cells pick a random one.
			var dir := off.normalized() if off.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
			dir = dir.rotated(randf_range(-0.3, 0.3))
			var dist := randf_range(120.0, 300.0)
			var life := randf_range(0.5, 0.8)
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
