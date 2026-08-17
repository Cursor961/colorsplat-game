class_name Decoy
extends Area2D
## Decoy projectile — thrown like a grenade, but instead of exploding on contact it
## lures EVERY monster toward itself (game_world sets it as the shared lure target)
## for FUSE_TIME seconds. It beeps on an accelerating cadence (L4D pipebomb style) and
## blinks a warning light, then detonates: a smaller-than-grenade blast that still
## one-shots monsters. game_world handles the actual blast via the `exploded` signal.

signal exploded(decoy: Decoy)

const FUSE_TIME := 4.0             ## Lure duration + time until detonation
const INITIAL_SPEED := 900.0       ## Fast throw start (same feel as grenade)
const DRAG := 3.0                  ## Exponential drag — speed = INITIAL * e^(-DRAG*t)
const EXPLOSION_RADIUS := 95.0     ## Smaller than the grenade (150)

# Beep cadence: starts slow, accelerates to a frantic blip just before it blows.
const BEEP_GAP_START := 0.55
const BEEP_GAP_END := 0.07
const BLINK_COLOR := Color(2.2, 0.5, 0.5)  ## bright red warning flash
# Small indicator light blinking on the decoy with each beep.
const LIGHT_COLOR := Color("F000A4")
const LIGHT_RADIUS := 5.0
const LIGHT_OFFSET := Vector2(0, -10)  ## on the texture, above center (rotates with it)
const LIGHT_TIME := 0.16               ## how long the light stays lit per beep

var direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
var _has_exploded: bool = false
var _next_beep_at: float = 0.0
var _flash_tw: Tween
var _light_t: float = 0.0              ## >0 while the blink light is lit

func _ready() -> void:
	z_index = 5

func setup(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direction = dir.normalized()
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		var tex_size := sprite.texture.get_size()
		var sf := 40.0 / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(sf, sf)
		# A node's own _draw renders BELOW its children — flip the sprite behind the
		# parent so the blink light (drawn in _draw) shows on top of the texture.
		sprite.show_behind_parent = true

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return
	_elapsed += delta
	# Exponential deceleration — fast throw that slows to a crawl, then sits and lures.
	var speed := INITIAL_SPEED * exp(-DRAG * _elapsed)
	global_position += direction * speed * delta
	# Spin the sprite while flying (slows with the throw), like the grenade.
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.rotation += delta * 8.0 * (speed / INITIAL_SPEED)

	# Accelerating beep + blink
	if _elapsed >= _next_beep_at:
		_beep()
		var u := clampf(_elapsed / FUSE_TIME, 0.0, 1.0)
		_next_beep_at = _elapsed + lerpf(BEEP_GAP_START, BEEP_GAP_END, u)

	# Fade the blink light timer + redraw while it's visible.
	if _light_t > 0.0:
		_light_t -= delta
		queue_redraw()

	if _elapsed >= FUSE_TIME:
		_explode()

## Small blinking indicator light on the decoy texture (lit briefly on each beep).
func _draw() -> void:
	if _light_t <= 0.0:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var pos := LIGHT_OFFSET.rotated(sprite.rotation) if sprite else LIGHT_OFFSET
	draw_circle(pos, LIGHT_RADIUS, LIGHT_COLOR)

func _beep() -> void:
	AudioManager.play_sfx("decoy_beep", 0.5)   # half volume
	_light_t = LIGHT_TIME
	queue_redraw()
	# Warning blink — quick red flash that always returns to white (self-correcting,
	# so rapid overlapping beeps near the end just keep it strobing red).
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		if _flash_tw and _flash_tw.is_valid():
			_flash_tw.kill()
		_flash_tw = create_tween()
		_flash_tw.tween_property(sprite, "modulate", BLINK_COLOR, 0.05)
		_flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	exploded.emit(self)
	queue_free()
