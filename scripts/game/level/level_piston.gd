class_name LevelPiston
extends Area2D
## Wall-to-wall crusher. A deadly head slams out `extend_len` px in `extend_dir_deg`,
## holds, then retracts — on a loop. Instant death on contact while it's out (1 HP).
## Place it flush against a wall; it shoots across the corridor to the opposite wall.

const TEX := "res://assets/sprites/levels/piston.svg"

@export var size: float = 84.0             ## head thickness
@export var extend_dir_deg: float = 90.0   ## 0=right, 90=down, -90=up, 180=left
@export var extend_len: float = 384.0      ## reach (to the opposite wall)
@export var base_inset: float = 30.0       ## px the base sits inside the anchor wall (= generator PIST_MARGIN)
@export var cycle: float = 2.6             ## full period
@export var extend_time: float = 0.22      ## fast slam out
@export var hold: float = 0.7
@export var retract_time: float = 0.6
@export var phase: float = 0.0             ## stagger multiple pistons

var _t: float = 0.0
var _base: Vector2
var _dir: Vector2
var _head: Sprite2D
var _shaft: Line2D
var _shaft_outline: Line2D         ## black border behind the shaft (outline INSIDE the width)
var _shape: CollisionShape2D
var _wall: StaticBody2D            ## solid rod: blocks bullets + monsters while extended
var _wall_shape: CollisionShape2D
var _out: bool = false
var _slammed: bool = false         ## camera-kick fired for this extension

func _ready() -> void:
	z_index = 6
	add_to_group("pistons")
	collision_layer = 0
	collision_mask = 2          # detect the player
	_base = position
	_dir = Vector2.from_angle(deg_to_rad(extend_dir_deg))
	_t = phase
	# Black outline BEHIND the grey fill, at the full width; the fill is 5 px narrower on each
	# side, so the black shows as an inside outline (total width unchanged).
	_shaft_outline = Line2D.new()
	_shaft_outline.width = size * 0.7
	_shaft_outline.default_color = Color(0.0, 0.0, 0.0)
	_shaft_outline.z_index = 3
	add_child(_shaft_outline)
	_shaft = Line2D.new()
	_shaft.width = maxf(size * 0.7 - 10.0, 2.0)          # -5 px left, -5 px right
	_shaft.default_color = Color(0.588, 0.580, 0.580)   # #969494
	_shaft.z_index = 4                                  # BELOW the head so the retracted stub hides
	add_child(_shaft)
	_build_head()
	_build_shape()
	_build_wall()
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	if GameManager.time_stopped:
		return
	_t += delta
	var ph := fmod(_t, cycle)
	var f: float
	if ph < extend_time:
		f = ph / extend_time
	elif ph < extend_time + hold:
		f = 1.0
	elif ph < extend_time + hold + retract_time:
		f = 1.0 - (ph - extend_time - hold) / retract_time
	else:
		f = 0.0
	var tip: Vector2 = _dir * (extend_len * f)
	position = _base + tip                     # move the whole Area (head) to the tip
	_out = f > 0.06
	# Camera kick + light haptic + metallic slam sound when the head slams home near the
	# player (proximity-gated so staggered pistons across a big level don't clang nonstop).
	if f >= 1.0 and not _slammed:
		_slammed = true
		var p := get_tree().get_first_node_in_group("players")
		if p and global_position.distance_to(p.global_position) < 620.0:
			var gw := get_tree().get_first_node_in_group("game_world")
			if gw and gw.has_method("_add_shake"):
				gw.call("_add_shake", 6.0)
			GameManager.vibrate(18)
			AudioManager.play_sfx_at("pist", global_position.x)
	elif f <= 0.05:
		_slammed = false
	# Shaft from the ANCHOR WALL to the head (drawn in head-local space). The base sits
	# `base_inset` px inside the wall (generator's PIST_MARGIN); extend the shaft that far
	# (plus a few px) so it's stuck to the wall with no gap when the piston is out.
	if _shaft:
		var p0 := -tip - _dir * (base_inset + 6.0)
		_shaft.clear_points()
		_shaft.add_point(p0)
		_shaft.add_point(Vector2.ZERO)
		if _shaft_outline:
			_shaft_outline.clear_points()
			_shaft_outline.add_point(p0)
			_shaft_outline.add_point(Vector2.ZERO)
	# Solid rod: while extended it's a wall (stops bullets + monsters); off when retracted.
	if _wall_shape:
		if _out:
			var along: float = tip.length() + size + base_inset
			(_wall_shape.shape as RectangleShape2D).size = Vector2(along, size * 0.8)
			_wall_shape.rotation = _dir.angle()
			_wall_shape.position = -tip * 0.5 - _dir * (base_inset * 0.5)
			_wall_shape.disabled = false
		else:
			_wall_shape.disabled = true
	# Continuous overlap check (body_entered only fires on transitions).
	if _out:
		var p := get_tree().get_first_node_in_group("players")
		if p and not p.is_dead and global_position.distance_to(p.global_position) <= size * 0.5 + p.radius:
			p.take_zone_damage(999999.0)
		# Instakill any MONSTER crushed anywhere along the extended rod — same as the player.
		# (Invisible ghosts phase through the rod and aren't targetable, so they're skipped.)
		var perp := Vector2(-_dir.y, _dir.x)
		var rod_len := tip.length() + base_inset + size * 0.5
		for mm in get_tree().get_nodes_in_group("monsters"):
			if not (mm is Monster):
				continue
			var mon := mm as Monster
			if not mon.is_targetable() or mon.hp <= 0.0:
				continue
			var rel: Vector2 = mon.global_position - global_position
			var along: float = rel.dot(-_dir)   # 0 = at the head, growing back toward the wall
			if along >= -size * 0.5 and along <= rod_len and absf(rel.dot(perp)) <= size * 0.5 + mon.radius:
				mon.take_damage(999999.0)

func _on_body(body: Node2D) -> void:
	if _out and body.is_in_group("players"):
		var p := body as Player
		if p and not p.is_dead:
			p.take_zone_damage(999999.0)

func _build_head() -> void:
	_head = Sprite2D.new()
	_head.z_index = 7                    # above the shaft (z=4) so it caps the end cleanly
	if ResourceLoader.exists(TEX):
		_head.texture = load(TEX)
		var t: Vector2 = _head.texture.get_size()
		var sf := size / maxf(t.x, t.y)
		_head.scale = Vector2(sf, sf)
		_head.rotation = deg_to_rad(extend_dir_deg) + PI / 2.0   # SVG up -> face extend dir
	add_child(_head)

func _build_shape() -> void:
	_shape = CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size * 0.45
	_shape.shape = c
	add_child(_shape)

## Solid rod that blocks bullets + monsters (except invisible ghosts) while extended.
## layer 1 = player, 4 = bullet-detect, 32 = monster-block (invisible ghosts un-mask bit 32).
func _build_wall() -> void:
	_wall = StaticBody2D.new()
	_wall.add_to_group("walls")
	_wall.collision_layer = 1 | 4 | 32
	_wall.collision_mask = 0
	_wall_shape = CollisionShape2D.new()
	_wall_shape.shape = RectangleShape2D.new()
	_wall_shape.disabled = true
	_wall.add_child(_wall_shape)
	add_child(_wall)
