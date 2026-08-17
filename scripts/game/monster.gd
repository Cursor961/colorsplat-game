class_name Monster
extends CharacterBody2D
## Monster AI - converted from Classes/Monster.as
## Supports all 8 types via MonsterTypes data.
## Steering, avoidance, type-specific behaviors (charge, heal, spawn, split, ghost, sine).

signal died(monster: Monster)
signal spawned_children(children: Array)  ## Splitter/Spawner
signal healed_pulse(healer: Monster, healed_monsters: Array)  ## Healer visual
signal fired_bullet(from_pos: Vector2, dir: Vector2)  ## Healer ranged attack

# ---- STATS (set from MonsterTypes on spawn) ----
var monster_type: MonsterTypes.Type = MonsterTypes.Type.BASIC
var hp: float = 60.0
var max_hp: float = 60.0
var damage: float = 50.0
var speed: float = 140.0
var radius: float = 16.0
var monster_color: Color = Color.RED
var score_value: int = 10
var paint_scale: float = 1.0
var contact_hp_percent: float = 0.10  ## Fraction of player max HP dealt on contact
var split_tier: int = 0  ## Current split level (Splitter/splitter-donor only)

# ---- SPECIAL (HYBRID) MONSTER ----
## ~10% of monsters are "special": they keep their base type's SHAPE + movement but adopt a
## random OTHER type's COLOUR and layer on that donor's signature power (e.g. Speeder body that
## also splits = Speeder+Splitter). Set via make_special() right after initialize().
var is_special: bool = false
var special_type: MonsterTypes.Type = MonsterTypes.Type.BASIC
var _sp_split: bool = false       ## splitter donor → splits on death
var _sp_explode: bool = false     ## tankbomber donor → explodes on death
var _sp_charge_timer: float = 0.0 ## brute donor → time to next charge
var _sp_charge_warn: float = 0.0  ## brute donor → remaining red-blink warning time
var _sp_charging: float = 0.0     ## brute donor → remaining charge-lunge time

# ---- MOVEMENT ----
var heading: float = 0.0           ## Current facing angle (radians)
var _avoidance_force: Vector2 = Vector2.ZERO
var _sprite: Sprite2D = null       ## cached Sprite2D child (avoids per-frame node lookup)
## Cached player (single-player game) so monsters don't run a group query every frame.
## Validity-checked, so it auto-refreshes after a scene change / respawn.
static var _cached_player: Node2D = null
const TURN_SMOOTHING := 10.0      ## heading += delta_angle / this (from original /10)
const AVOIDANCE_RADIUS := 40.0    ## Distance for monster-monster avoidance
const AVOIDANCE_STRENGTH := 200.0

# ---- HARD SEPARATION (anti-stacking) ----
## Monsters don't physically collide with each other; only the soft avoidance force keeps
## them apart — and it has two blind spots that let bodies STACK: an exactly-overlapping
## pair (splitter children spawn ±30 px around one point) gets ZERO force (no direction),
## and AVOIDANCE_RADIUS (40) is smaller than two big bodies' radii summed (tank 32+32), so
## fat types overlap force-free. Stacked monsters chase the same target at the same speed
## and never drift apart → growing piles that tank the framerate. This positional-style
## push (computed pairwise in compute_avoidance, applied as extra velocity) shoves any
## overlapping pair apart; an exact stack gets a random direction so it can split at all.
const SEPARATION_STRENGTH := 8.0      ## px/s of push per px of overlap (per pair)
const SEPARATION_MAX_SPEED := 260.0   ## cap on the summed push (deep piles can't explode)
var _separation_push: Vector2 = Vector2.ZERO

# ---- FREEZE (Freeze-Shot slow / grenade+laser full freeze) ----
## While _freeze_timer > 0 the monster's movement is scaled by _freeze_mult (1 = normal,
## 0.6 = the freeze-shot's light 2 s slow, 0 = a full permanent freeze from a freeze
## grenade/laser). A blue self_modulate tint shows it's chilled (composes with charge/ghost
## modulate). The final-velocity scale lives in _pre_move_freeze() at each move_and_slide.
var _freeze_timer: float = 0.0
var _freeze_mult: float = 1.0
const FREEZE_PERMANENT := 1.0e9   ## "for its entire life" — never counts down in a real game
## A 65%-opacity dark-blue silhouette laid over the sprite while frozen. Shared material
## (fixed dark blue @ 0.65) built once. Reads only the texture ALPHA, so it turns ANY monster
## blue — a plain modulate can't (multiply can't recolour a red sprite to blue).
var _freeze_overlay: Sprite2D = null
static var _freeze_overlay_mat: ShaderMaterial = null

# ---- SPAWNING STATE ----
var is_spawning: bool = true
var _last_safe_pos := Vector2.ZERO  ## last finite position (NaN-transform recovery)
var _spawn_timer: float = 1.0     ## 1 second pre-spawn animation
const SPAWN_DURATION := 1.0

