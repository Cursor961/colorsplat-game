class_name SparkTrail
extends Node2D
## Spark-style player trail: instead of a stretched ribbon (PlayerTrail), it pops small
## spark sprites behind the player that rapidly scale in and out — a shimmering "šumění"
## of sparks. Lives under GameWorld (world space) like PlayerTrail so its sparks stay put.

const SPAWN_INTERVAL := 0.035   ## seconds between spawned sparks (dense shimmer)
const SPARK_LIFE := 0.34        ## how long each spark lives
const SPARK_SIZE := 23.6        ## on-screen size of a spark at its peak (px) — 2.2x smaller
const SPREAD := 16.0            ## random offset around the player so it reads as a cloud
const MOVE_EPS := 1.5           ## px moved per frame to count as "moving" (sparks only while moving)
const TELEPORT_DIST := 120.0    ## a one-frame jump bigger than this = a respawn teleport, not movement

var _player: Node2D
var _tex: Texture2D
var _accum: float = 0.0
var _base_scale: float = 1.0
var _last_pos: Vector2 = Vector2.ZERO

func setup(player: Node2D, tex: Texture2D) -> void:
	_player = player
	_tex = tex
	z_index = 4  # above floor paint / bullets, below the player (z=5) — same as PlayerTrail
	if _tex:
		_base_scale = SPARK_SIZE / maxf(float(_tex.get_width()), 1.0)
	if player:
		_last_pos = player.global_position

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _tex == null:
		return
	# No sparks while DEAD, on a respawn TELEPORT, or while standing still — only during
	# real movement. (A death teleports the player to the start; without this the trail would
	# spark across the level.)
	var moved := _player.global_position.distance_to(_last_pos)
	_last_pos = _player.global_position
	if bool(_player.get("is_dead")) or moved > TELEPORT_DIST or moved < MOVE_EPS:
		_accum = 0.0
		return
	_accum += delta
	while _accum >= SPAWN_INTERVAL:
		_accum -= SPAWN_INTERVAL
		_spawn_spark()

## One spark: appears at the player (with a little scatter), pops UP fast then shrinks to
## nothing while fading. The fast scale-in/out is the shimmering flicker.
func _spawn_spark() -> void:
	var s := Sprite2D.new()
	s.texture = _tex
	s.top_level = true   # ignore this node's transform — the sparks stay in world space
	s.global_position = _player.global_position + Vector2(randf_range(-SPREAD, SPREAD), randf_range(-SPREAD, SPREAD))
	s.rotation = randf() * TAU
	s.scale = Vector2.ZERO
	add_child(s)

	var peak := _base_scale * randf_range(0.65, 1.05)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(peak, peak), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ZERO, SPARK_LIFE - 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "modulate:a", 0.0, SPARK_LIFE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)
