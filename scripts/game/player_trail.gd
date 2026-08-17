class_name PlayerTrail
extends Line2D
## Textured trail that follows the player — a chain of points that lag behind the
## player and ease toward the one ahead (ported from the rainbow-cursor logic:
## each particle follows the next with a `trail_speed` factor). Rendered as a
## tapering, fading ribbon using the equipped trail's SVG texture.
##
## Lives under GameWorld (NOT the player) so its points are in world space.

const TRAIL_LENGTH := 24       ## number of chain points
const TRAIL_SPEED := 0.5       ## catch-up factor per 1/60s (higher = tighter)
const TRAIL_WIDTH := 24.0   ## slimmer so it tucks fully under the player (no edges poking out at spawn)

var _player: Node2D
var _pts: Array[Vector2] = []

func setup(player: Node2D, tex: Texture2D) -> void:
	_player = player
	texture = tex
	texture_mode = Line2D.LINE_TEXTURE_STRETCH
	width = TRAIL_WIDTH
	default_color = Color.WHITE
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	z_index = 4  # above floor paint / bullets, below the player (z=5)

	# Taper from full width at the head to thin at the tail.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	width_curve = curve

	# Fade out toward the tail.
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	gradient = grad

	var p := _player.global_position
	_pts.clear()
	for _i in TRAIL_LENGTH:
		_pts.append(p)
	points = PackedVector2Array(_pts)

const TELEPORT_DIST := 120.0   ## a one-frame jump bigger than this = a respawn teleport, not real movement

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pos := _player.global_position
	# Player dead, OR teleported (level respawn): hide + SNAP the whole ribbon onto the player
	# so it never draws a streak from the death spot to the start. It reappears once the player
	# is alive and moving normally again.
	if bool(_player.get("is_dead")) or _pts[0].distance_to(pos) > TELEPORT_DIST:
		for i in _pts.size():
			_pts[i] = pos
		points = PackedVector2Array(_pts)
		visible = not bool(_player.get("is_dead"))
		return
	visible = true
	_pts[0] = pos
	var t := clampf(TRAIL_SPEED * delta * 60.0, 0.0, 1.0)
	for i in range(1, _pts.size()):
		_pts[i] = _pts[i].lerp(_pts[i - 1], t)
	points = PackedVector2Array(_pts)