# ---- PREVENT SPLIT (katana/grenade kills) ----
var prevent_split: bool = false

# ---- TYPE-SPECIFIC STATE ----
# Brute
var _is_charging: bool = false
var _charge_warning_timer: float = 0.0

# Healer
var _heal_timer: float = 0.0
var _shoot_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO   ## current random wander heading (challenge mode)
var _wander_timer: float = 0.0

# Spawner
var _spawn_cycle_timer: float = 0.0
var _spawn_warning: bool = false
var spawner_has_spawned: bool = false  ## true once it has produced its first grunts (achievement)

# Ghost
var _ghost_visible: bool = true
var _ghost_timer: float = 0.0
var _ghost_tex_visible: Texture2D = null    ## Purple sprite (loaded on init)
var _ghost_tex_invisible: Texture2D = null  ## Grey sprite (loaded on init)

# Speeder
var _sine_time: float = 0.0

# ---- SPAWNER CHILD (grunts spawned inside a Spawner) ----
var _parent_spawner: Monster = null  ## Set by game_world when spawned from Spawner
var _collision_disabled: bool = false  ## True while still overlapping parent Spawner

# ---- REFERENCES ----

# ---- DECOY LURE (shared across all monsters) ----
## While set to a valid node, every monster chases this instead of the player.
## Set by game_world when a Decoy is thrown; cleared when it detonates.
static var _lure_target: Node2D = null

## Challenge mode: Healers move in random 2s bursts (instead of chasing) until the player
## enters their heal radius, then chase. They also stay inside `wander_bounds` and don't
## pulse-heal. Set per-level by game_world (`_apply_level_modifiers`), reset in `_reset_game`.
static var healer_wander_mode: bool = false
static var wander_bounds: Rect2 = Rect2()
## Challenge mode: EVERY monster wanders in random bursts until the player gets within
## `wander_detect_radius` px, then it switches to its normal behavior.
static var wander_all_mode: bool = false
static var wander_detect_radius: float = 480.0

static func set_lure_target(node: Node2D) -> void:
	_lure_target = node

## Clear the lure. Pass the node to only clear if it's still the active lure
## (avoids a newer decoy being cancelled by an older one detonating).
static func clear_lure_target(node: Node2D = null) -> void:
	if node == null or _lure_target == node:
		_lure_target = null

func _ready() -> void:
	add_to_group("monsters")
	z_index = 6  ## Above player (z=5), bullets (z=3), walls, paint
	_sine_time = randf() * TAU  # Random phase offset for speeders
	_sprite = get_node_or_null("Sprite2D")  # cache once

## Initialize monster with type and stats. Called by spawner.
func initialize(type: MonsterTypes.Type, elapsed_time: float = 0.0, p_split_tier: int = 0) -> void:
	monster_type = type
	split_tier = p_split_tier
	var stats := MonsterTypes.get_stats(type, elapsed_time, p_split_tier)

	hp = stats["hp"]
	max_hp = stats["max_hp"]
	damage = stats["damage"]
	speed = stats["speed"]
	radius = stats["radius"]
	monster_color = stats["color"]
	score_value = stats["score"]
	paint_scale = stats["paint_scale"]
	contact_hp_percent = stats.get("contact_hp_percent", 0.10)

	# Start spawn animation
	is_spawning = true
	_spawn_timer = SPAWN_DURATION

	# Update collision shape to match radius
	_update_collision_shape()

	# Initialize type-specific timers
	match monster_type:
		MonsterTypes.Type.HEALER:
			_heal_timer = stats.get("heal_interval", 3.0)
			_shoot_timer = stats.get("shoot_interval", 3.0)
		MonsterTypes.Type.SPAWNER:
			_spawn_cycle_timer = stats.get("spawn_interval", 5.0)
		MonsterTypes.Type.GHOST:
			_ghost_visible = true
			_ghost_timer = stats.get("visible_duration", 2.0)
			# Pre-load both ghost sprite textures
			_ghost_tex_visible = SpriteLoader.get_ghost_visible_texture()
			_ghost_tex_invisible = SpriteLoader.get_ghost_invisible_texture()

