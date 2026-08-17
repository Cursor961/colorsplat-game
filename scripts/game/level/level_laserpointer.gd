class_name LevelLaserPointer
extends StaticBody2D
## Stationary laser emitter. Tracks the player, charges `charge_time`, then a telegraph
## warning beam locks on, then it FIRES a kill-beam. Indestructible. Texture points UP.
## The beam is RAYCAST — it stops at the first wall and never passes through geometry.
## Heavily juiced visuals: a pulsing charge glow, a gradient/tapered beam, an additive
## glow layer behind it, and an impact flash where it lands.

const TEX := "res://assets/sprites/levels/laserpointer.svg"

@export var size: float = 110.0
@export var charge_time: float = 5.0
@export var telegraph: float = 0.8
@export var beam_half_width: float = 24.0
@export var beam_length: float = 4000.0
@export var post_time: float = 0.45        ## how long the fired beam lingers + fades
@export var startup: float = 2.0           ## idle grace after level (re)start — can't fire yet

var _t: float = 0.0
var _startup: float = 0.0
var _post: float = 0.0
var _locked: bool = false
var _fire_dir: Vector2 = Vector2.RIGHT
var _end: float = 0.0                       ## beam length to the wall this shot

var _sprite: Sprite2D
var _core: Sprite2D       ## charge glow at the emitter
var _glow: Line2D         ## wide additive glow behind the beam
var _tele_out: Line2D     ## DARK outline under the telegraph line (normal blend — reads on ice)
var _beam: Line2D         ## bright gradient beam
var _impact: Sprite2D     ## flash where the beam lands

func _ready() -> void:
	z_index = 6
	add_to_group("laserpointers")
	collision_layer = 1 | 16     # solid; NOT destructible
	collision_mask = 0
	_build_visual()
	_build_shape()
	var rad := _radial_tex()
	_core = _mk_sprite(rad, Color(1.0, 0.35, 0.25, 0.0), 7, true)
	_impact = _mk_sprite(rad, Color(1.0, 0.6, 0.3, 0.0), 9, true)
	_glow = _mk_line(beam_half_width * 2.6, _grad(Color(1.0, 0.3, 0.2, 0.0)), 8, true)
	# Telegraph outline: dark red, NORMAL blend (the additive glow disappears on bright
	# ice), drawn under the beam so the warning line has a hard readable edge everywhere.
	_tele_out = _mk_line(12.0, _grad(Color(0.30, 0.0, 0.0, 0.95)), 9, false)
	_beam = _mk_line(beam_half_width * 2.0, _beam_grad(), 9, false)
	_beam.width_curve = _taper()
	_hide_beam()
	_t = randf() * charge_time
	_startup = startup

func _physics_process(delta: float) -> void:
	if GameManager.time_stopped:
		return
	var p := get_tree().get_first_node_in_group("players")
	if p == null or p.is_dead:
		_hide_beam(); _core.modulate.a = 0.0
		return

	# Startup grace: for the first `startup` seconds after (re)spawn the laser stays idle (dim,
	# just tracking) — it can't charge or fire, so the player can't die to it right after start.
	if _startup > 0.0:
		_startup -= delta
		_t = 0.0
		var to_p: Vector2 = (p.global_position - global_position).normalized()
		if _sprite:
			_sprite.rotation = to_p.angle() + PI / 2.0
		_hide_beam()
		_core.modulate = Color(1.0, 0.6, 0.2, 0.12)
		_core.scale = Vector2.ONE * 0.4
		return

	if _post > 0.0:
		_post -= delta
		var f: float = clampf(_post / post_time, 0.0, 1.0)
		_beam.modulate.a = f
		_glow.modulate.a = f * 0.8
		_impact.modulate.a = f
		_impact.scale = Vector2.ONE * (0.7 + (1.0 - f) * 0.9)
		_core.modulate.a = f * 0.9
		_core.scale = Vector2.ONE * (1.4 - f * 0.4)
		if _post <= 0.0:
			_hide_beam(); _locked = false; _t = 0.0
		return

	_t += delta
	var to_player: Vector2 = (p.global_position - global_position).normalized()
	if _t < charge_time - telegraph:
		# CHARGING — aim tracks the player; the emitter core glow swells.
		if _sprite: _sprite.rotation = to_player.angle() + PI / 2.0
		var c: float = _t / maxf(charge_time - telegraph, 0.01)
		_core.modulate = Color(1.0, 0.8 - c * 0.4, 0.2, 0.15 + c * 0.35)
		_core.scale = Vector2.ONE * (0.4 + c * 0.6)
	elif _t < charge_time:
		# TELEGRAPH — lock the aim, show a thin pulsing warning beam to the wall.
		if not _locked:
			_locked = true
			_fire_dir = to_player
		_end = _raycast_end()
		var prog: float = (_t - (charge_time - telegraph)) / telegraph    # 0..1
		var pulse: float = 0.6 + 0.4 * sin(_t * 40.0)
		_set_beam_points(_end)
		# Punchier warning line: solid RED core over a dark outline (not the old thin
		# yellow) — reads clearly on the pale ice floor too.
		_beam.width = (5.0 + prog * 9.0) * pulse
		_beam.gradient = _grad(Color(1.0, 0.16 - prog * 0.1, 0.10, 0.95))
		_beam.modulate.a = 1.0
		_tele_out.clear_points()
		_tele_out.add_point(Vector2.ZERO)
		_tele_out.add_point(_fire_dir * _end)
		_tele_out.width = _beam.width + 8.0
		_tele_out.modulate.a = 0.95
		_glow.width = _beam.width * 2.4
		_glow.modulate.a = 0.35 * pulse
		_set_glow_points(_end)
		_core.modulate = Color(1.0, 0.5, 0.2, 0.6 + 0.3 * pulse)
		_core.scale = Vector2.ONE * (1.0 + 0.2 * pulse)
		_impact.modulate.a = 0.0
	else:
		_fire()

