class_name PlayerIndicator
extends Node2D
## Accessibility marker: a bright pulsing ring drawn around the player so they
## stay easy to find when the floor is covered in paint splats. Toggled by the
## "player_indicator" setting. Added as a child of the player; drawn behind the
## player sprite (negative z) so it haloes the player.

@export var base_radius: float = 30.0
var ring_color: Color = Color(0.15, 1.0, 1.0)  ## set from the "indicator_color" setting

var _t: float = 0.0

func _ready() -> void:
	z_index = -1  # behind the player sprite (relative to the player node)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + 0.12 * sin(_t * 4.0)
	var r := base_radius * pulse
	# Dark outline ring for contrast against any background.
	draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 48, Color(0, 0, 0, 0.75), 8.0, true)
	# Bright ring in the player's chosen color — high contrast over splats.
	var c := ring_color
	c.a = 0.95
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 4.5, true)