## Turn this into a HYBRID: keep the base type's shape + movement, adopt `donor`'s colour and
## layer on the donor's signature power. `tier` bounds splitter-donor split chains. Call right
## after initialize(); game_world then applies the donor-colour sprite tint (+ tankbomber dot).
func make_special(donor: MonsterTypes.Type, tier: int = 0) -> void:
	is_special = true
	special_type = donor
	monster_color = MonsterTypes.get_color(donor)   # colour = donor (paint splat + sprite tint)
	var ds: Dictionary = MonsterTypes.STATS[donor]
	# BEST-OF-BOTH stats: SPEED and HP each take the LARGER of the base type vs the donor type.
	speed = maxf(speed, float(ds.get("speed", speed)))
	var donor_hp: float = float(ds.get("hp", hp))
	if donor_hp > hp:
		hp = donor_hp
		max_hp = donor_hp
	# Layer the DONOR's signature special attack (the base keeps its own → the hybrid has BOTH).
	match donor:
		MonsterTypes.Type.BRUTE:
			_sp_charge_timer = 1.6                       # periodic charge lunge
		MonsterTypes.Type.HEALER:
			_heal_timer = ds.get("heal_interval", 3.0); _shoot_timer = ds.get("shoot_interval", 3.0)
		MonsterTypes.Type.SPAWNER:
			_spawn_cycle_timer = ds.get("spawn_interval", 5.0)
		MonsterTypes.Type.SPLITTER:
			_sp_split = true; split_tier = tier
		MonsterTypes.Type.GHOST:
			_ghost_visible = true; _ghost_timer = ds.get("visible_duration", 3.0)
		MonsterTypes.Type.TANKBOMBER:
			_sp_explode = true
		# SPEEDER + TANK: pure stats (speed/HP via max-of-both) — hybrids go STRAIGHT at the player.

## Layer the donor's per-frame power on top of the base movement (called each physics frame).
func _special_tick(delta: float, target: Node2D) -> void:
	if not is_special:
		return
	match special_type:
		MonsterTypes.Type.BRUTE:
			_special_brute_charge(delta, target)
		MonsterTypes.Type.HEALER:
			_think_healer(delta)
			_think_healer_shoot(delta, target)
		MonsterTypes.Type.SPAWNER:
			_think_spawner(delta)
		MonsterTypes.Type.GHOST:
			_special_ghost_blink(delta)

## Brute-donor: red-blink warning (like the base Brute/"dasher"), then a fast charge-lunge.
func _special_brute_charge(delta: float, target: Node2D) -> void:
	var warn_t: float = float(MonsterTypes.STATS[MonsterTypes.Type.BRUTE].get("charge_warning_time", 0.4))
	if _sp_charging > 0.0:
		_set_charge_tint(Color(1.5, 0.25, 0.25))       # solid red during the charge
		_sp_charging -= delta
		if target:
			velocity = global_position.direction_to(target.global_position) * speed * 3.0
		if _sp_charging <= 0.0:
			_set_charge_tint(monster_color)             # back to donor colour
	elif _sp_charge_warn > 0.0:
		_sp_charge_warn -= delta                        # winding up: rapid red blink
		var pulse := 0.5 + 0.5 * sin((warn_t - _sp_charge_warn) * 45.0)
		_set_charge_tint(monster_color.lerp(Color(1.6, 0.2, 0.2), pulse))
		if _sp_charge_warn <= 0.0:
			_sp_charging = 0.45
	else:
		_sp_charge_timer -= delta
		if _sp_charge_timer <= 0.0:
			_sp_charge_timer = 2.6
			_sp_charge_warn = warn_t

var _charge_trail_timer: float = 0.0

## One fading red after-image at the monster's current pose (charge trail).
## Parented to the game_world root, NOT the monster container — several systems iterate
## the container with typed `Monster` loops and a stray Sprite2D would crash them.
func _spawn_charge_ghost() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var host := get_tree().get_first_node_in_group("game_world")
	if host == null:
		return
	var g := Sprite2D.new()
	g.texture = _sprite.texture
	g.modulate = Color(1.0, 0.2, 0.2, 0.45)
	g.z_index = z_index - 1
	host.add_child(g)
	g.global_transform = _sprite.global_transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.28)
	tw.tween_callback(g.queue_free)

## Tint the body during a charge warning/lunge. Special monsters use the fill shader (modulate
## is ignored), so drive the shader `tint`; plain monsters use modulate.
func _set_charge_tint(col: Color) -> void:
	if is_special and _sprite and _sprite.material is ShaderMaterial:
		(_sprite.material as ShaderMaterial).set_shader_parameter("tint", col)
	elif _sprite:
		_sprite.modulate = col

## Ghost-donor blink: fade in/out on the SAME (tinted) sprite — no texture swap (keeps base shape).
func _special_ghost_blink(delta: float) -> void:
	var stats := MonsterTypes.STATS[MonsterTypes.Type.GHOST]
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_visible = not _ghost_visible
		set_collision_mask_value(6, _ghost_visible)   # invisible → phase through piston walls
		if _ghost_visible:
			_ghost_timer = stats.get("visible_duration", 3.0)
			if _sprite: _sprite.modulate.a = 1.0
		else:
			_ghost_timer = stats.get("invisible_duration", 3.0)
			if _sprite: _sprite.modulate.a = 0.5   # phased-out = 50% opacity (still see it coming)

## Override the spawn freeze + play a scale/fade-in (0 → full) over `duration`. Used by
## Metin totems so their spawns "grow" out of the totem with a short 0.5s freeze.
func begin_spawn_anim(duration: float) -> void:
	is_spawning = true
	_spawn_timer = duration
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var target_scale: Vector2 = sprite.scale
	# Lock in the REAL resting scale BEFORE shrinking to zero. Otherwise a bullet landing
	# during the grow-in captures the tiny mid-animation scale as "base" and the monster
	# stays permanently small (killing a spawner mid-spawn used to leave dwarf grunts).
	_base_sprite_scale = target_scale
	_base_captured = true
	sprite.scale = Vector2.ZERO
	sprite.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 1.0, duration * 0.8)

