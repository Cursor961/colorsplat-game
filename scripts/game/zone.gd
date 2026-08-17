class_name Zone
extends Node2D
## A gameplay zone (Timeboost or Danger) that occupies one grid cell.
## Draws an animated dashed border, shows a countdown timer,
## and applies effects to the player while inside.

signal expired(zone: Zone)

enum Type { TIMEBOOST, DANGER }

# ---- CONFIG ----
const UIT := preload("res://scripts/utils/ui_theme.gd")
var zone_type: Type = Type.TIMEBOOST
var grid_cell: Vector2i = Vector2i.ZERO  ## Which grid cell this zone occupies
var cell_rect: Rect2 = Rect2()           ## World-space rect of the grid cell
const ZONE_DURATION := 20.0             ## Seconds before zone expires
const DANGER_DPS_FRACTION := 0.07       ## Damage/sec as FRACTION of player max HP (7%)
const TIMEBOOST_MULT := 2.0             ## Timer multiplier for timeboost

# ---- STATE ----
var time_remaining: float = ZONE_DURATION
var is_active: bool = false              ## True after spawn animation finishes
var _player_inside: bool = false
var player_time_inside: float = 0.0  ## Total seconds player has spent inside this zone
var _spawn_animating: bool = false
var _despawn_animating: bool = false

# ---- ANIMATED BORDER ----
var _dash_offset: float = 0.0
const DASH_LENGTH := 20.0
const GAP_LENGTH := 12.0
const BORDER_WIDTH := 4.0
const DASH_SPEED := 60.0  ## px/s — how fast dashes march around the perimeter

# ---- VISUALS ----
var _zone_sprite: Sprite2D
var _timer_label: Label
var _lilita_font: Font

# ---- COLORS ----
var _border_color: Color
var _bg_color: Color

func _ready() -> void:
	z_index = 1  ## Below paint (z=2), player (z=5), monsters (z=6)
	# Load font
	_lilita_font = UIT.load_font()

	# Set colors based on type
	match zone_type:
		Type.TIMEBOOST:
			_border_color = Color(0.0, 0.235, 0.0)  # Dark green (rgb(0,60,0))
			_bg_color = Color(0.051, 1.0, 0.133, 0.25)  # Green 25% opacity
		Type.DANGER:
			_border_color = Color(0.4, 0.0, 0.0)  # Dark red (rgb(102,0,0))
			_bg_color = Color(0.9, 0.0, 0.0, 0.25)  # Red 25% opacity

	_setup_visuals()

func initialize(type: Type, cell: Vector2i, rect: Rect2) -> void:
	zone_type = type
	grid_cell = cell
	cell_rect = rect
	global_position = rect.position + rect.size / 2.0  # Center of cell

func _setup_visuals() -> void:
	# Load zone texture
	var tex_path: String
	match zone_type:
		Type.TIMEBOOST:
			tex_path = "res://assets/sprites/zones/timeboost.svg"
		Type.DANGER:
			tex_path = "res://assets/sprites/zones/dangerzone.svg"

	if ResourceLoader.exists(tex_path):
		_zone_sprite = Sprite2D.new()
		_zone_sprite.texture = load(tex_path)
		# Scale sprite to fill cell rect
		var tex_size := _zone_sprite.texture.get_size()
		var sf := Vector2(cell_rect.size.x / tex_size.x, cell_rect.size.y / tex_size.y)
		_zone_sprite.scale = sf
		add_child(_zone_sprite)

	# Timer label — top right corner of zone
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if _lilita_font:
		_timer_label.add_theme_font_override("font", _lilita_font)
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_constant_override("outline_size", 4)
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	match zone_type:
		Type.TIMEBOOST:
			_timer_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.133))
		Type.DANGER:
			_timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	# Position at top-right of zone (zone is centered at origin, cell_rect.size / 2 offset)
	_timer_label.position = Vector2(cell_rect.size.x / 2.0 - 90, -cell_rect.size.y / 2.0 + 8)
	_timer_label.size = Vector2(80, 30)
	_update_timer_text()
	add_child(_timer_label)

func _update_timer_text() -> void:
	if _timer_label:
		var secs := int(ceil(time_remaining))
		_timer_label.text = "%ds" % secs

