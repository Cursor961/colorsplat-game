class_name LevelWall
extends StaticBody2D
## A solid wall segment. Blocks the player AND monsters, and stops bullets.
## Collision layer 1|4 (player mask=1, monster mask=4 both collide) + "walls" group
## (bullets detect it). The arena boundary stays on layer 1 only, so this does NOT
## affect endless-mode spawn-in.
##
## Set `wall_size` to the block's pixel size; add your own Sprite2D / NinePatchRect
## child for the visual (sized to match). The collision box is built in code.

@export var wall_size: Vector2 = Vector2(240, 48)
## Drawn block colours — full-black by default; a subtle border defines edges. Set
## border_color alpha to 0 for pure black, or drop in a child Sprite2D for a texture.
@export var fill_color: Color = Color(0, 0, 0)
@export var border_color: Color = Color(0.10, 0.10, 0.13)

func _ready() -> void:
	z_index = 2
	add_to_group("walls")
	# Layer 1 = blocks the player; bit 16 = blocks monsters (monsters mask 16, NOT each
	# other); 4 kept so bullets (mask incl. 4) still register a wall hit.
	collision_layer = 1 | 4 | 16
	collision_mask = 0
	_build_shape()
	queue_redraw()

## Simple visible block so corridors/barriers aren't invisible. Level authors can hide
## this (modulate) and add their own wall texture as a child Sprite2D if they prefer.
func _draw() -> void:
	var hs := wall_size * 0.5
	draw_rect(Rect2(-hs, wall_size), fill_color, true)
	if border_color.a > 0.0:
		draw_rect(Rect2(-hs, wall_size), border_color, false, 3.0)

func _build_shape() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var rect := RectangleShape2D.new()
	rect.size = wall_size
	cs.shape = rect