func _physics_process(delta: float) -> void:
	# Stoppill: monsters are frozen in place (but can still take damage & die)
	if GameManager.time_stopped:
		return

	if is_spawning:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			is_spawning = false
			# Guarantee the grow-in actually finished: anything that fought the tween mid-spawn
			# (a hit, a killed spawner) must never leave a permanently shrunken monster.
			if _sprite and _base_captured:
				_sprite.scale = _base_sprite_scale
				_sprite.modulate.a = 1.0
			# Snap heading to face the current target so chase starts immediately
			# (instead of having to smoothly rotate from default heading=0).
			var initial_target := _get_target()
			if initial_target:
				heading = global_position.angle_to_point(initial_target.global_position)
		return

	# NaN-transform recovery — sanitize BEFORE any direction math below (a bad collision
	# solve can NaN the transform; normalize() on it spams the console every frame).
	if not global_position.is_finite():
		global_position = _last_safe_pos
		velocity = Vector2.ZERO
	else:
		_last_safe_pos = global_position
	if not velocity.is_finite():
		velocity = Vector2.ZERO

	# Freeze countdown: un-tint + restore full speed when a timed (freeze-shot) freeze ends.
	# A permanent (grenade/laser) freeze never reaches 0, so the monster stays chilled for life.
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_freeze_mult = 1.0
			_hide_freeze_overlay()

	# Check if spawner-child grunt has left parent — re-enable collision
	if _collision_disabled and _parent_spawner != null:
		var dist := global_position.distance_to(_parent_spawner.global_position)
		if dist > _parent_spawner.radius + radius + 5.0:
			_enable_collision()
	elif _collision_disabled and _parent_spawner == null:
		# Parent died — re-enable immediately
		_enable_collision()

	var target := _get_target()
	if target == null:
		return

	# Challenge wander (all types): drift in random bursts until the player is close,
	# then fall through to the normal behavior below.
	if wander_all_mode and global_position.distance_to(target.global_position) > wander_detect_radius:
		_move_wander_step(delta)
		_apply_separation()
		_pre_move_freeze()
		move_and_slide()
		if _sprite:
			_sprite.rotation = heading + PI / 2.0
		return

	match monster_type:
		MonsterTypes.Type.BASIC, MonsterTypes.Type.TANK, MonsterTypes.Type.TANKBOMBER:
			_move_basic(delta, target)
		MonsterTypes.Type.SPEEDER:
			if is_special:
				_move_basic(delta, target)   # hybrids never inherit the sine path — straight chase
			else:
				_move_speeder(delta, target)
		MonsterTypes.Type.BRUTE:
			_move_brute(delta, target)
		MonsterTypes.Type.HEALER:
			if healer_wander_mode:
				_move_healer_wander(delta, target)
				# No heal pulse/decal in challenge mode.
			else:
				_move_basic(delta, target)
				_think_healer(delta)
			_think_healer_shoot(delta, target)  # projectiles always aim at the player
		MonsterTypes.Type.SPAWNER:
			_move_basic(delta, target)
			_think_spawner(delta)
		MonsterTypes.Type.SPLITTER:
			_move_basic(delta, target)
		MonsterTypes.Type.GHOST:
			_move_basic(delta, target)
			_think_ghost(delta)

	# Special (hybrid): layer the donor's power on top of the base behaviour above.
	if is_special:
		_special_tick(delta, target)

	# Red after-image trail while charging (base Brute or any brute-donor hybrid).
	if _is_charging or _sp_charging > 0.0:
		_charge_trail_timer -= delta
		if _charge_trail_timer <= 0.0:
			_charge_trail_timer = 0.045
			_spawn_charge_ghost()

	# Defensive: never feed a non-finite velocity to move_and_slide (would spam
	# "Vector2 cannot be normalized" and teleport the monster).
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	# A bad collision solve can NaN the transform itself — snap back to the last good
	# spot instead of spamming the console forever.
	if not global_position.is_finite():
		global_position = _last_safe_pos
		velocity = Vector2.ZERO
	else:
		_last_safe_pos = global_position
	_apply_separation()
	_pre_move_freeze()
	move_and_slide()

	# Rotate sprite to match heading (SVGs point up = -Y, so offset by +PI/2 to align with +X heading=0)
	if _sprite:
		_sprite.rotation = heading + PI / 2.0

# ============================================================
# MOVEMENT TYPES
# ============================================================

