class_name LevelManager
extends Node2D
## Central coordinator for a hand-built Level or Challenge. Use it as the ROOT node of
## a level scene — every component (walls, spawns, exit…) goes underneath it.
##
## Drop ONE LevelManager into the root of a level scene and set its goal flags in the
## Inspector. The game host (game_world) calls `begin(host, player)` after loading the
## level; LevelManager then applies the start conditions (e.g. 1-HP challenges), fires
## every spawner, tracks progress, and emits `level_won` when ALL enabled goals are met.
## Player death is handled by the normal death flow (= level failed).
##
## Components find this node via the "level_manager" group. See docs/level_building_guide.

signal level_won
signal targets_changed(done: int)   ## a destroy-target went down (HUD counter)
signal level_failed
signal key_collected(key_id: String)

# ---- GOALS (enable any combination; ALL enabled goals must be satisfied to win) ----
@export_group("Goals")
## Win by stepping onto a LevelExit platform.
@export var goal_reach_exit: bool = true
## Win by staying alive for `survive_seconds`.
@export var goal_survive_time: bool = false
@export var survive_seconds: float = 60.0
## Win by killing `kill_target` monsters.
@export var goal_kill_count: bool = false
@export var kill_target: int = 10
## Win when every monster the level spawned is dead (at least one must have spawned).
@export var goal_kill_all: bool = false
## Win when every registered "target" (e.g. Metin totems) is destroyed. Targets register
## themselves in _ready and call target_destroyed() when killed.
@export var goal_clear_targets: bool = false

# ---- PLAYER START CONDITIONS ----
@export_group("Player start")
## Optional: drag a Node2D/Marker here to place the player there at level start.
@export var player_start: Node2D
## Direct spawn position (used if non-zero) — simpler + more reliable than a node ref.
@export var player_start_pos: Vector2 = Vector2.ZERO
## If > 0, the player's max HP is capped to this for the whole level.
@export var cap_max_hp: float = 0.0
## If > 0, the player starts with exactly this much HP (e.g. 1 for a 1-HP challenge).
@export var force_start_hp: float = 0.0

@export_group("Challenge modifiers")
## Player can't shoot for the whole level (e.g. a pure-dodge challenge).
@export var disable_shooting: bool = false
## Multiplies enemy (Healer) projectile speed for this level.
@export var enemy_projectile_speed_mult: float = 1.0
## Healers wander randomly until the player is near (instead of chasing) + don't heal.
@export var healer_wander: bool = false
## If > 0, shrink the playfield to this size (walls + camera clamp). 0 = default 1920x1080.
@export var arena_width_override: float = 0.0
@export var arena_height_override: float = 0.0
## Hide the bottom HP gauge (for fixed 1-HP challenges where HP isn't worth showing).
@export var hide_hp_bar: bool = false
## Run the normal weighted ENDLESS monster spawning during this level.
@export var endless_spawning: bool = false
## If > 0, overrides the player's fire rate (shots/s) for this level.
@export var fire_rate_override: float = 0.0
## If > 0, overrides the player's bullet damage (e.g. 99999 = instakill).
@export var bullet_damage_override: float = 0.0
## If > 0, the player has this many bullets for the whole level; the HUD shows the
## count and the run ends (scored) once the last bullet resolves.
@export var ammo_limit: int = 0
## Every shot fires a full-screen LASER beam instead of a bullet (pair with a low
## fire_rate_override, e.g. 0.5 = one laser per 2 s).
@export var laser_mode: bool = false
## Every shot throws a GRENADE instead of a bullet (careful: grenade self-damage!).
@export var grenade_mode: bool = false
## Sniper-style: if a fired shot (laser) hits no monster, the player instantly dies.
@export var die_on_miss: bool = false
## Permanent player move-speed multiplier for this level/challenge (1.0 = normal).
@export var player_speed_mult: float = 1.0
## Max monsters alive at once from this level's spawn points (0 = no cap).
@export var max_active_monsters: int = 0
## Endless-style random powerup / item spawning inside this challenge (Řezník).
@export var spawn_powerups: bool = false
@export var spawn_items: bool = false
## What the top-right slot shows: "time" (default) | "ammo" | "targets".
@export var time_slot: String = "time"
## Multiplies the speed of monsters spawned by this level's spawn points.
@export var monster_speed_mult: float = 1.0
## Totem challenge: EVERY destroyed target speeds up ALL monsters by this fraction (0.01 =
## +1 % per totem). Compounds — applied to existing monsters when a totem breaks and baked
## into the speed of every monster spawned afterwards. 0 = off.
@export var monster_speedup_per_target: float = 0.0
var _target_speed_bonus: float = 1.0   ## accumulated monster-speed multiplier from destroyed targets
## EVERY monster wanders randomly (like the dasher Healers) until the player is within
## `wander_detect_radius` px, then it switches to its normal behavior.
@export var monsters_wander: bool = false
@export var wander_detect_radius: float = 480.0
## Added to the game timer for the ENDLESS spawn-rate curve (endless_spawning) — e.g.
## 180 makes monsters spawn as if the run were already 3 minutes in.
@export var endless_time_offset: float = 0.0
## Show a kill counter in the HUD's top-left corner (kill-scored challenges).
@export var show_kill_counter: bool = false
## Darkness overlay — only a circle around the player stays visible.
@export var blackout: bool = false
@export var blackout_radius: float = 280.0
## Shrinking arena: every `shrink_interval` s the playfield shrinks by `shrink_step` px
## on EACH side (black walls close in), down to the minimum size.
@export var shrink_arena: bool = false
@export var shrink_interval: float = 10.0
@export var shrink_step: float = 60.0
@export var shrink_min_width: float = 720.0
@export var shrink_min_height: float = 480.0

