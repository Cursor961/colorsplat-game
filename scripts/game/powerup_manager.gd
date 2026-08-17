class_name PowerupManager
extends Node
## Manages powerup spawning on the map and tracking ALL active powerups.
## Multiple powerups can be active simultaneously — they stack.
## Picking up the same type resets that type's timer to 15s.
## Only one uncollected powerup on the map at a time.

signal powerup_activated(type: Powerup.Type)
signal powerup_deactivated(type: Powerup.Type)
signal powerup_timer_updated(type: Powerup.Type, remaining: float)

# ---- CONFIG ----
const SPAWN_CHANCE_PER_SEC := 0.06   ## 6% chance each second
const POWERUP_DURATION := 15.0       ## Active duration after pickup
const OCTOSHOOT_DURATION := 30.0     ## Octoshoot lasts 30 seconds
const SHURIKEN_DURATION := 30.0      ## Shuriken lasts 30 seconds
const HPBOOSTMAX_DURATION := 5.0     ## Invincibility lasts 5 seconds
const STOPPILL_DURATION := 10.0      ## Time stop lasts 10 seconds
const SHOOT_BOUNCE_DURATION := 20.0  ## Bullet Bounce (rare) lasts 20 seconds
const SPAWN_MARGIN := 60.0           ## Min px from screen edge for spawn position

# ---- STATE ----
## Dictionary of active powerups: Powerup.Type -> float (remaining seconds)
var _active_powerups: Dictionary = {}
var is_running: bool = false

# ---- SPAWNING ----
var _spawn_check_timer: float = 0.0
var _current_pickup: Powerup = null   ## The uncollected powerup on the map (max 1)
var excluded_types: Array = []        ## types never spawned (e.g. HP_BOOST in Řezník)
var _powerup_scene: PackedScene
var _powerup_container: Node2D        ## Where pickups are added (set by game_world)

# ---- TEXTURES ----
var _textures: Dictionary = {}        ## Powerup.Type -> Texture2D

# ---- ARENA ----
var _arena_width: float = 1920.0
var _arena_height: float = 1080.0

func _ready() -> void:
	_powerup_scene = load("res://scenes/game/powerup.tscn")
	_load_textures()

func _physics_process(delta: float) -> void:
	# Count down active powerups ALWAYS (even when not is_running) — durations must expire
	# in challenges/levels too, where the manager doesn't auto-spawn but drops still
	# activate powerups (e.g. Totem). Otherwise they'd last forever.
	if not _active_powerups.is_empty():
		var expired: Array = []
		for type: int in _active_powerups:
			_active_powerups[type] -= delta
			powerup_timer_updated.emit(type, _active_powerups[type])
			if _active_powerups[type] <= 0.0:
				expired.append(type)
		for type: int in expired:
			_active_powerups.erase(type)
			powerup_deactivated.emit(type)

	# Auto-spawning of map pickups only runs in endless (is_running).
	if not is_running:
		return

	# Spawn check (once per second)
	_spawn_check_timer += delta
	if _spawn_check_timer >= 1.0:
		_spawn_check_timer -= 1.0
		if _current_pickup == null or not is_instance_valid(_current_pickup):
			_current_pickup = null
			if randf() < SPAWN_CHANCE_PER_SEC:
				_spawn_random_powerup()

# ============================================================
# ACTIVATION / DEACTIVATION
# ============================================================

func activate(type: Powerup.Type) -> void:
	# CLEANERMAX is an instant effect — fire once, never stored / no HUD timer.
	if type == Powerup.Type.CLEANERMAX:
		powerup_activated.emit(type)
		return

	var is_new := not _active_powerups.has(type)
	# Rare powerups have longer durations
	var duration := POWERUP_DURATION
	match type:
		Powerup.Type.OCTOSHOOT:
			duration = OCTOSHOOT_DURATION
		Powerup.Type.SHURIKEN:
			duration = SHURIKEN_DURATION
		Powerup.Type.HPBOOSTMAX:
			duration = HPBOOSTMAX_DURATION
		Powerup.Type.STOPPILL:
			duration = STOPPILL_DURATION
		Powerup.Type.SHOOT_BOUNCE:
			duration = SHOOT_BOUNCE_DURATION
	_active_powerups[type] = duration  ## Always reset timer
	if is_new:
		powerup_activated.emit(type)
	## If same type already active → timer was reset, HUD updates via powerup_timer_updated

