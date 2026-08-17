class_name LevelTutorialPointer
extends Node2D
## A tutorial pointer/hand that draws the player's eye to something (a door, a pad…).
## Gently bobs. Purely decorative. `angle_deg` rotates it to point where you need.

const TEX := "res://assets/sprites/levels/tutorial_pointer.svg"

@export var size: float = 140.0
@export var angle_deg: float = 0.0
@export var bob: float = 14.0      ## px of idle bob (0 = none)

func _ready() -> void:
	z_index = 4                     # above the floor/pickups so the hint stands out
	if not ResourceLoader.exists(TEX):
		return
	var s := Sprite2D.new()
	s.texture = load(TEX)
	var t := s.texture.get_size()
	if size > 0.0 and t.x > 0.0 and t.y > 0.0:
		var sf := size / maxf(t.x, t.y)
		s.scale = Vector2(sf, sf)
	s.rotation = deg_to_rad(angle_deg)
	add_child(s)
	if bob > 0.0:
		var tw := create_tween().set_loops()
		tw.tween_property(s, "position", Vector2(0.0, -bob), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
