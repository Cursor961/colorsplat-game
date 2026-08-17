class_name Bullet
extends Area2D
## Bullet logic - converted from Classes/Bullet.as
## Flies in straight line, swept collision with monsters, wall collision.

signal hit_monster(bullet: Bullet, monster: Monster)
signal hit_wall(bullet: Bullet)
signal hit_crate(bullet: Bullet, crate: LootCrate)

@export var speed: float = 500.0
@export var damage: float = 100.0
@export var radius: float = 5.0
@export var bullet_color: Color = Color.YELLOW
@export var is_secondary: bool = false  ## Powerup side bullets (don't play impact sound)
var is_fmj: bool = false  ## FMJ: passes through monsters, doesn't stop on hit
var is_freeze: bool = false  ## Freeze Shot: swaps to the ice bullet + chills monsters on hit
var is_bounce: bool = false  ## Bullet Bounce: reflects once off a wall / arena edge

var direction: Vector2 = Vector2.RIGHT
var _prev_position: Vector2

# ---- BULLET BOUNCE ----
var _bounces_left: int = 0
var _arena_size: Vector2 = Vector2(1920.0, 1080.0)   ## for arena-edge bounce

# ---- FREEZE SHOT ----
const FREEZE_SLOW_DURATION := 2.0    ## light slow lasts 2 s after the hit
const FREEZE_SLOW_MULT := 0.33       ## capped to 33% of the monster's normal speed
const FREEZE_DMG_MULT := 1.0 / 3.0   ## freeze bullets deal 1/3 damage (3x shots to kill)

# Despawn bounds = arena + margin (cached in _ready). A bullet that misses everything
# would otherwise fly forever and leak. Uses the ARENA size, not the 1920x1080 view, so
# bullets survive across larger levels (they only vanish past the actual level edges).
var _despawn_min: Vector2 = Vector2(-200, -200)
var _despawn_max: Vector2 = Vector2(2120, 1280)

# ---- FMJ TRAIL ----
var _trail_timer: float = 0.0
const FMJ_TRAIL_INTERVAL := 0.02  ## Spawn a trail particle every 20ms
const FMJ_TRAIL_LIFETIME := 0.15  ## Trail particle fade time (short)

func _ready() -> void:
	add_to_group("bullets")
	z_index = 3  ## Layer 3: bullets above walls and paint, below monsters/player
	_prev_position = global_position
	# Cache despawn bounds from the arena (levels can be much larger than the 1920x1080 view).
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw:
		var aw: float = float(gw.get("arena_width"))
		var ah: float = float(gw.get("arena_height"))
		if aw > 0.0 and ah > 0.0:
			_despawn_min = Vector2(-200.0, -200.0)
			_despawn_max = Vector2(aw + 200.0, ah + 200.0)
			_arena_size = Vector2(aw, ah)
	if is_bounce:
		_bounces_left = 1   # one reflection off a wall / arena edge
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	# Freeze Shot: recolour the bullet's FILL dark blue via a shader while keeping the black
	# outline stroke (a plain modulate can't — the default bullet is yellow, which has no blue
	# channel, so multiply comes out dark green). Freeze wins over FMJ when both are active.
	if is_freeze and sprite:
		sprite.material = _freeze_fill_material()
		_add_freeze_glow()
	elif is_fmj and sprite:
		sprite.modulate = Color(1.0, 0.3, 0.3)  # FMJ red tint (multiply works on the red channel)

