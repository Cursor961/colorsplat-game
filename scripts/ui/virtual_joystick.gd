class_name TouchJoystick
extends Control
## Mobile virtual joystick - floating style.
## (Renamed from VirtualJoystick — Godot 4.7 added a native class of that name.)
## Appears at touch position, knob follows finger.
## Returns normalized Vector2 direction.

signal joystick_input(direction: Vector2)

@export var joystick_radius: float = 80.0    ## Max distance knob can travel from center
@export var dead_zone: float = 0.15           ## Input below this is ignored (0-1)
@export var base_color: Color = Color(1, 1, 1, 0.3)
@export var knob_color: Color = Color(1, 1, 1, 0.6)
@export var knob_radius: float = 30.0

var _is_active: bool = false
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO

## Which half of screen this joystick listens to.
## "left" for movement, "right" for aiming.
@export_enum("left", "right") var side: String = "left"

## Optional SVG textures (loaded from SpriteLoader). Falls back to procedural draw.
var _base_texture: Texture2D = null
var _knob_texture: Texture2D = null

var _base_joystick_radius: float = 0.0  ## unscaled design values (for live rescale)
var _base_knob_radius: float = 0.0

func _ready() -> void:
	# Scale joystick sizes to viewport (+ the game-GUI setting)
	_base_joystick_radius = joystick_radius
	_base_knob_radius = knob_radius
	rescale_live()

	# Invisible until touch
	_is_active = false
	# Try loading SVG joystick textures
	_base_texture = SpriteLoader.get_joystick_base_texture()
	_knob_texture = SpriteLoader.get_joystick_knob_texture()

## (Re)apply the game-GUI scale — also called live from settings Apply in-game.
func rescale_live() -> void:
	var sf := SaveManager.ui_sf_game(get_viewport().get_visible_rect().size)
	joystick_radius = _base_joystick_radius * sf
	knob_radius = _base_knob_radius * sf

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			# Check if touch is on our side
			var screen_center := get_viewport_rect().size.x / 2.0
			var is_left := touch.position.x < screen_center
			if (side == "left" and is_left) or (side == "right" and not is_left):
				if _touch_index == -1:  # Not already tracking a touch
					_touch_index = touch.index
					_center = touch.position
					_knob_pos = touch.position
					_is_active = true
					queue_redraw()
		else:
			if touch.index == _touch_index:
				_release()

	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index and _is_active:
			var diff := drag.position - _center
			if diff.length() > joystick_radius:
				diff = diff.normalized() * joystick_radius
			_knob_pos = _center + diff

			# Calculate normalized output
			_output = diff / joystick_radius
			if _output.length() < dead_zone:
				_output = Vector2.ZERO

			joystick_input.emit(_output)
			queue_redraw()

func _release() -> void:
	_touch_index = -1
	_is_active = false
	_output = Vector2.ZERO
	joystick_input.emit(Vector2.ZERO)
	queue_redraw()

func get_direction() -> Vector2:
	return _output

func _draw() -> void:
	if not _is_active:
		return

	if _base_texture and _knob_texture:
		# Draw SVG-based joystick
		var base_size := _base_texture.get_size()
		var base_scale := (joystick_radius * 2.0) / maxf(base_size.x, base_size.y)
		var base_rect := Rect2(
			_center - base_size * base_scale * 0.5,
			base_size * base_scale
		)
		draw_texture_rect(_base_texture, base_rect, false, base_color)

		var knob_size := _knob_texture.get_size()
		var knob_scale := (knob_radius * 2.0) / maxf(knob_size.x, knob_size.y)
		var knob_rect := Rect2(
			_knob_pos - knob_size * knob_scale * 0.5,
			knob_size * knob_scale
		)
		draw_texture_rect(_knob_texture, knob_rect, false, knob_color)
	else:
		# Fallback: procedural draw
		draw_circle(_center, joystick_radius, base_color)
		draw_arc(_center, joystick_radius, 0, TAU, 64, Color(1, 1, 1, 0.2), 2.0)
		draw_circle(_knob_pos, knob_radius, knob_color)
