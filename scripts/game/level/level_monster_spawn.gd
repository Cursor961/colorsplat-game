class_name LevelMonsterSpawn
extends Node2D
## A monster spawn point. Place it where you want monsters to appear. On level start
## it spawns `count` monsters of `monster_type` scattered within `spread` px. Set
## `repeat` to keep spawning waves on an interval (great for survive challenges).

@export var monster_type: MonsterTypes.Type = MonsterTypes.Type.BASIC
@export var count: int = 1
@export var spread: float = 40.0
## Spawn just off the left/right arena edge (random side + Y) instead of at this node —
## monsters then drive in from the side. Great for survive/dodge challenges.
@export var from_random_side: bool = false
## Like from_random_side but ALL FOUR edges (top/bottom too) — surround the player.
@export var from_random_edge: bool = false
## Delay (s) after level start before the first spawn.
@export var start_delay: float = 0.0
@export_group("Repeat")
@export var repeat: bool = false
@export var repeat_interval: float = 5.0
## 0 = infinite repeats; otherwise stop after this many extra waves.
@export var repeat_max: int = 0
## Stop spawning after this many seconds of level time (0 = never).
@export var stop_after: float = 0.0

var _lm: Node = null
var _active: bool = false
var _timer: float = 0.0
var _waves_done: int = 0
var _elapsed_total: float = 0.0

func _ready() -> void:
	_lm = get_tree().get_first_node_in_group("level_manager")
	if _lm and _lm.has_method("register_spawner"):
		_lm.register_spawner(self)

## Called by LevelManager.begin().
func do_spawn() -> void:
	_active = true
	_timer = start_delay
	if start_delay <= 0.0:
		_spawn_wave()
		_timer = repeat_interval

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed_total += delta
	if stop_after > 0.0 and _elapsed_total >= stop_after:
		_active = false
		return
	_timer -= delta
	if _timer <= 0.0:
		if _waves_done == 0 and start_delay > 0.0:
			# First (delayed) wave.
			_spawn_wave()
			_timer = repeat_interval
		elif repeat and (repeat_max == 0 or _waves_done <= repeat_max):
			_spawn_wave()
			_timer = repeat_interval
		else:
			_active = false

func _spawn_wave() -> void:
	_waves_done += 1
	if _lm and _lm.host and _lm.host.has_method("level_spawn_monster"):
		var pos := global_position
		if from_random_edge:
			var aw: float = _lm.host.arena_width
			var ah: float = _lm.host.arena_height
			var off := 130.0
			match randi() % 4:
				0: pos = Vector2(-off, randf_range(ah * 0.1, ah * 0.9))            # left
				1: pos = Vector2(aw + off, randf_range(ah * 0.1, ah * 0.9))        # right
				2: pos = Vector2(randf_range(aw * 0.1, aw * 0.9), -off)            # top
				_: pos = Vector2(randf_range(aw * 0.1, aw * 0.9), ah + off)        # bottom
		elif from_random_side:
			var aw: float = _lm.host.arena_width
			var ah: float = _lm.host.arena_height
			var off := 130.0
			pos = Vector2(-off if randf() < 0.5 else aw + off, randf_range(ah * 0.15, ah * 0.85))
		# 0.2s scale-in (0 → full size) instead of standing still at full size on level load.
		_lm.host.level_spawn_monster(monster_type, pos, count, spread, 0.2)