func has_active(type: Powerup.Type) -> bool:
	return _active_powerups.has(type)

func get_active_types() -> Array:
	return _active_powerups.keys()

# ============================================================
# SPAWNING
# ============================================================

func start(arena_w: float, arena_h: float, container: Node2D) -> void:
	_arena_width = arena_w
	_arena_height = arena_h
	_powerup_container = container
	is_running = true
	_spawn_check_timer = 0.0

func stop() -> void:
	is_running = false
	# Deactivate all
	for type: int in _active_powerups.keys():
		powerup_deactivated.emit(type)
	_active_powerups.clear()
	# Remove any uncollected pickup
	if _current_pickup and is_instance_valid(_current_pickup):
		_current_pickup.queue_free()
	_current_pickup = null

func _spawn_random_powerup() -> void:
	if _powerup_scene == null or _powerup_container == null:
		return

	# Random type
	var types := [Powerup.Type.CLEANER, Powerup.Type.HP_BOOST,
				  Powerup.Type.SHOOT_BOOST, Powerup.Type.SPEED_BOOST,
				  Powerup.Type.FMJ, Powerup.Type.SHOOT_FREEZE]
	types = types.filter(func(t): return not (t in excluded_types))
	if types.is_empty():
		return
	var type: Powerup.Type = types[randi() % types.size()]

	# Random position (within arena, margin from edges)
	var pos := Vector2(
		randf_range(SPAWN_MARGIN, _arena_width - SPAWN_MARGIN),
		randf_range(SPAWN_MARGIN, _arena_height - SPAWN_MARGIN)
	)

	var powerup: Powerup = _powerup_scene.instantiate() as Powerup
	var tex: Texture2D = _textures.get(type, null)
	powerup.initialize(type, tex, 66.0)  ## 2.2x of original 30px diameter
	powerup.global_position = pos
	powerup.collected.connect(_on_powerup_collected)

	_powerup_container.add_child(powerup)
	_current_pickup = powerup

func _on_powerup_collected(powerup: Powerup) -> void:
	activate(powerup.powerup_type)
	_current_pickup = null

# ============================================================
# TEXTURES
# ============================================================

func _load_textures() -> void:
	var paths: Dictionary = {
		Powerup.Type.CLEANER: "res://assets/sprites/powerups/cleaner.svg",
		Powerup.Type.HP_BOOST: "res://assets/sprites/powerups/hpboost.svg",
		Powerup.Type.SHOOT_BOOST: "res://assets/sprites/powerups/shootboost.svg",
		Powerup.Type.SPEED_BOOST: "res://assets/sprites/powerups/speedboost.svg",
		Powerup.Type.FMJ: "res://assets/sprites/powerups/shootfmj.svg",
		Powerup.Type.OCTOSHOOT: "res://assets/sprites/powerups/octoshoot.svg",
		Powerup.Type.SHURIKEN: "res://assets/sprites/powerups/shuriken.svg",
		Powerup.Type.HPBOOSTMAX: "res://assets/sprites/powerups/powerup_hpboostmax.svg",
		Powerup.Type.STOPPILL: "res://assets/sprites/powerups/stoppill.svg",
		Powerup.Type.CLEANERMAX: "res://assets/sprites/powerups/cleanermax.svg",
		Powerup.Type.SHOOT_FREEZE: "res://assets/sprites/powerups/shootfreeze.svg",
		Powerup.Type.SHOOT_BOUNCE: "res://assets/sprites/powerups/shootbounce.svg",
	}
	for type_key: Powerup.Type in paths:
		var path: String = paths[type_key]
		if ResourceLoader.exists(path):
			_textures[type_key] = load(path)
		else:
			push_warning("PowerupManager: texture not found: " + path)

func get_texture(type: Powerup.Type) -> Texture2D:
	return _textures.get(type, null)
