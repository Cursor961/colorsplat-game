class_name MonsterSpawner
extends Node
## Monster wave/level spawner - converted from Monster_Spawner.as, Level.as, Wave.as
## Manages level progression, wave timing, group spawning.
## Used by both Level Mode and Endless Mode.

signal level_started(level_num: int)
signal level_completed(level_num: int)
signal wave_started(wave_num: int)
signal all_levels_completed()  ## Triggers tier increment in Endless
signal monster_spawn_requested(type: MonsterTypes.Type, pos: Vector2, elapsed_time: float, split_tier: int)

# ---- STATE ----
var current_level: int = 0       ## 0-based internally, displayed as 1-based
var current_wave: int = 0
var current_tier: int = 0        ## Legacy (used by HUD/level mode)
var elapsed_time: float = 0.0    ## Seconds since game start (for time-based scaling)
var is_running: bool = false
var is_endless: bool = false

# ---- TIMING ----
var _level_start_time: float = 0.0
var _wave_time: float = 0.0
var _group_spawn_timers: Array = []  ## Per-group spawn tracking

# ---- CURRENT LEVEL DATA ----
var _level_data: Dictionary = {}
var _waves: Array = []
var _active_groups: Array = []  ## Groups currently spawning

# ---- ENDLESS MODE ----
## Seconds per difficulty tier (stat scaling — hp/dmg/speed multipliers).
@export var endless_seconds_per_tier: float = 30.0
## Max monsters on screen (performance cap).
@export var endless_max_monsters: int = 50
## How far off-screen monsters spawn (px beyond the visible camera edge).
@export var endless_spawn_margin: float = 120.0
## Fixed playfield size (matches GameWorld.ARENA_W/H) — used as the spawn-center fallback.
const ARENA_W := 1920.0
const ARENA_H := 1080.0

## Weighted spawn table — every monster type available from the start.
## Weights: grunt 55, tank 15, brute 7, speeder 7, healer 5, splitter 4, ghost 4, spawner 3
## NOTE: static var (not const) because dicts with enum refs aren't valid compile-time constants.
static var ENDLESS_SPAWN_TABLE: Array = [
	{ "type": MonsterTypes.Type.BASIC,      "weight": 55 },
	{ "type": MonsterTypes.Type.TANK,       "weight": 10 },
	{ "type": MonsterTypes.Type.TANKBOMBER, "weight": 5 },
	{ "type": MonsterTypes.Type.BRUTE,      "weight": 7 },
	{ "type": MonsterTypes.Type.SPEEDER,    "weight": 7 },
	{ "type": MonsterTypes.Type.HEALER,     "weight": 5 },
	{ "type": MonsterTypes.Type.SPLITTER,   "weight": 4 },
	{ "type": MonsterTypes.Type.GHOST,      "weight": 4 },
	{ "type": MonsterTypes.Type.SPAWNER,    "weight": 3 },
]

# ---- ENDLESS SPAWN CURVE ----
## Linear ramp: 0.5 monsters/s at 0 min → 1.7 monsters/s at 7 min (420s).
## Uses GameManager.elapsed_time (affected by timeboost zones) for rate calculation.
const ENDLESS_RATE_START := 0.5      ## monsters/s at game_time=0
const ENDLESS_RATE_END := 1.7        ## monsters/s at game_time=420s (7 min)
const ENDLESS_RATE_FINAL := 1.9      ## monsters/s at game_time=780s (13 min) — hard cap
const ENDLESS_RAMP_DURATION := 420.0 ## phase 1: 0 → 7 min  (0.5 → 1.7/s)
const ENDLESS_RAMP2_END := 780.0     ## phase 2 end: 13 min (1.7 → 1.9/s; = 1.8 at 10 min)
const ENDLESS_INITIAL_PAUSE := 1.5   ## seconds before first spawn (game_time)

# ---- SPAWNER RATE LIMIT ----
## Spawner monsters: starts unlimited, ramps down to max 3 per minute at 7 min.
const SPAWNER_RATE_LIMIT_END := 3        ## max spawners per 60s window at ramp end
const SPAWNER_RATE_RAMP_DURATION := 420.0  ## 7 minutes to reach full cap

# ---- PER-TYPE SPAWN CAPS (endless) ----
## Max simultaneous monsters of ONE type on the map. Once a type is at its cap it
## won't spawn until some die. Basic gets a higher cap than the rest.
const MAX_PER_TYPE := 15
const MAX_BASIC := 25
## If fewer than this many distinct types are on the map, the global 50-monster
## cap is lifted so a still-missing type can spawn (keeps variety up). With this
## many distinct types present, 50 is a hard ceiling and nothing spawns past it.
const MIN_DISTINCT_TYPES := 4

