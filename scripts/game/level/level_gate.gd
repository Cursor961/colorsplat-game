class_name LevelGate
extends LevelWall
## A wall-block "door" that opens when a LevelButton with the matching `gate_id` is pressed.
## Tinted blue so it reads as a door, not a permanent wall.

@export var gate_id: String = "1"

func _ready() -> void:
	fill_color = Color(0.10, 0.15, 0.30)
	border_color = Color(0.35, 0.55, 0.95)
	super._ready()
	add_to_group("gate_" + gate_id)

func open() -> void:
	set_deferred("collision_layer", 0)   # stop blocking
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