func start_spawn_animation() -> void:
	_spawn_animating = true
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(_on_spawn_complete)

func _on_spawn_complete() -> void:
	_spawn_animating = false
	is_active = true

func start_despawn_animation() -> void:
	is_active = false
	_despawn_animating = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(_on_despawn_complete)

func _on_despawn_complete() -> void:
	_despawn_animating = false
	expired.emit(self)
	queue_free()

func _process(delta: float) -> void:
	# Animate dashes (keep visual animation even when time stopped)
	_dash_offset += DASH_SPEED * delta
	var perimeter := 2.0 * (cell_rect.size.x + cell_rect.size.y)
	if _dash_offset > perimeter:
		_dash_offset -= perimeter
	queue_redraw()

	if not is_active:
		return

	# Stoppill: freeze zone countdown (zone stays alive but timer paused)
	if GameManager.time_stopped:
		return

	# Countdown timer
	time_remaining -= delta
	_update_timer_text()

	if time_remaining <= 0.0:
		time_remaining = 0.0
		start_despawn_animation()
		return

## Check if a position is inside this zone.
func is_point_inside(pos: Vector2) -> bool:
	return cell_rect.has_point(pos)

## Called by game_world each frame for the player.
## Returns a dictionary with effects to apply:
## { "timeboost": bool, "damage": float }
func get_effects_for_player(player_pos: Vector2, delta: float) -> Dictionary:
	var effects := { "timeboost": false, "damage": 0.0 }
	if not is_active:
		return effects

	_player_inside = cell_rect.has_point(player_pos)

	if not _player_inside:
		return effects

	# Track cumulative time player is inside this zone
	player_time_inside += delta

	match zone_type:
		Type.TIMEBOOST:
			effects["timeboost"] = true
		Type.DANGER:
			# Damage as a FRACTION of player max HP per second (resolved by game_world).
			effects["damage"] = DANGER_DPS_FRACTION * delta

	return effects

func _draw() -> void:
	if _despawn_animating and scale.length() < 0.01:
		return
	_draw_animated_border()

func _draw_animated_border() -> void:
	# Draw dashed rectangle border around the zone
	var half_size := cell_rect.size / 2.0
	var rect_local := Rect2(-half_size, cell_rect.size)

	# Build perimeter segments: top → right → bottom → left
	var corners: Array[Vector2] = [
		rect_local.position,                                              # top-left
		Vector2(rect_local.position.x + rect_local.size.x, rect_local.position.y),  # top-right
		rect_local.position + rect_local.size,                            # bottom-right
		Vector2(rect_local.position.x, rect_local.position.y + rect_local.size.y),  # bottom-left
	]

	# Total perimeter
	var perimeter := 2.0 * (cell_rect.size.x + cell_rect.size.y)
	var dash_cycle := DASH_LENGTH + GAP_LENGTH

	# Walk around perimeter drawing dashes
	var edge_lengths: Array[float] = [
		cell_rect.size.x, cell_rect.size.y,
		cell_rect.size.x, cell_rect.size.y
	]

	var pos_along_perimeter := -fmod(_dash_offset, dash_cycle)

	var edge_start := 0.0
	for edge_idx in 4:
		var start_corner: Vector2 = corners[edge_idx]
		var end_corner: Vector2 = corners[(edge_idx + 1) % 4]
		var edge_len: float = edge_lengths[edge_idx]
		var edge_end := edge_start + edge_len

		# Direction along this edge
		var dir := (end_corner - start_corner).normalized()

		# Find dashes that overlap this edge
		var cursor := pos_along_perimeter
		while cursor < edge_end:
			var dash_start := cursor
			var dash_end := cursor + DASH_LENGTH

			# Clip to this edge
			var seg_start := maxf(dash_start, edge_start)
			var seg_end := minf(dash_end, edge_end)

			if seg_start < seg_end:
				var local_start := seg_start - edge_start
				var local_end := seg_end - edge_start
				var p1 := start_corner + dir * local_start
				var p2 := start_corner + dir * local_end
				draw_line(p1, p2, _border_color, BORDER_WIDTH)

			cursor += dash_cycle

		edge_start = edge_end
