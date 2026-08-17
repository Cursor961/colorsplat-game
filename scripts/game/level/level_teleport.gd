class_name LevelTeleport
extends Area2D
## An animated teleport pad. When the player steps on it, they are moved to `target`
## (the paired teleport). Place a GREEN and a PINK and point each one's `target` at the
## other — they portal between each other. Visual = the looped SVG sequence (32 fps).

## The destination node (drag the paired teleport here in the Inspector).
@export var target: Node2D
@export_enum("green", "pink") var color: String = "green"
## Small portal — ~15% bigger than the player's visible art; matches the exit. Tweak together.
@export var size: float = 55.0
@export var pad_radius: float = 26.0
## Seconds a freshly-teleported player is immune to teleports (avoids bouncing).
@export var arrival_cooldown: float = 0.6
## Grace after the level (re)loads before this pad can fire. Fixes the bug where a player who
## died on/near a pad was instantly teleported again the moment the level restarted (the fresh
## pad fired on the just-placed player before they'd settled at the start).
@export var startup_grace: float = 0.7

## Warp juice: the crossing itself is INSTANT and momentum-preserving (seamless), so the
## visuals must never block movement — the player is squeezed thin for a moment and pops back
## out while still travelling at full speed.
const SQUEEZE_SCALE := 0.35   ## how thin the crossing squeezes the player
const POP_TIME := 0.22        ## how long the pop back to full size takes

var _cooldown: float = 0.0
var _anim: AnimatedSprite2D                  ## the looping portal art (surges on a warp)
var _anim_base_scale: Vector2 = Vector2.ONE  ## resting scale of `_anim`
var _surge_tw: Tween
var _warp_tw: Tween                          ## the player's squeeze → pop tween

func _ready() -> void:
	z_index = 3                 # above the floor, below the player
	add_to_group("teleports")
	collision_layer = 0
	collision_mask = 2          # detect the player
	_cooldown = startup_grace   # don't teleport anyone during the level's first moments
	_build_glow()
	_anim = TeleportAnim.make_sprite(color, size)
	_anim_base_scale = _anim.scale
	add_child(_anim)
	_build_shape()
	body_entered.connect(_on_body_entered)
	# If not linked in the Inspector, auto-pair with the nearest SAME-colour teleport. Each
	# colour is its own independent pair (green↔green, pink↔pink), so a map can have TWO
	# separate teleport routes at once (a green pair + a pink pair).
	if target == null:
		call_deferred("_auto_pair")

func _auto_pair() -> void:
	if target != null and is_instance_valid(target):
		return
	var want := color
	var best: LevelTeleport = null
	var best_d := INF
	for t in get_tree().get_nodes_in_group("teleports"):
		if t == self or not t is LevelTeleport:
			continue
		var tp := t as LevelTeleport
		if tp.color == want:
			var d := global_position.distance_squared_to(tp.global_position)
			if d < best_d:
				best_d = d
				best = tp
	if best:
		target = best
		if best.target == null:
			best.target = self

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

## Pulsing radial glow (additive) behind the portal, tinted to its colour.
func _build_glow() -> void:
	var col: Color = Color(0.25, 1.0, 0.5) if color == "green" else Color(1.0, 0.35, 0.85)
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.85))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 96
	gt.height = 96
	var glow := Sprite2D.new()
	glow.texture = gt
	glow.z_index = -1                     # behind the animated portal art
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	var base: float = size * 2.7 / 96.0
	glow.scale = Vector2(base, base)
	glow.modulate.a = 0.55
	add_child(glow)
	# Breathing pulse: scale + alpha in/out forever.
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "scale", Vector2(base * 1.3, base * 1.3), 0.85).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(glow, "modulate:a", 0.9, 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "scale", Vector2(base, base), 0.85).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(glow, "modulate:a", 0.4, 0.85).set_trans(Tween.TRANS_SINE)

func _build_shape() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var c := CircleShape2D.new()
	c.radius = pad_radius
	cs.shape = c

