class_name Player
extends CharacterBody2D
## Player controller - converted from Classes/Player.as
## Dual joystick input: left = movement, right = aim/shoot direction.
## Paint collection, powerup mode, health, death.

signal died(player: Player)
signal health_changed(current: float, max_hp: float)
signal score_changed(score: int)

# ---- TWEAKABLE STATS (see docs/features.md) ----
@export_group("Movement")
@export var max_speed: float = 500.0          ## Max velocity in px/s
@export var acceleration: float = 1700.0      ## Acceleration in px/s^2
@export var friction: float = 0.05            ## Velocity decay per physics frame (velocity *= 1 - friction)
@export var ice_friction: float = 0.006       ## Much lower decay while standing on ice (2x slipperier)
@export var paint_slow_factor: float = 0.1    ## Speed multiplier when on enemy paint (10% of max)
@export var bounce_factor: float = 0.5        ## Wall bounce velocity retention
var _last_safe_pos := Vector2.ZERO             ## last finite position (NaN-transform recovery)

@export_group("Combat")
@export var max_health: float = 500.0
@export var bullet_damage: float = 100.0
@export var fire_rate: float = 5.0            ## Bullets per second
@export var bullet_speed: float = 500.0
@export var bullet_radius: float = 20.0
@export var hit_invuln_duration: float = 0.5  ## I-frames after taking a hit (prevents 60Hz HP drain on monster contact)

@export_group("Powerup")
@export var powerup_spread_angle: float = 10.0 ## Degrees offset for triple shot

@export_group("Visual")
@export var player_color: Color = Color(1.0, 0.8, 0.0)  ## Yellow default
@export var radius: float = 15.6             ## Visual/collision radius (1.2x of 13)

# ---- INTERNAL STATE ----
var health: float
var score: int = 0
var is_powered_up: bool = false   ## Externally controlled by PowerupManager (triple shot)
var is_dead: bool = false
var is_invulnerable: bool = false  ## After respawn / brief hit i-frames
var is_powerup_invincible: bool = false  ## Invincibility powerup — also blocks zone damage
var speed_multiplier: float = 1.0  ## Set by PowerupManager (SpeedBoost = 2.0)
var level_speed_mult: float = 1.0  ## Permanent per-level speed factor (challenges); NOT reset by respawn/powerups
var can_shoot: bool = true         ## Disabled by some challenges (e.g. the "dasher" survive-only run)
var ammo: int = -1                 ## Remaining bullets; -1 = unlimited (limited-ammo challenges)

var _move_input: Vector2 = Vector2.ZERO
var _aim_input: Vector2 = Vector2.ZERO
var _last_shot_time: float = 0.0
var _death_timer: float = 0.0
var _invuln_timer: float = 0.0
var _spawn_grace_timer: float = 0.0   ## brief FULL immunity (incl. spikes/saws) after (re)spawn — stops instant re-death
var _current_slow: float = 1.0  ## Paint slowdown multiplier (1.0 = no slow)
var _launch_timer: float = 0.0   ## while > 0, a speed-pad boost overrides movement input
var _ice_count: int = 0          ## # of overlapping ice zones (slippery while > 0)

## Effective per-frame velocity decay (ice = much lower → the player slides).
func _eff_friction() -> float:
	return ice_friction if _ice_count > 0 else friction

## Ref-counted ice zone enter/exit (LevelIceTile calls these).
func enter_ice() -> void:
	_ice_count += 1

func exit_ice() -> void:
	_ice_count = maxi(0, _ice_count - 1)

# ---- REFERENCES ----
var _game_world: Node2D  ## Set by GameWorld on spawn
var _hit_flash_tw: Tween  ## red damage flash on the sprite

## Brief bright-red flash of the player sprite — instant "I got hit" signal that's
## visible even when the HP gauge (bottom of screen) is out of the player's focus.
func flash_hit() -> void:
	var sprite := get_node_or_null("Sprite2D")
	if sprite == null:
		return
	if _hit_flash_tw and _hit_flash_tw.is_valid():
		_hit_flash_tw.kill()
	sprite.modulate = Color(2.4, 0.5, 0.5)   # over-bright red
	_hit_flash_tw = create_tween()
	_hit_flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.28).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	health = max_health
	add_to_group("players")
	z_index = 5  ## Layer 1 (top): player above bullets, walls, paint

