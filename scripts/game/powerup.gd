class_name Powerup
extends Area2D
## Powerup pickup item — spawns on the map, collected on player contact.
## Spawn animation: scale 0→1. Blinks last 5s. Despawns after 15s.
## Glow sprite rotates below icon at 1 revolution per 5 seconds.

signal collected(powerup: Powerup)

const Juice := preload("res://scripts/utils/juice.gd")

enum Type { CLEANER, HP_BOOST, SHOOT_BOOST, SPEED_BOOST, FMJ, OCTOSHOOT, SHURIKEN, HPBOOSTMAX, STOPPILL, CLEANERMAX, SHOOT_FREEZE, SHOOT_BOUNCE }

## Display names (for HUD / debug).
const TYPE_NAMES: Dictionary = {
	Type.CLEANER: "Cleaner",
	Type.HP_BOOST: "HP Boost",
	Type.SHOOT_BOOST: "Triple Shot",
	Type.SPEED_BOOST: "Speed Boost",
	Type.FMJ: "FMJ",
	Type.OCTOSHOOT: "Octoshoot",
	Type.SHURIKEN: "Shuriken",
	Type.HPBOOSTMAX: "Invincibility",
	Type.STOPPILL: "Time Stop",
	Type.CLEANERMAX: "Clean Sweep",
	Type.SHOOT_FREEZE: "Freeze Shot",
	Type.SHOOT_BOUNCE: "Bullet Bounce",
}

var powerup_type: Type = Type.CLEANER

# ---- LIFETIME ----
const MAP_LIFETIME := 15.0       ## Seconds before despawn
const BLINK_START := 10.0        ## Start blinking at 10s (5s before despawn)
var _lifetime: float = MAP_LIFETIME

# ---- GLOW ----
const GLOW_ROT_SPEED := TAU / 5.0  ## 1 full rotation per 5 seconds
const GLOW_BLUR_SHADER := "res://assets/shaders/glow_blur.gdshader"
var _glow_sprite: Sprite2D = null

var _no_expire: bool = false   ## true in level/challenge mode → pickup never despawns

func _ready() -> void:
	z_index = 4  ## Above paint, below player/monsters
	# In a hand-built level, floor pickups persist (no despawn); only endless expires them.
	var gw := get_tree().get_first_node_in_group("game_world")
	_no_expire = gw != null and bool(gw.get("_level_mode"))

	# Spawn animation: scale 0 → target over 0.35s
	var target_scale := scale  # Set by manager before add_child
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", target_scale, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _physics_process(delta: float) -> void:
	# Rotate glow
	if _glow_sprite:
		_glow_sprite.rotation += GLOW_ROT_SPEED * delta

	if _no_expire:
		return   # levels: never blink/despawn

	_lifetime -= delta
	# Blink in last 5 seconds (6 Hz toggle)
	if _lifetime <= (MAP_LIFETIME - BLINK_START):
		visible = int(_lifetime * 6.0) % 2 == 0
	# Despawn
	if _lifetime <= 0.0:
		queue_free()

## Called when a CharacterBody2D enters our Area2D (player pickup).
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		# Pickup pop (scale-bounce + sparks). Spawned into our parent so it outlives us.
		var icon: Texture2D = null
		var spr := get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			icon = spr.texture
		var tint := Color(1.0, 0.45, 0.35) if powerup_type in RARE_TYPES else Color(1.0, 0.92, 0.35)
		Juice.pickup_pop(get_parent(), global_position, icon, tint)
		collected.emit(self)
		queue_free()

## Rare powerup types (red glow). All others use yellow glow.
const RARE_TYPES: Array = [Type.OCTOSHOOT, Type.SHURIKEN, Type.HPBOOSTMAX, Type.STOPPILL, Type.CLEANERMAX, Type.SHOOT_BOUNCE]

## Initialize type and sprite. Called by PowerupManager before adding to tree.
func initialize(type: Type, tex: Texture2D, target_diameter: float) -> void:
	powerup_type = type

	# ---- Glow sprite (below icon) — yellow for common, red for rare ----
	var glow_path: String
	if type in RARE_TYPES:
		glow_path = "res://assets/sprites/powerups/pickup_glow_red.svg"
	else:
		glow_path = "res://assets/sprites/powerups/pickup_glow_yellow.svg"
	if ResourceLoader.exists(glow_path):
		_glow_sprite = Sprite2D.new()
		_glow_sprite.texture = load(glow_path)
		_glow_sprite.z_index = -1  ## Render below icon
		var glow_tex_size := _glow_sprite.texture.get_size()
		# Scale glow so it is 20% bigger than the pickup
		var glow_target := target_diameter * 1.2
		var glow_sf := glow_target / maxf(glow_tex_size.x, glow_tex_size.y)
		_glow_sprite.scale = Vector2(glow_sf, glow_sf)
		# Apply gaussian blur shader for soft edge fade
		if ResourceLoader.exists(GLOW_BLUR_SHADER):
			var mat := ShaderMaterial.new()
			mat.shader = load(GLOW_BLUR_SHADER)
			mat.set_shader_parameter("blur_strength", 3.5)
			_glow_sprite.material = mat
		add_child(_glow_sprite)

	# ---- Icon sprite ----
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite and tex:
		sprite.texture = tex
		var tex_size := tex.get_size()
		var sf := target_diameter / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(sf, sf)

	# Set the outer scale (spawn tween will animate from 0 to this)
	scale = Vector2.ONE