func _fire() -> void:
	_end = _raycast_end()
	_tele_out.modulate.a = 0.0   # warning line is done — the fired beam has its own look
	# Bright fired beam.
	_beam.width = beam_half_width * 2.0
	_beam.gradient = _beam_grad()
	_set_beam_points(_end)
	_glow.width = beam_half_width * 2.6
	_set_glow_points(_end)
	_impact.position = _fire_dir * _end
	_impact.scale = Vector2.ONE * 0.7
	_core.scale = Vector2.ONE * 1.4
	_post = post_time
	AudioManager.play_sfx("laser_shot")   # laser firing sound (was a placeholder monster_death)
	# BOSS mechanic: an arena laser whose shot crosses the FINAL BOSS chips 7% off it —
	# the player dodges so the beams hit the core. (The ray already stops AT the boss,
	# since it's on collision layer 1, so `_end` lands on its surface.)
	for bz in get_tree().get_nodes_in_group("boss"):
		if not (bz is Node2D and bz.has_method("enemy_laser_hit")):
			continue
		var brad: float = float(bz.get("size")) * 0.5
		var brel: Vector2 = (bz as Node2D).global_position - global_position
		var balong: float = brel.dot(_fire_dir)
		if balong > 0.0 and balong <= _end + brad \
		and absf(brel.cross(_fire_dir)) <= beam_half_width + brad:
			bz.enemy_laser_hit()
	# The beam also kills every MONSTER it crosses (before the wall) — the hazard cuts both
	# ways, so the player can bait monsters into the laser line.
	for m in get_tree().get_nodes_in_group("monsters"):
		if not (m is Monster):
			continue
		var mon := m as Monster
		if not mon.is_targetable() or mon.hp <= 0.0:
			continue
		var mrel: Vector2 = mon.global_position - global_position
		var malong: float = mrel.dot(_fire_dir)
		if malong > 0.0 and malong <= _end \
		and absf(mrel.cross(_fire_dir)) <= beam_half_width + mon.radius:
			mon.take_damage(999999.0)
	# Kill the player if on the beam, BEFORE the wall.
	var p := get_tree().get_first_node_in_group("players")
	if p == null or p.is_dead:
		return
	var rel: Vector2 = p.global_position - global_position
	var along: float = rel.dot(_fire_dir)
	if along <= 0.0 or along > _end:
		return
	if absf(rel.cross(_fire_dir)) <= beam_half_width + p.radius:
		p.take_zone_damage(999999.0)

## Distance from the emitter to the first wall along the locked aim (else full length).
func _raycast_end() -> float:
	var space := get_world_2d().direct_space_state
	var from: Vector2 = global_position + _fire_dir * (size * 0.5)
	var rq := PhysicsRayQueryParameters2D.create(from, global_position + _fire_dir * beam_length, 1)
	rq.exclude = [get_rid()]
	rq.collide_with_areas = false
	var hit := space.intersect_ray(rq)
	if hit:
		return maxf(global_position.distance_to(hit.position), size * 0.5)
	return beam_length

# ---------- visual helpers ----------
func _hide_beam() -> void:
	_beam.modulate.a = 0.0
	_glow.modulate.a = 0.0
	_tele_out.modulate.a = 0.0
	_impact.modulate.a = 0.0
	_core.modulate.a = 0.0

func _set_beam_points(end: float) -> void:
	_beam.clear_points(); _beam.add_point(Vector2.ZERO); _beam.add_point(_fire_dir * end)

func _set_glow_points(end: float) -> void:
	_glow.clear_points(); _glow.add_point(Vector2.ZERO); _glow.add_point(_fire_dir * end)

func _mk_line(w: float, grad: Gradient, z: int, additive: bool) -> Line2D:
	var ln := Line2D.new()
	ln.width = w
	ln.gradient = grad
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.z_index = z
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ln.material = mat
	add_child(ln)
	return ln

func _mk_sprite(tex: Texture2D, col: Color, z: int, additive: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.modulate = col
	s.z_index = z
	s.scale = Vector2.ONE
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
	add_child(s)
	return s

func _grad(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g

func _beam_grad() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1.0))             # white-hot at the muzzle
	g.add_point(0.12, Color(1.0, 0.55, 0.35, 0.95))
	g.add_point(0.6, Color(1.0, 0.25, 0.18, 0.7))
	g.set_color(1, Color(1.0, 0.12, 0.1, 0.0))       # fade to nothing at the far end
	return g

func _taper() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.85, 1.0))
	c.add_point(Vector2(1.0, 0.45))
	return c

func _radial_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	return gt

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	var t: Vector2 = _sprite.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	_sprite.scale = Vector2(sf, sf)
	_sprite.z_index = 6
	add_child(_sprite)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size * 0.40
	cs.shape = c
	add_child(cs)