## Standard chase: smooth turn toward player + acceleration.
## Monster's only goal is to reach the player and contact-damage them.
func _move_basic(delta: float, target: Node2D) -> void:
	# Direction from monster TO player (angle_to_point returns this directly in Godot 4).
	var desired_angle := global_position.angle_to_point(target.global_position)
	var angle_diff := CMath.angle_diff(heading, desired_angle)
	heading += angle_diff / TURN_SMOOTHING

	var move_dir := Vector2.from_angle(heading)
	var accel := speed * 2.0  # acceleration = 2 * speed (from original)

	velocity += move_dir * accel * delta
	velocity += _avoidance_force * delta

	# Friction
	velocity *= (1.0 - 0.05)

	# Clamp
	if velocity.length() > speed:
		velocity = velocity.normalized() * speed

## Challenge wander (Healers): move in random ~2s direction bursts; switch to chasing once
## the player is within the heal radius.
func _move_healer_wander(delta: float, target: Node2D) -> void:
	var stats := MonsterTypes.STATS[MonsterTypes.Type.HEALER]
	var heal_radius: float = stats.get("heal_radius", 150.0)
	if target and global_position.distance_to(target.global_position) <= heal_radius:
		_move_basic(delta, target)
		return
	_move_wander_step(delta)

## One step of the random-burst wander: a new random direction every ~2s, smooth turning,
## steered back toward the arena center when outside the inner bounds (monsters don't
## collide with the boundary walls, so they'd drift off-screen).
func _move_wander_step(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or _wander_dir == Vector2.ZERO:
		_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
		_wander_timer = 2.0
	var desired := _wander_dir
	if wander_bounds.size.x > 0.0 and not wander_bounds.grow(-90.0).has_point(global_position):
		desired = (wander_bounds.get_center() - global_position).normalized()
	# Smoothly rotate the heading toward the desired direction (~0.3s for a sharp turn)
	# instead of snapping, so the monsters curve rather than flick around.
	const WANDER_TURN_RATE := 7.0   # rad/s
	var angle_diff := CMath.angle_diff(heading, desired.angle())
	heading += clampf(angle_diff, -WANDER_TURN_RATE * delta, WANDER_TURN_RATE * delta)
	var move_dir := Vector2.from_angle(heading)
	velocity = velocity.move_toward(move_dir * speed * 0.8, speed * 4.0 * delta)
	velocity += _avoidance_force * delta
	if velocity.length() > speed:
		velocity = velocity.normalized() * speed

## Speeder: sinusoidal path that passes through player direction.
func _move_speeder(delta: float, target: Node2D) -> void:
	var to_player := target.global_position - global_position
	var dist := to_player.length()

	# Advance sine phase
	var stats := MonsterTypes.STATS[MonsterTypes.Type.SPEEDER]
	var freq: float = stats.get("sine_frequency", 2.5)
	var amplitude: float = stats.get("sine_amplitude", 80.0)
	var fade_dist: float = stats.get("sine_fade_distance", 120.0)

	_sine_time += delta * freq * TAU

	# Amplitude fades to 0 as monster approaches player
	var fade := clampf(dist / fade_dist, 0.0, 1.0)
	var lateral_offset := sin(_sine_time) * amplitude * fade

	# Base direction toward player + perpendicular sine offset
	var forward := to_player.normalized()
	var perpendicular := Vector2(-forward.y, forward.x)

	var target_pos := target.global_position + perpendicular * lateral_offset
	var move_dir := (target_pos - global_position).normalized()

	velocity = move_dir * speed
	heading = velocity.angle()

## Brute: normal movement until close, then charge attack.
func _move_brute(delta: float, target: Node2D) -> void:
	var dist := global_position.distance_to(target.global_position)
	var stats := MonsterTypes.STATS[MonsterTypes.Type.BRUTE]
	var charge_range: float = stats.get("charge_range", 150.0)
	var charge_mult: float = stats.get("charge_speed_mult", 3.0)
	var warning_time: float = stats.get("charge_warning_time", 0.4)

	if not _is_charging and dist < charge_range:
		_charge_warning_timer += delta
		if _charge_warning_timer >= warning_time:
			_is_charging = true
	elif not _is_charging:
		_charge_warning_timer = 0.0

	var current_speed := speed
	if _is_charging:
		current_speed = speed * charge_mult

	# Direction toward player (no inversion - Godot 4's angle_to_point already gives self→target).
	var desired_angle := global_position.angle_to_point(target.global_position)
	var angle_diff := CMath.angle_diff(heading, desired_angle)
	var turn_rate := TURN_SMOOTHING if not _is_charging else TURN_SMOOTHING * 3.0  # Less turning during charge
	heading += angle_diff / turn_rate

	var move_dir := Vector2.from_angle(heading)
	velocity = move_dir * current_speed

	# Visual warning: rapid red blink while winding up, solid red tint during charge.
	# (Special/hybrid brutes drive the fill shader instead of modulate — see _set_charge_tint.)
	if _sprite:
		var rest: Color = monster_color if is_special else Color.WHITE
		if _is_charging:
			_set_charge_tint(Color(1.5, 0.25, 0.25) if is_special else Color(1.4, 0.45, 0.45))
		elif _charge_warning_timer > 0.0:
			var pulse := 0.5 + 0.5 * sin(_charge_warning_timer * 45.0)
			if is_special:
				_set_charge_tint(rest.lerp(Color(1.6, 0.2, 0.2), pulse))
			else:
				_set_charge_tint(Color(1.0, 1.0 - 0.65 * pulse, 1.0 - 0.65 * pulse))
		else:
			_set_charge_tint(rest)

# ============================================================
# TYPE-SPECIFIC BEHAVIORS
# ============================================================

## Healer: pulse heal every N seconds to nearby monsters.
func _think_healer(delta: float) -> void:
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		var stats := MonsterTypes.STATS[MonsterTypes.Type.HEALER]
		_heal_timer = stats.get("heal_interval", 3.0)
		var heal_radius: float = stats.get("heal_radius", 150.0)
		var heal_pct: float = stats.get("heal_percent", 0.20)

		# Heal nearby monsters (not self)
		var healed: Array = []
		for m: Node in get_tree().get_nodes_in_group("monsters"):
			if m == self or not m is Monster:
				continue
			var mon: Monster = m as Monster
			if mon.is_spawning or mon.hp <= 0:
				continue
			if global_position.distance_to(mon.global_position) <= heal_radius:
				mon.heal(mon.max_hp * heal_pct)
				healed.append(mon)

		# Emit signal for visual effects (heal flash + healer aura)
		if not healed.is_empty():
			healed_pulse.emit(self, healed)

## Healer: fire a paint projectile at the player on a short interval.
## The bullet spawns at the healer's position (hidden beneath it) and game_world
## creates the actual EnemyBullet node via the fired_bullet signal.
func _think_healer_shoot(delta: float, target: Node2D) -> void:
	_shoot_timer -= delta
	if _shoot_timer > 0.0:
		return
	var stats := MonsterTypes.STATS[MonsterTypes.Type.HEALER]
	_shoot_timer = stats.get("shoot_interval", 3.0)
	var dir := (target.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		return
	fired_bullet.emit(global_position, dir)

## Spawner: spawn grunts every N seconds.
func _think_spawner(delta: float) -> void:
	var stats := MonsterTypes.STATS[MonsterTypes.Type.SPAWNER]
	var interval: float = stats.get("spawn_interval", 5.0)
	var warning_time: float = stats.get("spawn_warning_time", 1.0)
	var max_monsters: int = stats.get("spawn_max_monsters", 30)

	_spawn_cycle_timer -= delta

	# Warning pulse before spawn
	if _spawn_cycle_timer <= warning_time and not _spawn_warning:
		_spawn_warning = true

	# Visual warning: brighten/pulse the spawner in the run-up to a spawn.
	var sprite: Sprite2D = _sprite
	if sprite:
		if _spawn_warning:
			var pulse := 0.5 + 0.5 * sin(_spawn_cycle_timer * 28.0)
			var b := 1.0 + 0.7 * pulse
			sprite.modulate = Color(b, b, b)
		else:
			sprite.modulate = Color.WHITE

	if _spawn_cycle_timer <= 0.0:
		_spawn_cycle_timer = interval
		_spawn_warning = false

		# Check monster count limit
		var current_count := get_tree().get_nodes_in_group("monsters").size()
		if current_count >= max_monsters:
			return

		spawner_has_spawned = true   # produced grunts → "kill before spawn" achievement now fails
		# Spawn grunts
		var count: int = stats.get("spawn_count", 4)
		var spread: float = stats.get("spawn_spread", 80.0)
		var children: Array = []

		for i in count:
			var offset := Vector2(CMath.rand(-spread, spread), CMath.rand(-spread, spread))
			children.append({
				"type": MonsterTypes.Type.BASIC,
				"position": global_position + offset,
			})

		spawned_children.emit(children)

## Ghost: toggle between visible (purple) and invisible (grey) sprites.
## While using the grey sprite the ghost is invulnerable (is_targetable() returns false).
func _think_ghost(delta: float) -> void:
	var stats := MonsterTypes.STATS[MonsterTypes.Type.GHOST]
	_ghost_timer -= delta

	if _ghost_timer <= 0.0:
		_ghost_visible = not _ghost_visible
		set_collision_mask_value(6, _ghost_visible)   # invisible → phase through piston walls
		var sprite: Sprite2D = _sprite
		if _ghost_visible:
			_ghost_timer = stats.get("visible_duration", 2.0)
			if sprite and _ghost_tex_visible:
				sprite.texture = _ghost_tex_visible
				sprite.modulate.a = 1.0
		else:
			_ghost_timer = stats.get("invisible_duration", 0.5)
			if sprite and _ghost_tex_invisible:
				sprite.texture = _ghost_tex_invisible
				sprite.modulate.a = 0.4  # Semi-transparent grey to hint at presence

func is_targetable() -> bool:
	if is_spawning:
		return false
	if (monster_type == MonsterTypes.Type.GHOST or special_type == MonsterTypes.Type.GHOST) and not _ghost_visible:
		return false
	return true

func ignores_paint() -> bool:
	return monster_type == MonsterTypes.Type.GHOST or special_type == MonsterTypes.Type.GHOST

## True while a Brute is mid-charge (used by achievements).
func is_charging() -> bool:
	return _is_charging

# ============================================================
# DAMAGE, HEALING & DEATH
# ============================================================

func take_damage(amount: float) -> void:
	if not is_targetable():
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_die()
	else:
		_play_hit_squash()   # springy impact reaction on a non-lethal hit

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)

## Chill this monster: slow it (movement scaled by `slow_mult`) for `duration` seconds and
## tint it blue. Freeze-Shot bullets pass (2.0, 0.6) for a light 2 s slow; a freeze
## grenade/laser passes (FREEZE_PERMANENT, 0.0) to freeze it solid for its whole life. The
## STRONGEST active freeze wins (longest time + lowest speed).
func apply_freeze(duration: float, slow_mult: float) -> void:
	_freeze_timer = maxf(_freeze_timer, duration)
	_freeze_mult = slow_mult if _freeze_mult >= 1.0 else minf(_freeze_mult, slow_mult)
	_show_freeze_overlay()

## Lay a 65%-opacity dark-blue silhouette over the sprite so a slowed/frozen monster is obvious.
func _show_freeze_overlay() -> void:
	if _sprite == null:
		return
	if _freeze_overlay != null and is_instance_valid(_freeze_overlay):
		_freeze_overlay.texture = _sprite.texture   # keep synced (e.g. ghost texture swap)
		return
	if _freeze_overlay_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec4 ov : source_color = vec4(0.08, 0.13, 0.45, 0.65);\nvoid fragment() {\n\tfloat a = texture(TEXTURE, UV).a;\n\tCOLOR = vec4(ov.rgb, a * ov.a);\n}\n"
		_freeze_overlay_mat = ShaderMaterial.new()
		_freeze_overlay_mat.shader = sh
		_freeze_overlay_mat.set_shader_parameter("ov", Color(0.08, 0.13, 0.45, 0.65))  # dark blue @ 65%
	_freeze_overlay = Sprite2D.new()
	_freeze_overlay.texture = _sprite.texture
	_freeze_overlay.material = _freeze_overlay_mat   # shared, fixed blue @ 30%
	_freeze_overlay.z_index = 1                      # render above the base sprite
	_sprite.add_child(_freeze_overlay)               # child → inherits scale/rotation

func _hide_freeze_overlay() -> void:
	if _freeze_overlay != null and is_instance_valid(_freeze_overlay):
		_freeze_overlay.queue_free()
	_freeze_overlay = null

## Extra velocity that shoves overlapping monsters apart (see SEPARATION_STRENGTH). Applied
## as velocity (not a position write) so walls still block it, and BEFORE the freeze cap so
## frozen-solid monsters stay genuinely frozen.
func _apply_separation() -> void:
	if _separation_push != Vector2.ZERO:
		velocity += (_separation_push * SEPARATION_STRENGTH).limit_length(SEPARATION_MAX_SPEED)

## Cap the frame's final speed at freeze_mult × the monster's BASE speed, right before
## move_and_slide — so the slow catches EVERY movement path and even a 3× charge lunge is held
## to 33 % of NORMAL speed (not 33 % of the charge). freeze_mult 0 = frozen solid.
func _pre_move_freeze() -> void:
	if _freeze_mult >= 1.0:
		return
	var cap := speed * _freeze_mult
	if cap <= 0.0:
		velocity = Vector2.ZERO
	elif velocity.length() > cap:
		velocity = velocity.normalized() * cap

# ---- HIT / FLINCH SCALE FX ----------------------------------------------------
## One shared tween drives the sprite's squash/flinch scale (whichever fires last wins).
## Only the Sprite2D SCALE is touched — never modulate — so charge/ghost tints are safe.
var _scale_fx_tween: Tween = null
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_captured: bool = false
var _last_flinch_ms: int = 0

## Capture the sprite's resting scale once (set by game_world at spawn, stable afterwards).
func _capture_base_scale() -> void:
	if not _base_captured and _sprite:
		_base_sprite_scale = _sprite.scale
		_base_captured = true

## Quick squash-and-stretch when shot: the body flattens on impact then springs back.
func _play_hit_squash() -> void:
	if _sprite == null or is_spawning:
		return   # never fight the spawn grow-in tween
	_capture_base_scale()
	if _scale_fx_tween and _scale_fx_tween.is_valid():
		_scale_fx_tween.kill()
	_sprite.scale = _base_sprite_scale
	var squash := Vector2(_base_sprite_scale.x * 1.3, _base_sprite_scale.y * 0.72)
	_scale_fx_tween = create_tween()
	_scale_fx_tween.tween_property(_sprite, "scale", squash, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_fx_tween.tween_property(_sprite, "scale", _base_sprite_scale, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A neighbour died right next to me — cringe (a brief shrink-and-recover) so the whole pack
## visibly reacts to a kill. Rate-limited so dense swarms don't jitter.
func flinch() -> void:
	if _sprite == null or is_spawning or not is_targetable():
		return   # never fight the spawn grow-in tween
	var now := Time.get_ticks_msec()
	if now - _last_flinch_ms < 180:
		return
	_last_flinch_ms = now
	_capture_base_scale()
	if _scale_fx_tween and _scale_fx_tween.is_valid():
		_scale_fx_tween.kill()
	_sprite.scale = _base_sprite_scale
	var cringe := _base_sprite_scale * 0.84
	_scale_fx_tween = create_tween()
	_scale_fx_tween.tween_property(_sprite, "scale", cringe, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_fx_tween.tween_property(_sprite, "scale", _base_sprite_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _die() -> void:
	# Splitter OR splitter-donor hybrid: spawn children (unless killed by katana/grenade).
	# A hybrid's children keep the base SHAPE (child type = monster_type) but stay splitter-hybrids.
	if (monster_type == MonsterTypes.Type.SPLITTER or _sp_split) and not prevent_split:
		var stats := MonsterTypes.STATS[MonsterTypes.Type.SPLITTER]
		var max_tier: int = stats.get("max_split_tier", 2)
		if split_tier < max_tier:
			var count: int = stats.get("split_count", 3)
			var children: Array = []
			for i in count:
				var offset := Vector2(CMath.rand(-30, 30), CMath.rand(-30, 30))
				var cd := {
					"type": monster_type,
					"position": global_position + offset,
					"split_tier": split_tier + 1,
					# Splitter children NEVER roll a random mutation: a splitter-donor hybrid keeps
					# the splitter donor (stays "mutated into splitter"); everything else splits
					# into plain splitters (-2 = never special). No ghost/etc. drops from a split.
					"special": int(MonsterTypes.Type.SPLITTER) if _sp_split else -2,
				}
				children.append(cd)
			spawned_children.emit(children)

	died.emit(self)

# ============================================================
# AVOIDANCE (called externally for performance, like original think threads)
# ============================================================

func compute_avoidance(others: Array) -> void:
	_avoidance_force = Vector2.ZERO
	_separation_push = Vector2.ZERO
	var r2 := AVOIDANCE_RADIUS * AVOIDANCE_RADIUS
	var sp := global_position
	# Grunts still inside their parent Spawner overlap it BY DESIGN — no separation until
	# their collision re-enables (they'd get shoved out through walls otherwise).
	var can_separate := not _collision_disabled
	for other: Monster in others:
		if other == self:
			continue
		var diff := sp - other.global_position
		var d2 := diff.length_squared()        # cheap cull — skip sqrt for far monsters
		if can_separate and not other._collision_disabled:
			# Exactly-stacked pair: no direction to push along — pick a random one so the
			# pair can start separating at all (each body rolls its own direction).
			if d2 <= 0.0001:
				_separation_push += Vector2.RIGHT.rotated(randf() * TAU) * (radius + other.radius) * 0.5
			else:
				var min_sep := (radius + other.radius) * 0.85
				if d2 < min_sep * min_sep:
					var sep_dist := sqrt(d2)
					_separation_push += diff / sep_dist * (min_sep - sep_dist) * 0.5
		if d2 < r2 and d2 > 0.0001:
			var dist := sqrt(d2)
			_avoidance_force += diff / dist * AVOIDANCE_STRENGTH * (1.0 - dist / AVOIDANCE_RADIUS)

# ============================================================
# UTILITY
# ============================================================

func _update_collision_shape() -> void:
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = radius

## Disable collision (used for grunts spawned inside a Spawner body).
## Skip the spawn delay — monster is immediately active and targetable.
func skip_spawn_delay() -> void:
	is_spawning = false
	_spawn_timer = 0.0

func disable_collision() -> void:
	_collision_disabled = true
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if shape_node:
		shape_node.set_deferred("disabled", true)

func _enable_collision() -> void:
	_collision_disabled = false
	_parent_spawner = null
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if shape_node:
		shape_node.set_deferred("disabled", false)

## Current chase target: the active decoy lure if one exists, else the closest player.
func _get_target() -> Node2D:
	if _lure_target != null and is_instance_valid(_lure_target):
		return _lure_target
	return _get_closest_player()

func _get_closest_player() -> Node2D:
	# Single-player game: cache the player node so we don't run a group query every
	# frame for every monster. The validity check auto-refreshes after respawn / scene
	# change (the cache is a shared static).
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("players")
	var closest: Node2D = null
	var closest_dist := INF
	for p: Node in players:
		if p is Node2D:
			var d := global_position.distance_to((p as Node2D).global_position)
			if d < closest_dist:
				closest_dist = d
				closest = p as Node2D
	_cached_player = closest
	return closest