# ---- ENDLESS INTERNAL ----
## Max banked spawn budget. Without this, while the map sits at the 50-cap the budget
## keeps accumulating every frame (the spawn loop just breaks), then dumps a huge burst
## the instant space frees up (e.g. a grenade clears 20 monsters). Clamping it keeps the
## real spawn rate bounded by ENDLESS_RATE_END (~1.7/s) — no catch-up bursts.
const MAX_SPAWN_BUDGET := 2.0
## Shifts the endless spawn-rate curve forward in time (set by challenge levels).
var endless_time_offset: float = 0.0
var _endless_spawn_budget: float = 0.0  ## Fractional monster accumulator
var _spawner_spawn_times: Array = []    ## Timestamps of recent spawner spawns (for rate limit)

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	# Stoppill: no new monsters spawn while time is stopped
	if GameManager.time_stopped:
		return
	if is_endless:
		_think_endless(delta)
	else:
		_think_level_mode(delta)

# ============================================================
# LEVEL MODE
# ============================================================

func start_level_mode(level_num: int = 1) -> void:
	is_running = true
	is_endless = false
	current_tier = 0
	_load_level(level_num)

func _load_level(level_num: int) -> void:
	current_level = level_num
	current_wave = 0
	_level_start_time = 0.0
	_wave_time = 0.0

	_level_data = LevelData.get_level(level_num)
	if _level_data.is_empty():
		all_levels_completed.emit()
		return

	_waves = _level_data.get("waves", [])
	_active_groups = []
	level_started.emit(level_num)

func _think_level_mode(delta: float) -> void:
	_level_start_time += delta
	_wave_time += delta

	# Check if current wave should start
	if current_wave < _waves.size():
		var wave_data: Dictionary = _waves[current_wave]
		var delay: float = wave_data.get("delay", 0.0)

		if _level_start_time >= delay:
			_start_wave(wave_data)
			current_wave += 1
			_wave_time = 0.0

	# Process active group spawning
	_process_active_groups(delta)

	# Check level completion: all waves done + no monsters alive
	if current_wave >= _waves.size() and _active_groups.is_empty():
		if get_tree().get_nodes_in_group("monsters").is_empty():
			level_completed.emit(current_level)
			# Auto-advance to next level
			if current_level < LevelData.TOTAL_LEVELS:
				_load_level(current_level + 1)
			else:
				all_levels_completed.emit()
				is_running = false

func _start_wave(wave_data: Dictionary) -> void:
	wave_started.emit(current_wave)
	var groups: Array = wave_data.get("groups", [])
	for group: Dictionary in groups:
		var active_group := {
			"data": group,
			"remaining": group.get("count", 1),
			"total": group.get("count", 1),
			"timer": 0.0,
			"spawn_interval": 0.3,  ## Time between individual spawns in group
		}
		_active_groups.append(active_group)

func _process_active_groups(delta: float) -> void:
	var completed: Array = []

	for i in _active_groups.size():
		var ag: Dictionary = _active_groups[i]
		ag["timer"] += delta

		if ag["remaining"] > 0 and ag["timer"] >= ag["spawn_interval"]:
			ag["timer"] -= ag["spawn_interval"]
			_spawn_from_group(ag["data"])
			ag["remaining"] -= 1

		if ag["remaining"] <= 0:
			completed.append(i)

	# Remove completed groups (reverse order)
	for i in range(completed.size() - 1, -1, -1):
		_active_groups.remove_at(completed[i])

func _spawn_from_group(group: Dictionary) -> void:
	var base_pos: Vector2 = group.get("position", Vector2(0.5, 0.5))
	var spread: float = group.get("spread", 50.0)
	var type: MonsterTypes.Type = group.get("type", MonsterTypes.Type.BASIC)
	var formation: String = group.get("formation", "")

	var viewport_size := get_viewport().get_visible_rect().size

	if formation == "wall":
		_spawn_wall_formation(group, viewport_size)
	elif formation == "grid":
		_spawn_grid_formation(group, viewport_size)
	else:
		# Standard random spread
		var world_pos := Vector2(
			base_pos.x * viewport_size.x + CMath.rand(-spread, spread),
			base_pos.y * viewport_size.y + CMath.rand(-spread, spread)
		)
		monster_spawn_requested.emit(type, world_pos, elapsed_time, 0)

