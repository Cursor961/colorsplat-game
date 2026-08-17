class_name ZoneManager
extends Node
## Manages zone spawning and lifecycle for Endless mode.
## Grid: 3 columns × 2 rows dividing the play area.
## Max 2 active zones. 3% spawn chance per second. 50/50 type split.

signal zone_spawned(zone: Zone)
signal zone_expired(zone: Zone)

# ---- GRID CONFIG ----
const GRID_COLS := 3
const GRID_ROWS := 2
const MAX_ACTIVE_ZONES := 2
const SPAWN_CHANCE_PER_SEC := 0.03  ## 3% each second

# ---- STATE ----
var is_running: bool = false
var _active_zones: Array[Zone] = []
var _occupied_cells: Array[Vector2i] = []
var _spawn_timer: float = 0.0
var _arena_size: Vector2 = Vector2(1920, 540)

## Cell size computed from arena dimensions.
var _cell_size: Vector2 = Vector2.ZERO

func setup(arena_width: float, arena_height: float) -> void:
	_arena_size = Vector2(arena_width, arena_height)
	_cell_size = Vector2(arena_width / GRID_COLS, arena_height / GRID_ROWS)

func start() -> void:
	is_running = true
	_spawn_timer = 0.0
	_active_zones.clear()
	_occupied_cells.clear()

func stop() -> void:
	is_running = false
	# Clean up existing zones
	for zone in _active_zones.duplicate():
		zone.queue_free()
	_active_zones.clear()
	_occupied_cells.clear()

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	# Stoppill: no new zones spawn while time is stopped
	if GameManager.time_stopped:
		return

	_spawn_timer += delta
	if _spawn_timer >= 1.0:
		_spawn_timer -= 1.0
		_try_spawn_zone()

## Try to spawn a zone with 3% probability.
func _try_spawn_zone() -> void:
	if _active_zones.size() >= MAX_ACTIVE_ZONES:
		return

	if randf() > SPAWN_CHANCE_PER_SEC:
		return

	# Get player position to exclude their grid cell
	var player_pos := Vector2.ZERO
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and players[0] is Node2D:
		player_pos = (players[0] as Node2D).global_position
	var player_cell := Vector2i(
		clampi(int(player_pos.x / _cell_size.x), 0, GRID_COLS - 1),
		clampi(int(player_pos.y / _cell_size.y), 0, GRID_ROWS - 1)
	)

	# Find available grid cells (not occupied and not under the player)
	var available_cells: Array[Vector2i] = []
	for col in GRID_COLS:
		for row in GRID_ROWS:
			var cell := Vector2i(col, row)
			if cell not in _occupied_cells and cell != player_cell:
				available_cells.append(cell)

	if available_cells.is_empty():
		return

	# Pick random cell
	var cell := available_cells[randi() % available_cells.size()]

	# Pick random type (50/50)
	var type: Zone.Type
	if randf() < 0.5:
		type = Zone.Type.TIMEBOOST
	else:
		type = Zone.Type.DANGER

	_spawn_zone(type, cell)

func _spawn_zone(type: Zone.Type, cell: Vector2i) -> void:
	var rect := _get_cell_rect(cell)

	var zone := Zone.new()
	zone.initialize(type, cell, rect)
	zone.expired.connect(_on_zone_expired)

	_active_zones.append(zone)
	_occupied_cells.append(cell)

	# Add zone to parent (game_world adds it as child)
	get_parent().add_child(zone)

	# Start spawn animation
	zone.start_spawn_animation()

	zone_spawned.emit(zone)

func _on_zone_expired(zone: Zone) -> void:
	_active_zones.erase(zone)
	_occupied_cells.erase(zone.grid_cell)
	zone_expired.emit(zone)

func _get_cell_rect(cell: Vector2i) -> Rect2:
	var pos := Vector2(cell.x * _cell_size.x, cell.y * _cell_size.y)
	return Rect2(pos, _cell_size)

## Called by game_world each frame to process zone effects on the player.
## Returns combined effects: { "timeboost": bool, "total_damage": float }
func process_zone_effects(player_pos: Vector2, delta: float) -> Dictionary:
	var combined := { "timeboost": false, "total_damage": 0.0 }
	for zone in _active_zones:
		var effects := zone.get_effects_for_player(player_pos, delta)
		if effects["timeboost"]:
			combined["timeboost"] = true
		combined["total_damage"] += effects["damage"]
	return combined