func _physics_process(delta: float) -> void:
	if is_dead:
		# Use unscaled delta so death timer runs in real seconds
		# (Engine.time_scale ramps to ~0 during death slowdown)
		var real_delta := delta / maxf(Engine.time_scale, 0.01)
		_death_timer -= real_delta
		if _death_timer <= 0.0:
			_on_death_timer_expired()
		return

	# Invulnerability countdown
	if is_invulnerable:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			is_invulnerable = false
	if _spawn_grace_timer > 0.0:
		_spawn_grace_timer -= delta

	var speed_before := velocity.length()
	_process_movement(delta)
	_process_shooting(delta)
	_process_paint_detection()
	_process_juice(delta, speed_before)

# ============================================================
# JUICE: squash & stretch + speed-pad ghost trail
# ============================================================
const JuiceFX := preload("res://scripts/utils/juice.gd")
var _ice_spark_t: float = 0.0              ## next light-blue slide spark (on ice)
## Vortex scale driven by LevelTeleport (1 = normal, 0 = fully swallowed by a portal). It
## MULTIPLIES into the squash result below instead of fighting it — the squash system rewrites
## sprite.scale every frame, so a plain tween on the sprite would be overwritten.
var teleport_scale: float = 1.0
var _squash_base: Vector2 = Vector2.ZERO   ## sprite's authored scale (captured lazily)
var _squash_tex: Texture2D = null          ## re-capture base when the skin texture changes
var _wall_squash: float = 0.0              ## impact squash amount (decays)
var _ghost_trail_t: float = 0.0            ## remaining ghost-trail time (speed pads)
var _ghost_tick: float = 0.0

func _process_juice(delta: float, speed_before: float) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	# Capture the sprite's base scale BEFORE we ever write to it (and again on skin swap).
	if _squash_base == Vector2.ZERO or _squash_tex != sprite.texture:
		_squash_base = sprite.scale
		_squash_tex = sprite.texture
	# Wall impact: speed dropped hard while touching something -> quick squash pop.
	if get_slide_collision_count() > 0 and speed_before - velocity.length() > 320.0:
		_wall_squash = 0.16
	_wall_squash = maxf(_wall_squash - delta * 0.9, 0.0)
	# Stretch along the movement direction (projected onto the sprite's local axes).
	var f := clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.4) * 0.10
	var ang := velocity.angle() - sprite.global_rotation
	var cx := absf(cos(ang))
	var sy := absf(sin(ang))
	var sq := 1.0 - _wall_squash
	sprite.scale = _squash_base * teleport_scale * Vector2(
		(1.0 + f * cx - f * 0.5 * sy) * sq,
		(1.0 + f * sy - f * 0.5 * cx) * sq)
	# Light-blue slide sparks while on ice (signals "you're slipping") — cleaner-style sparks.
	if _ice_count > 0 and velocity.length() > 60.0:
		_ice_spark_t -= delta
		if _ice_spark_t <= 0.0:
			_ice_spark_t = 0.06
			var sp := Sprite2D.new()
			sp.texture = JuiceFX._spark_texture()
			sp.modulate = Color(0.55, 0.85, 1.0, 0.9)
			sp.z_index = 4   # under the player (5), over the floor
			get_parent().add_child(sp)
			var back := -velocity.normalized()
			sp.global_position = global_position + back * radius \
				+ Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
			var ssf := randf_range(0.22, 0.42)
			sp.scale = Vector2(ssf, ssf)
			var stw := sp.create_tween()
			stw.set_parallel(true)
			stw.tween_property(sp, "global_position",
				sp.global_position + back * randf_range(22.0, 48.0)
				+ Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)), 0.35) \
				.set_ease(Tween.EASE_OUT)
			stw.tween_property(sp, "scale", Vector2.ZERO, 0.35).set_ease(Tween.EASE_IN)
			stw.tween_property(sp, "modulate:a", 0.0, 0.35)
			stw.chain().tween_callback(sp.queue_free)
	# Ghost trail while a speed-pad launch is active.
	if _ghost_trail_t > 0.0:
		_ghost_trail_t -= delta
		_ghost_tick -= delta
		if _ghost_tick <= 0.0:
			_ghost_tick = 0.04
			var g := Sprite2D.new()
			g.texture = sprite.texture
			g.global_transform = sprite.global_transform
			g.modulate = Color(0.75, 0.9, 1.0, 0.4)
			g.z_index = z_index - 1
			get_parent().add_child(g)
			var tw := g.create_tween()
			tw.tween_property(g, "modulate:a", 0.0, 0.3)
			tw.tween_callback(g.queue_free)