func _spawn_wall_formation(group: Dictionary, viewport_size: Vector2) -> void:
	var center: Vector2 = group.get("position", Vector2(0.5, 0.5))
	var count: int = group.get("count", 5)
	var spacing: float = group.get("spacing", 0.08)
	var horizontal: bool = group.get("horizontal", true)
	var type: MonsterTypes.Type = group.get("type", MonsterTypes.Type.BASIC)

	for i in count:
		var offset := (i - count / 2.0) * spacing
		var pos: Vector2
		if horizontal:
			pos = Vector2((center.x + offset) * viewport_size.x, center.y * viewport_size.y)
		else:
			pos = Vector2(center.x * viewport_size.x, (center.y + offset) * viewport_size.y)
		monster_spawn_requested.emit(type, pos, elapsed_time, 0)

func _spawn_grid_formation(group: Dictionary, viewport_size: Vector2) -> void:
	var center: Vector2 = group.get("position", Vector2(0.5, 0.5))
	var grid_size: Vector2i = group.get("grid_size", Vector2i(3, 3))
	var spacing: float = group.get("spacing", 0.06)
	var type: MonsterTypes.Type = group.get("type", MonsterTypes.Type.BASIC)

	for row in grid_size.y:
		for col in grid_size.x:
			var offset := Vector2(
				(col - grid_size.x / 2.0) * spacing,
				(row - grid_size.y / 2.0) * spacing
			)
			var pos := Vector2(
				(center.x + offset.x) * viewport_size.x,
				(center.y + offset.y) * viewport_size.y
			)
			monster_spawn_requested.emit(type, pos, elapsed_time, 0)

# ============================================================
# ENDLESS MODE  (continuous off-screen spawning, percentage-based)
# ============================================================

func start_endless() -> void:
	is_running = true
	is_endless = true
	current_level = 0
	current_tier = 0
	current_wave = 0
	_level_start_time = 0.0
	elapsed_time = 0.0
	_endless_spawn_budget = 0.0
	_spawner_spawn_times.clear()
	endless_time_offset = 0.0   # challenges set it AFTER start_endless()

## Continuous spawn loop. Difficulty scales with GameManager.elapsed_time (score time).
## Linear ramp: 0.5 monsters/s at 0 min → 1.7 monsters/s at 7 min (420s).
## Budget-based: fractional monsters accumulate, spawn when budget >= 1.0.
## Monster stats are constant (no time-based stat scaling).
func _think_endless(delta: float) -> void:
	_level_start_time += delta
	elapsed_time = _level_start_time

	# Use game elapsed time (affected by timeboost zones) for spawn rate.
	# endless_time_offset shifts the curve (challenges: spawn as if N seconds in).
	var game_time := GameManager.elapsed_time + endless_time_offset

	# Initial 1.5s pause
	if game_time < ENDLESS_INITIAL_PAUSE:
		return

	# Two-phase linear spawn rate:
	#   phase 1: 0.5/s → 1.7/s over 0–7 min
	#   phase 2: 1.7/s → 1.9/s over 7–13 min (1.8/s at 10 min), then capped at 1.9/s
	var rate: float
	if game_time <= ENDLESS_RAMP_DURATION:
		rate = ENDLESS_RATE_START + (ENDLESS_RATE_END - ENDLESS_RATE_START) * (game_time / ENDLESS_RAMP_DURATION)
	else:
		var t2 := clampf((game_time - ENDLESS_RAMP_DURATION) / (ENDLESS_RAMP2_END - ENDLESS_RAMP_DURATION), 0.0, 1.0)
		rate = ENDLESS_RATE_END + (ENDLESS_RATE_FINAL - ENDLESS_RATE_END) * t2

	# Accumulate spawn budget (clamped so it can't bank a burst while at the cap)
	_endless_spawn_budget = minf(_endless_spawn_budget + rate * delta, MAX_SPAWN_BUDGET)

	# Spawn monsters while budget allows, honoring per-type caps and the
	# diversity-aware global cap. type_counts/total are tracked locally and bumped
	# per spawn (the new monster isn't in the "monsters" group until next frame).
	var monsters := get_tree().get_nodes_in_group("monsters")
	var type_counts := _count_types(monsters)
	var total := monsters.size()
	while _endless_spawn_budget >= 1.0:
		var at_global_cap := total >= endless_max_monsters
		var distinct := type_counts.size()
		# 50 cap: hard ceiling once 4+ types are present; lifted below that so a
		# missing type can still come in to fill out the variety.
		if at_global_cap and distinct >= MIN_DISTINCT_TYPES:
			break
		var force_new := at_global_cap  # here distinct < MIN_DISTINCT_TYPES
		var type := _pick_endless_type(type_counts, force_new)
		if type < 0:
			break  # nothing eligible (all at cap / no missing type available)
		_endless_spawn_budget -= 1.0
		_spawn_endless_single(type)
		total += 1
		type_counts[type] = int(type_counts.get(type, 0)) + 1

