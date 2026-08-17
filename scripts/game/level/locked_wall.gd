class_name LockedWall
extends LevelWall
## A wall that blocks the way until the matching key is collected, then disappears.
## Set `required_key` to a LevelKey's `key_id`. When the player collects that key,
## this wall is removed (collision off + hidden). Add your own locked-door visual.

@export var required_key: String = "key1"
## Colored lock art (lock_<color>.svg) drawn centered over the wall block.
@export_enum("blue", "green", "red") var color: String = "blue"

func _ready() -> void:
	super._ready()
	z_index = 5
	add_to_group("locks")   # so a metin can throw its key toward the matching lock
	_build_lock_visual()
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm:
		lm.key_collected.connect(_on_key_collected)
		# In case it was somehow already collected.
		if lm.has_method("has_key") and lm.has_key(required_key):
			_open()

func _build_lock_visual() -> void:
	var path := "res://assets/sprites/levels/lock_%s.svg" % color
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	var t: Vector2 = s.texture.get_size()
	var target := minf(wall_size.x, wall_size.y) * 0.8
	var sf := target / maxf(t.x, t.y)
	s.scale = Vector2(sf, sf)
	add_child(s)

func _on_key_collected(key_id: String) -> void:
	if key_id == required_key:
		_open()

func _open() -> void:
	# Disable collision immediately (deferred — physics may be flushing) and hide.
	set_deferred("collision_layer", 0)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		cs.set_deferred("disabled", true)
	# Fade out, then free.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