func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0 or target == null or not is_instance_valid(target):
		return
	if not body.is_in_group("players"):
		return
	if "is_dead" in body and body.is_dead:
		return   # never teleport a dead/respawning player
	# ---- SEAMLESS CROSSING: instant, momentum-preserving. No centre-snap, no pause. ----
	# Direction of travel decides where they come out. If they were standing still on the pad,
	# fall back to the radial direction they're sitting at.
	var vel := Vector2.ZERO
	if "velocity" in body:
		vel = body.velocity
	var dir := vel
	if dir.length() < 1.0:
		dir = body.global_position - global_position
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	# Emerge just past the far pad's edge, still heading the same way — mirrors how deep they
	# were into THIS pad, so the crossing reads as one continuous movement rather than a jump
	# to the middle of the portal. Landing outside the pad also means it can't re-trigger.
	body.global_position = target.global_position + dir * (pad_radius + 4.0)
	if "velocity" in body:
		body.velocity = vel               # momentum carries through completely untouched
	# Block the destination pad from throwing them straight back if they turn around.
	_cooldown = arrival_cooldown
	if target is LevelTeleport:
		(target as LevelTeleport)._cooldown = arrival_cooldown

	# ---- Juice (all non-blocking — the player never stops moving) ----
	_surge()
	_ring(false)                          # ring COLLAPSING inward = swallowed here
	if target is LevelTeleport:
		var d := target as LevelTeleport
		d._surge()
		d._ring(true)                     # ring BURSTING outward = spat out there
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw and "particles" in gw and gw.particles:
		gw.particles.spawn_impact_particles(target.global_position, _tint(), 12)
	# Squeeze-through pop: thin for an instant, then springs back — runs WHILE they keep moving.
	# `teleport_scale` multiplies into the player's squash system (see player.gd) so it composes
	# with the normal squash-and-stretch instead of being overwritten by it every frame.
	if "teleport_scale" in body:
		if _warp_tw and _warp_tw.is_valid():
			_warp_tw.kill()
		body.teleport_scale = SQUEEZE_SCALE
		_warp_tw = body.create_tween()
		_warp_tw.tween_property(body, "teleport_scale", 1.0, POP_TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("portal", 2.0)  # 2x louder (the source wav is quiet)

## This pad's colour tint (green vs pink).
func _tint() -> Color:
	return Color(0.25, 1.0, 0.5) if color == "green" else Color(1.0, 0.35, 0.85)

## The looped portal art reacts to a warp: the spin surges and the disc punches bigger, then
## springs back — reads as the portal "firing" without disturbing the looping animation itself.
func _surge() -> void:
	if _anim == null or not is_instance_valid(_anim):
		return
	if _surge_tw and _surge_tw.is_valid():
		_surge_tw.kill()
	_anim.speed_scale = 4.0
	_anim.scale = _anim_base_scale * 1.35
	_surge_tw = create_tween()
	_surge_tw.set_parallel(true)
	_surge_tw.tween_property(_anim, "scale", _anim_base_scale, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_surge_tw.tween_property(_anim, "speed_scale", 1.0, 0.5).set_ease(Tween.EASE_OUT)

## Additive energy ring on the pad. `expanding` = burst outward (spit out), otherwise it
## collapses inward (sucked in). Lives on the pad itself, which never gets freed.
func _ring(expanding: bool) -> void:
	var col := _tint()
	var ring := Line2D.new()
	ring.width = maxf(3.0, size * 0.10)
	ring.default_color = Color(col.r, col.g, col.b, 0.9)
	var pts := PackedVector2Array()
	var rr: float = size * 0.5
	for i in 29:                              # 28 segments + a repeat of the first point = closed loop
		var a: float = TAU * float(i % 28) / 28.0
		pts.append(Vector2(cos(a), sin(a)) * rr)
	ring.points = pts
	ring.z_index = 6                          # above the portal art, below the player
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	ring.scale = Vector2(0.25, 0.25) if expanding else Vector2(2.4, 2.4)
	add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4) if expanding else Vector2(0.15, 0.15), 0.38) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.38)
	tw.chain().tween_callback(ring.queue_free)