## Check if spawner spawn rate is at its per-minute limit.
## Starts unlimited (no cap), linearly ramps to 3/minute over 7 min.
## Returns true if spawner should be blocked (rate exceeded).
func _is_spawner_rate_limited() -> bool:
	var game_time := GameManager.elapsed_time
	# Before any ramp, spawners are unlimited
	if game_time <= 0.0:
		return false
	# Linear ramp: unlimited (INF) → 3/min over 420s
	var t := clampf(game_time, 0.0, SPAWNER_RATE_RAMP_DURATION)
	var ramp_frac := t / SPAWNER_RATE_RAMP_DURATION  # 0.0 → 1.0
	if ramp_frac <= 0.0:
		return false  # Still unlimited
	# Effective cap per minute: lerp from very large → 3
	# At ramp_frac=0.01 → ~300/min (effectively unlimited). At 1.0 → 3/min.
	var cap_per_min: float = SPAWNER_RATE_LIMIT_END / ramp_frac
	# Purge timestamps older than 60 seconds
	var cutoff := game_time - 60.0
	while _spawner_spawn_times.size() > 0 and _spawner_spawn_times[0] < cutoff:
		_spawner_spawn_times.pop_front()
	# Check if recent spawner count exceeds the current cap
	return _spawner_spawn_times.size() >= int(cap_per_min)

## Record a spawner spawn timestamp (called when a SPAWNER type is picked).
func _record_spawner_spawn() -> void:
	_spawner_spawn_times.append(GameManager.elapsed_time)

## Count live monsters per type → { MonsterTypes.Type: count }.
func _count_types(monsters: Array) -> Dictionary:
	var counts: Dictionary = {}
	for m in monsters:
		if m is Monster:
			var t: int = m.monster_type
			counts[t] = int(counts.get(t, 0)) + 1
	return counts

## Max simultaneous count allowed for a given type.
func _type_cap(type: int) -> int:
	return MAX_BASIC if type == MonsterTypes.Type.BASIC else MAX_PER_TYPE

## Pick a weighted endless type that's eligible to spawn, or -1 if none is.
## Eligibility: under its per-type cap, and (for SPAWNER) not rate-limited.
## When force_new is true the global cap has been lifted purely to add variety,
## so only types NOT currently on the map qualify — each spawn then raises the
## distinct-type count toward MIN_DISTINCT_TYPES.
func _pick_endless_type(type_counts: Dictionary, force_new: bool) -> int:
	var spawner_limited := _is_spawner_rate_limited()

	# Build the eligible weighted pool.
	var pool: Array = []
	var pool_weight := 0
	for entry: Dictionary in ENDLESS_SPAWN_TABLE:
		var t: int = entry["type"]
		var count: int = int(type_counts.get(t, 0))
		if count >= _type_cap(t):
			continue  # per-type cap reached
		if force_new and count > 0:
			continue  # variety mode: only brand-new types
		if t == MonsterTypes.Type.SPAWNER and spawner_limited:
			continue  # spawner rate limit
		pool.append(entry)
		pool_weight += int(entry["weight"])

	if pool.is_empty() or pool_weight <= 0:
		return -1

	var roll := randi() % pool_weight
	var cumulative := 0
	for entry: Dictionary in pool:
		cumulative += int(entry["weight"])
		if roll < cumulative:
			var picked: int = entry["type"]
			if picked == MonsterTypes.Type.SPAWNER:
				_record_spawner_spawn()
			return picked
	return -1

## Spawn one monster of `type` just beyond the PLAYFIELD boundary (the walls — where the
## player can no longer go), so it drives in across the arena from a random edge.
func _spawn_endless_single(type: int) -> void:
	var margin := endless_spawn_margin  # px beyond the arena edge

	# Random edge: 0=top, 1=right, 2=bottom, 3=left — just outside the 1920x1080 playfield.
	var edge := randi() % 4
	var pos: Vector2
	match edge:
		0:  # top
			pos = Vector2(randf_range(0.0, ARENA_W), -margin)
		1:  # right
			pos = Vector2(ARENA_W + margin, randf_range(0.0, ARENA_H))
		2:  # bottom
			pos = Vector2(randf_range(0.0, ARENA_W), ARENA_H + margin)
		_:  # left
			pos = Vector2(-margin, randf_range(0.0, ARENA_H))

	monster_spawn_requested.emit(type, pos, elapsed_time, 0)

# ============================================================
# CONTROL
# ============================================================

func stop() -> void:
	is_running = false
	_active_groups.clear()

func reset() -> void:
	stop()
	current_level = 0
	current_wave = 0
	current_tier = 0
	elapsed_time = 0.0
	_spawner_spawn_times.clear()