# ============================================================
# MOVEMENT
# ============================================================

func set_move_input(input: Vector2) -> void:
	_move_input = input

func set_aim_input(input: Vector2) -> void:
	_aim_input = input

## Speed-pad boost: fling the player at `vel` for `duration`, overriding input so the
## pad actually throws them (friction still bleeds it off). Called by LevelSpeedPad.
func launch(vel: Vector2, duration: float = 0.35) -> void:
	velocity = vel
	_launch_timer = maxf(_launch_timer, duration)
	_ghost_trail_t = maxf(_ghost_trail_t, duration + 0.15)   # motion-blur ghosts while flying

func _process_movement(delta: float) -> void:
	# NaN-transform recovery (see monster.gd): a degenerate collision solve can poison
	# velocity/position — snap back to the last good spot instead of breaking forever.
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not global_position.is_finite():
		global_position = _last_safe_pos
	else:
		_last_safe_pos = global_position
	# Speed-pad launch: carry the boost velocity, ignore stick input for its duration.
	if _launch_timer > 0.0:
		_launch_timer -= delta
		velocity *= (1.0 - friction)
		var lc := move_and_collide(velocity * delta)
		if lc:
			velocity = velocity.bounce(lc.get_normal()) * bounce_factor
		return
	# Variable speed: the joystick's distance from its center (0..1) scales the speed cap
	# linearly — a slight push moves slowly, only the very edge gives full speed. Keyboard
	# input is a unit vector, so it still moves at full speed.
	var input_mag := minf(_move_input.length(), 1.0)
	if input_mag > 0.01:
		var dir := _move_input.normalized()
		velocity += dir * acceleration * speed_multiplier * level_speed_mult * delta

		# Clamp to the magnitude-scaled max speed (with paint slowdown + speed powerup)
		var effective_max := max_speed * _current_slow * speed_multiplier * level_speed_mult * input_mag
		if not velocity.is_finite():
			velocity = Vector2.ZERO
		elif velocity.length() > effective_max:
			velocity = velocity.normalized() * effective_max

	# Apply friction (also glides to a stop when input is released). On ice this is much
	# lower, so the player keeps sliding.
	velocity *= (1.0 - _eff_friction())

	# Move and handle wall collisions (bounce)
	var collision := move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * bounce_factor

# ============================================================
# SHOOTING
# ============================================================

func _process_shooting(delta: float) -> void:
	if not can_shoot or ammo == 0:
		return
	var fire_interval := 1.0 / fire_rate
	# The cooldown keeps ticking even while the aim stick is idle (capped at ONE banked
	# shot so idling can't store a burst) — a shot is ready the moment the player aims.
	# Matters most for slow fire rates (e.g. Sniper's 1 laser / 1.5 s).
	_last_shot_time = minf(_last_shot_time + delta, fire_interval)
	if _aim_input.length_squared() < 0.04:  # Dead zone
		return

	if _last_shot_time >= fire_interval:
		_last_shot_time -= fire_interval
		_fire_bullet(_aim_input.normalized())

		# Powerup: triple shot
		if is_powered_up:
			var spread_rad := deg_to_rad(powerup_spread_angle)
			var dir := _aim_input.normalized()
			_fire_bullet(dir.rotated(spread_rad), true)
			_fire_bullet(dir.rotated(-spread_rad), true)

