class_name LevelControlsHint
extends Node2D
## Tutorial controls overlay (the dual-joystick layout hint). Picks the LEFT or RIGHT
## image automatically from the player's control setting: default = RIGHT, left-handed
## mode = LEFT. Purely decorative — place it on the floor of a tutorial level (e.g. lvl 1).

const TEX_RIGHT := "res://assets/sprites/levels/level1_controlsright.svg"
const TEX_LEFT := "res://assets/sprites/levels/level1_controlsleft.svg"

@export var size: float = 0.0      ## 0 = native texture size; else scale so art ≈ size px
@export var opacity: float = 0.85

func _ready() -> void:
	z_index = 2                     # on the floor, under entities
	var path := TEX_LEFT if SaveManager.is_left_handed() else TEX_RIGHT
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	if size > 0.0:
		var t := s.texture.get_size()
		var sf := size / maxf(t.x, t.y)
		s.scale = Vector2(sf, sf)
	s.modulate.a = clampf(opacity, 0.0, 1.0)
	add_child(s)