func _physics_process(delta: float) -> void:
	_prev_position = global_position
	var move := direction * speed * delta
	global_position += move

	# Bullet Bounce: reflect once off an arena edge (the "screen edge"). Wall reflections are
	# handled on collision in _try_bounce_off_wall().
	if is_bounce and _bounces_left > 0:
		var bounced := false
		if global_position.x < 0.0 and direction.x < 0.0:
			direction.x = -direction.x; global_position.x = 0.0; bounced = true
		elif global_position.x > _arena_size.x and direction.x > 0.0:
			direction.x = -direction.x; global_position.x = _arena_size.x; bounced = true
		if global_position.y < 0.0 and direction.y < 0.0:
			direction.y = -direction.y; global_position.y = 0.0; bounced = true
		elif global_position.y > _arena_size.y and direction.y > 0.0:
			direction.y = -direction.y; global_position.y = _arena_size.y; bounced = true
		if bounced:
			_bounces_left -= 1
			_update_rotation()

	if is_fmj:
		# FMJ trail effect
		_trail_timer += delta
		if _trail_timer >= FMJ_TRAIL_INTERVAL:
			_trail_timer -= FMJ_TRAIL_INTERVAL
			_spawn_trail_dot()

	# Despawn only past the ARENA edges (cached in _ready). A bullet that misses every
	# monster would otherwise fly forever and leak. (Previously this used the 1920x1080
	# viewport size, which wrongly culled bullets mid-level on larger levels.)
	if global_position.x < _despawn_min.x or global_position.x > _despawn_max.x \
	or global_position.y < _despawn_min.y or global_position.y > _despawn_max.y:
		_destroy()

func _on_body_entered(body: Node2D) -> void:
	if body is Monster:
		var monster := body as Monster
		if monster.is_targetable():
			if is_freeze:
				monster.apply_freeze(FREEZE_SLOW_DURATION, FREEZE_SLOW_MULT)
			monster.take_damage(damage * FREEZE_DMG_MULT if is_freeze else damage)
			hit_monster.emit(self, monster)
			if not is_fmj:
				_destroy()
			# FMJ: bullet passes through, no destroy
	elif body.is_in_group("walls"):
		# Breakable walls are in "walls" too — chip them before the wall despawn.
		if body.has_method("hit_by_bullet"):
			body.hit_by_bullet(self)
		hit_wall.emit(self)
		if _try_bounce_off_wall(body):
			return   # Bounce powerup: reflected off the wall instead of dying.
		_destroy()   # walls always stop bullets — FMJ passes through MONSTERS, not walls
					 # (only the laser can shoot through a wall)
	elif body.has_method("hit_by_bullet"):
		# Generic level object (barrel, movable crate, …) reacts to the hit.
		body.hit_by_bullet(self)
		if not is_fmj:
			_destroy()

func _on_area_entered(area: Area2D) -> void:
	# Wall detection via Area2D if walls are areas
	if area.is_in_group("walls"):
		if area.has_method("hit_by_bullet"):
			area.hit_by_bullet(self)
		hit_wall.emit(self)
		if _try_bounce_off_wall(area):
			return   # Bounce powerup: reflected off the wall instead of dying.
		_destroy()   # walls always stop bullets — FMJ no longer passes through walls
	# Lootcrate detection
	elif area is LootCrate:
		hit_crate.emit(self, area as LootCrate)
		if not is_fmj:
			_destroy()
	elif area.has_method("hit_by_bullet"):
		# Generic Area2D level object reacts to the hit.
		area.hit_by_bullet(self)
		if not is_fmj:
			_destroy()

func _destroy() -> void:
	queue_free()

## Shared blue-FILL material for Freeze Shot bullets. Recolours only the bright fill pixels
## and leaves the dark outline stroke untouched (same trick as the special-monster tint), so
## the ice bullet keeps the black outline every other bullet has. The fill is a DARKER blue
## than the glow halo behind it, so the bullet reads crisply against its own glow.
static var _freeze_fill_mat: ShaderMaterial = null
func _freeze_fill_material() -> ShaderMaterial:
	if _freeze_fill_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec4 col : source_color = vec4(0.14, 0.34, 0.85, 1.0);\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV);\n\tfloat bright = max(max(t.r, t.g), t.b);\n\tfloat fill = smoothstep(0.18, 0.45, bright);\n\tCOLOR = vec4(mix(t.rgb, col.rgb, fill), t.a * COLOR.a);\n}\n"
		_freeze_fill_mat = ShaderMaterial.new()
		_freeze_fill_mat.shader = sh
		_freeze_fill_mat.set_shader_parameter("col", Color(0.14, 0.34, 0.85, 1.0))  # dark blue fill (glow is 0.45,0.72,1.0)
	return _freeze_fill_mat

