class_name ItemPickup
extends Area2D
## Item pickup on the map. Collected on player contact → goes into inventory.
## Same visual pattern as Powerup: glow sprite, spawn scale anim, blink, despawn.

signal collected(pickup: ItemPickup)

const Juice := preload("res://scripts/utils/juice.gd")

enum ItemType { GRENADE, SLOWPILL, KATANA, LASER, HP25, DECOY }

const TYPE_NAMES: Dictionary = {
	ItemType.GRENADE: "Grenade",
	ItemType.SLOWPILL: "Slowpill",
	ItemType.KATANA: "Katana",
	ItemType.LASER: "Laser",
	ItemType.HP25: "HP +25",
	ItemType.DECOY: "Decoy",
}

var item_type: ItemType = ItemType.GRENADE

# ---- LIFETIME ----
const MAP_LIFETIME := 20.0
const BLINK_START := 15.0
var _lifetime: float = MAP_LIFETIME

# ---- GLOW ----
const GLOW_ROT_SPEED := TAU / 5.0
const GLOW_BLUR_SHADER := "res://assets/shaders/glow_blur.gdshader"
var _glow_sprite: Sprite2D = null

var _no_expire: bool = false   ## true in level/challenge mode → pickup never despawns

func _ready() -> void:
	z_index = 4
	var gw := get_tree().get_first_node_in_group("game_world")
	_no_expire = gw != null and bool(gw.get("_level_mode"))

	var target_scale := scale
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", target_scale, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _physics_process(delta: float) -> void:
	if _glow_sprite:
		_glow_sprite.rotation += GLOW_ROT_SPEED * delta

	if _no_expire:
		return   # levels: never blink/despawn

	_lifetime -= delta
	if _lifetime <= (MAP_LIFETIME - BLINK_START):
		visible = int(_lifetime * 6.0) % 2 == 0
	if _lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		var icon: Texture2D = null
		var spr := get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			icon = spr.texture
		Juice.pickup_pop(get_parent(), global_position, icon, Color(0.45, 1.0, 0.5))  # green = item
		collected.emit(self)
		queue_free()

func initialize(type: ItemType, tex: Texture2D, target_diameter: float) -> void:
	item_type = type

	# Items use green glow
	var glow_path := "res://assets/sprites/powerups/pickup_glow_green.svg"
	if ResourceLoader.exists(glow_path):
		_glow_sprite = Sprite2D.new()
		_glow_sprite.texture = load(glow_path)
		_glow_sprite.z_index = -1
		var glow_tex_size := _glow_sprite.texture.get_size()
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

	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite and tex:
		sprite.texture = tex
		var tex_size := tex.get_size()
		var sf := target_diameter / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(sf, sf)

	scale = Vector2.ONE
