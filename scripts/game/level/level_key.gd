class_name LevelKey
extends Area2D
## A key pickup. When the player touches it, the matching LockedWall(s) open and it
## counts toward the "collect all keys" idea. Set `key_id` to match a LockedWall's
## `required_key`. Add your own key visual as a child Sprite2D.

@export var key_id: String = "key1"
@export var pickup_radius: float = 44.0
## Colored key art (key_<color>.svg) + a gentle bob. Set required_key on the matching
## LockedWall to this key's key_id (commonly the same colour word).
@export_enum("blue", "green", "red") var color: String = "blue"
@export var size: float = 72.0

func _ready() -> void:
	z_index = 4
	collision_layer = 0
	collision_mask = 2          # detect the player (player is on layer 2)
	_build_visual()
	_build_shape()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	var path := "res://assets/sprites/levels/key_%s.svg" % color
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	var t: Vector2 = s.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	s.scale = Vector2(sf, sf)
	add_child(s)
	# Gentle idle bob so keys read as pickups.
	var tw := create_tween().set_loops()
	tw.tween_property(s, "position:y", -8.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

func _build_shape() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var c := CircleShape2D.new()
	c.radius = pickup_radius
	cs.shape = c

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm:
		lm.collect_key(key_id)
	AudioManager.play_sfx("powerup_pickup")
	# Small pop, then free.
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.4, 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