## A soft light-blue glow halo behind a Freeze Shot bullet (child → follows it around).
func _add_freeze_glow() -> void:
	var gpath := "res://assets/sprites/powerups/pickup_glow.svg"
	if not ResourceLoader.exists(gpath):
		return
	var glow := Sprite2D.new()
	glow.texture = load(gpath)
	glow.modulate = Color(0.45, 0.72, 1.0, 0.5)   # light blue, soft
	var gs := glow.texture.get_size()
	var target := radius * 2.5                     # halo ~1.25x the bullet diameter (2x smaller)
	glow.scale = Vector2(target / maxf(gs.x, 1.0), target / maxf(gs.y, 1.0))
	glow.z_index = -1                              # behind the bullet sprite
	add_child(glow)

## Node rotation so the bullet sprite faces its travel direction (SVG points up = -Y → +90°).
func _update_rotation() -> void:
	rotation = direction.angle() + PI / 2.0

## Bullet Bounce off a level wall: reflect the direction across the wall face and nudge back
## out. Returns true if it bounced (caller must NOT destroy). FMJ passes through walls, so it
## never bounces off them (only off arena edges). Lasers don't bounce (they aren't bullets).
func _try_bounce_off_wall(wall: Node) -> bool:
	if not is_bounce or _bounces_left <= 0 or is_fmj:
		return false
	# Mirror the direction across the wall face → angle of reflection == angle of incidence
	# (a "screensaver" bounce). _wall_normal always returns a valid face, so it never reverses.
	var n := _wall_normal(wall)
	direction = (direction - 2.0 * direction.dot(n) * n).normalized()
	global_position += n * (radius + 3.0)   # push clear so it can't re-hit the same wall
	_bounces_left -= 1
	_update_rotation()
	return true

## Surface normal of an axis-aligned wall face. Uses the wall rect + the bullet's PREVIOUS
## position when available (accurate for glancing hits); otherwise falls back to flipping the
## dominant axis of travel — either way a proper reflection (never a 180° reversal).
func _wall_normal(wall: Node) -> Vector2:
	if wall is Node2D:
		var ws_v: Variant = wall.get("wall_size")
		if ws_v is Vector2:
			var half: Vector2 = (ws_v as Vector2) * 0.5
			var d: Vector2 = _prev_position - (wall as Node2D).global_position
			# The axis on which the previous position was MOST outside the wall is the bounce face.
			if absf(d.x) - half.x >= absf(d.y) - half.y:
				return Vector2(signf(d.x), 0.0)
			return Vector2(0.0, signf(d.y))
	# No rect geometry → reflect off the face opposing the dominant travel axis.
	if absf(direction.x) >= absf(direction.y):
		return Vector2(-signf(direction.x), 0.0)
	return Vector2(0.0, -signf(direction.y))

## Initialize bullet direction and stats. Called by game_world.spawn_bullet().
func setup(pos: Vector2, dir: Vector2, spd: float, dmg: float, r: float, col: Color, secondary: bool = false) -> void:
	global_position = pos
	_prev_position = pos
	direction = dir.normalized()
	speed = spd
	damage = dmg
	radius = r
	bullet_color = col
	is_secondary = secondary
	# Bullet sprite points up (Y-) in SVG; add 90° so sprite faces movement direction
	_update_rotation()

	# Update collision shape to match radius
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = r

	# Scale sprite to match bullet radius
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var tex_size := sprite.texture.get_size()
		var target_diameter := r * 2.0
		var scale_factor := target_diameter / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)

## Spawn a small fading red dot behind the FMJ bullet.
func _spawn_trail_dot() -> void:
	var dot := Sprite2D.new()
	# Use the bullet's own sprite texture for the trail particle
	var src_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if src_sprite and src_sprite.texture:
		dot.texture = src_sprite.texture
		# Trail dot is same size as the bullet
		dot.scale = src_sprite.scale * 0.8
	else:
		return
	dot.global_position = global_position
	dot.rotation = rotation
	dot.z_index = 2  # Below bullets
	dot.modulate = Color(1.0, 0.5, 0.5, 0.6)  # Light red, semi-transparent
	get_parent().add_child(dot)
	# Fade out quickly
	var tw := dot.create_tween()
	tw.tween_property(dot, "modulate:a", 0.0, FMJ_TRAIL_LIFETIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(dot.queue_free)