@export_group("Stars")
## Star scoring by survival time: the run ends on player death (leave all Goals off!)
## and the time survived earns 1-3 stars (bronze/silver/gold thresholds in seconds).
@export var stars_by_survival: bool = false
@export var star_time_1: float = 40.0   ## bronze
@export var star_time_2: float = 50.0   ## silver
@export var star_time_3: float = 60.0   ## gold
## Star scoring by kill count (e.g. limited-ammo challenges): thresholds = kills.
@export var stars_by_kills: bool = false
@export var star_kills_1: int = 15   ## bronze
@export var star_kills_2: int = 22   ## silver
@export var star_kills_3: int = 28   ## gold
## Star scoring by completion SPEED (win-based levels): stars for finishing within
## star_time_1/2/3 seconds (1 = slowest/bronze, 3 = fastest/gold).
@export var stars_by_speed: bool = false
## Star scoring by destroy-targets killed (e.g. Metin totems in the Totem challenge).
@export var stars_by_targets: bool = false
@export var star_targets_1: int = 5   ## bronze
@export var star_targets_2: int = 8   ## silver
@export var star_targets_3: int = 12  ## gold

@export_group("Meta")
## For numbered Level-mode levels (1-30): set this so the win saves the best time +
## stars to the level card and unlocks the next level. 0 = challenge / not a level.
@export var level_number: int = 0
@export var level_name: String = "Level"
## Shown on the challenge result screen.
@export_multiline var description: String = ""
## Stable id used to persist completion (challenge select screen). Empty = not tracked.
@export var challenge_id: String = ""

# ---- STATE ----
var host: Node = null          ## the game world (level host)
var _player: Node = null
var _started: bool = false
var _ended: bool = false
var _elapsed: float = 0.0
var _kills: int = 0
var _spawned_total: int = 0
var _exit_reached: bool = false
var _targets_total: int = 0     ## registered destroy-targets (e.g. Metin totems)
var _targets_done: int = 0
var _keys: Dictionary = {}
var _spawners: Array = []       ## LevelMonsterSpawn / LevelPickupSpawn that wait for begin()

func _enter_tree() -> void:
	# Register early so components querying in _ready() always find us.
	add_to_group("level_manager")

# ============================================================
# REGISTRATION (called by components in their _ready)
# ============================================================

func register_spawner(s: Node) -> void:
	if s not in _spawners:
		_spawners.append(s)

# ============================================================
# LIFECYCLE — called by the host after the level scene is loaded
# ============================================================

