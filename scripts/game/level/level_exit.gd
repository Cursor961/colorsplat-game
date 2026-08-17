class_name LevelExit
extends Area2D
## The level-end goal — the animated BLUE teleport. When the player reaches it the
## "reach exit" goal is satisfied and the level is won (result screen: time + stars +
## menu / next level). Optionally require all monsters dead first.

## Small portal — ~15% bigger than the player's VISIBLE art (~44 px). Exit + teleports
## share this size on purpose. Tweak both together if the portals should read bigger.
@export var exit_size: Vector2 = Vector2(55, 55)
## If true, the exit only counts once every monster is dead.
@export var require_all_enemies_dead: bool = false

func _ready() -> void:
	z_index = 3
	collision_layer = 0
	collision_mask = 2          # detect the player
	_build_glow()               # pulsing halo BEHIND the portal
	_build_visual()
	_build_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _build_visual() -> void:
	# Animated blue goal portal (looped sequence).
	add_child(TeleportAnim.make_sprite("blue", maxf(exit_size.x, exit_size.y)))

## Soft cyan-blue glow that breathes (scale + alpha) so the goal reads as inviting.
func _build_glow() -> void:
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = _make_radial_glow()
	glow.centered = true
	var d := maxf(exit_size.x, exit_size.y) * 2.4   # halo extends past the portal
	var t: Vector2 = glow.texture.get_size()
	glow.scale = Vector2(d / t.x, d / t.y)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # additive = light, not a flat disc
	glow.material = mat
	glow.modulate = Color(0.35, 0.65, 1.0, 0.5)
	glow.z_index = -1                                    # behind the portal anim
	add_child(glow)
	var base := glow.scale
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "scale", base * 1.18, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(glow, "modulate:a", 0.85, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "scale", base, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(glow, "modulate:a", 0.4, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## A soft white radial gradient (centre opaque → transparent edge), tinted via modulate.
func _make_radial_glow() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	return gt

func _build_shape() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var rect := RectangleShape2D.new()
	rect.size = exit_size
	cs.shape = rect

var _player_inside: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		_player_inside = true
		_try_reach()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		_player_inside = false

func _process(_delta: float) -> void:
	# Re-check while standing on the pad so the last kill (require-all-dead) still wins.
	if _player_inside:
		_try_reach()

func _try_reach() -> void:
	# Re-validate the player is GENUINELY on the pad. On Retry the level layout (and this
	# Exit) is re-added in the same frame the player is repositioned, and Area2D can emit a
	# stale body_entered for the player's previous (exit) position → a spurious insta-win.
	var p := get_tree().get_first_node_in_group("players") as Node2D
	if p == null or p.global_position.distance_to(global_position) > maxf(exit_size.x, exit_size.y):
		_player_inside = false
		return
	if require_all_enemies_dead and _enemies_alive():
		return
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm:
		lm.reach_exit()

func _enemies_alive() -> bool:
	for m in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and (m as Monster).hp > 0.0:
			return true
	return false