func _fire_bullet(direction: Vector2, is_secondary: bool = false) -> void:
	if _game_world and _game_world.has_method("spawn_bullet"):
		_game_world.spawn_bullet(
			global_position,
			direction,
			bullet_speed,
			bullet_damage,
			bullet_radius,
			player_color,
			is_secondary
		)
	# Play shoot sound only for primary bullet (not the triple-shot side bullets).
	# FMJ powerup uses its own shot sound.
	if not is_secondary:
		# Limited-ammo challenges: each primary shot consumes one bullet.
		if ammo > 0:
			ammo -= 1
			if _game_world and _game_world.has_method("on_player_ammo_changed"):
				_game_world.on_player_ammo_changed(ammo)
		# Freeze Shot reuses the punchy FMJ fire sound.
		if _game_world and _game_world.has_method("is_fmj_active") and _game_world.is_fmj_active():
			AudioManager.play_sfx("bullet_fire_fmj")
		elif _game_world and _game_world.has_method("is_freeze_active") and _game_world.is_freeze_active():
			AudioManager.play_sfx("bullet_fire_fmj")
		else:
			AudioManager.play_sfx("bullet_fire")


# ============================================================
# PAINT DETECTION (slowdown)
# ============================================================

func _process_paint_detection() -> void:
	## Override _current_slow based on paint under player.
	## Called by FloorPaint system via game_world.
	## Default: no slow. FloorPaint sets this each frame.
	pass  # Handled externally by FloorPaint.check_player_paint()

func set_paint_slow(factor: float) -> void:
	## Called by FloorPaint. factor = 1.0 (no slow) or paint_slow_factor (on enemy paint).
	_current_slow = factor

# ============================================================
# DAMAGE & DEATH
# ============================================================

func take_damage(amount: float) -> void:
	# is_powerup_invincible = the Invincibility rare powerup (and win anim). Unlike the brief
	# i-frame flag (is_invulnerable, which decays) it blocks EVERY damage source — contact,
	# explosions, everything — so nothing can chip the player while it's active.
	if is_dead or is_invulnerable or is_powerup_invincible:
		return
	health -= amount
	health_changed.emit(health, max_health)

	if health <= 0.0:
		health = 0.0
		_die()
	else:
		# Brief i-frames after each hit so sustained monster contact doesn't drain HP at 60Hz.
		is_invulnerable = true
		_invuln_timer = hit_invuln_duration

## Continuous damage (danger zones) — bypasses brief hit i-frames (does not
## trigger them either). Still blocked by the invincibility powerup.
func take_zone_damage(amount: float) -> void:
	# Spawn grace blocks EVEN spikes/saws so the player can't be re-killed the instant they
	# respawn (a hazard near the start, or a moving saw sweeping over the spawn point).
	if is_dead or is_powerup_invincible or _spawn_grace_timer > 0.0:
		return
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0.0:
		health = 0.0
		_die()

func _die() -> void:
	is_dead = true
	_death_timer = 2.0  # 2 second delay before game over
	died.emit(self)
	# Visual: big paint splat at position (handled by game_world)

func _on_death_timer_expired() -> void:
	if _game_world and _game_world.has_method("on_player_death_complete"):
		_game_world.on_player_death_complete(self)

func respawn(pos: Vector2) -> void:
	health = max_health
	is_dead = false
	is_powered_up = false
	is_invulnerable = true
	is_powerup_invincible = false
	speed_multiplier = 1.0
	_launch_timer = 0.0    # clear any speed-pad boost — dying mid-boost must NOT carry the
	_ghost_trail_t = 0.0   # launch (locked input + motion ghosts) into the respawn / retry
	teleport_scale = 1.0   # safety: never respawn mid-portal-vortex (would leave the player invisible)
	_invuln_timer = 3.0  # 3s invulnerability after respawn
	_spawn_grace_timer = 1.5  # + full hazard immunity so a saw/spike can't instantly re-kill
	velocity = Vector2.ZERO
	global_position = pos
	health_changed.emit(health, max_health)

# ============================================================
# SCORE
# ============================================================

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)