func begin(p_host: Node, p_player: Node) -> void:
	host = p_host
	_player = p_player
	# Optional spawn position (direct vector wins; else an optional node ref).
	if player_start_pos != Vector2.ZERO:
		_player.global_position = player_start_pos
	elif player_start and is_instance_valid(player_start):
		_player.global_position = player_start.global_position
	# Apply start conditions.
	if cap_max_hp > 0.0:
		_player.max_health = cap_max_hp
	if force_start_hp > 0.0:
		var cap: float = _player.max_health if _player.max_health > 0.0 else force_start_hp
		_player.health = minf(force_start_hp, cap)
	if cap_max_hp > 0.0 or force_start_hp > 0.0:
		_player.health_changed.emit(_player.health, _player.max_health)
	# Fire all spawners now that the host + player exist.
	for s in _spawners:
		if is_instance_valid(s) and s.has_method("do_spawn"):
			s.do_spawn()
	_started = true

func _process(delta: float) -> void:
	if not _started or _ended:
		return
	if _player and _player.is_dead:
		return
	_elapsed += delta
	_check_win()

# ============================================================
# PROGRESS HOOKS (host / components call these)
# ============================================================

func notify_monster_spawned() -> void:
	_spawned_total += 1

func notify_monster_killed() -> void:
	_kills += 1
	_check_win()

## A destroy-target (Metin totem, …) registers itself in _ready.
func register_target() -> void:
	_targets_total += 1

## A destroy-target was destroyed; counts toward the goal_clear_targets win.
func target_destroyed() -> void:
	_targets_done += 1
	if monster_speedup_per_target > 0.0:
		_target_speed_bonus *= (1.0 + monster_speedup_per_target)
	targets_changed.emit(_targets_done)   # game_world speeds up existing monsters + HUD updates

## Accumulated monster-speed multiplier from destroyed targets (1.0 = none yet).
func target_speed_bonus() -> float:
	return _target_speed_bonus
	_check_win()

func collect_key(key_id: String) -> void:
	if _keys.has(key_id):
		return
	_keys[key_id] = true
	key_collected.emit(key_id)
	_check_win()

func has_key(key_id: String) -> bool:
	return _keys.get(key_id, false)

func reach_exit() -> void:
	_exit_reached = true
	_check_win()

func elapsed() -> float:
	return _elapsed

## Stars earned so far (0-3).
## - stars_by_survival: thresholds passed by _elapsed (run ends at death)
## - stars_by_kills: kill-count thresholds (limited-ammo runs)
## - stars_by_speed: finish within star_time_3/2/1 seconds (win-based levels)
## - none: 3 for a plain win (host calls this only on win there)
func compute_stars() -> int:
	if stars_by_survival:
		var s := 0
		if _elapsed >= star_time_1: s += 1
		if _elapsed >= star_time_2: s += 1
		if _elapsed >= star_time_3: s += 1
		return s
	if stars_by_kills:
		var k := 0
		if _kills >= star_kills_1: k += 1
		if _kills >= star_kills_2: k += 1
		if _kills >= star_kills_3: k += 1
		return k
	if stars_by_targets:
		var t := 0
		if _targets_done >= star_targets_1: t += 1
		if _targets_done >= star_targets_2: t += 1
		if _targets_done >= star_targets_3: t += 1
		return t
	if stars_by_speed:
		if _elapsed <= star_time_3: return 3
		if _elapsed <= star_time_2: return 2
		# Numbered levels: simply COMPLETING the level is always at least bronze (1 star),
		# no matter how slow. (Challenges can still score 0 on a slow win.)
		if _elapsed <= star_time_1 or level_number > 0: return 1
		return 0
	return 3

# ============================================================
# WIN CHECK
# ============================================================

func _alive_monster_count() -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and (m as Monster).hp > 0.0:
			n += 1
	return n

func _check_win() -> void:
	if not _started or _ended:
		return
	# Every ENABLED goal must hold simultaneously.
	if goal_reach_exit and not _exit_reached:
		return
	if goal_survive_time and _elapsed < survive_seconds:
		return
	if goal_kill_count and _kills < kill_target:
		return
	if goal_kill_all and (_spawned_total == 0 or _alive_monster_count() > 0):
		return
	if goal_clear_targets and (_targets_total == 0 or _targets_done < _targets_total):
		return
	# Guard against a misconfigured level with zero goals (would insta-win).
	if not (goal_reach_exit or goal_survive_time or goal_kill_count or goal_kill_all or goal_clear_targets):
		return
	_win()

func _win() -> void:
	_ended = true
	level_won.emit()

## Host calls this if the level is failed by something other than player death.
func fail() -> void:
	if _ended:
		return
	_ended = true
	level_failed.emit()
