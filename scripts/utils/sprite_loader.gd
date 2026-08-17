class_name SpriteLoader
## Sprite asset loader - maps entity types to SVG file paths.
## Centralized system for loading player skins, monster sprites, bullet sprites.
## Supports future skin/cosmetic system via named variants.
##
## Usage:
##   var tex = SpriteLoader.get_monster_texture(MonsterTypes.Type.BASIC)
##   var tex = SpriteLoader.get_player_texture("default")
##   var tex = SpriteLoader.get_bullet_texture("default")

# ---- BASE PATHS ----
const PLAYER_DIR := "res://assets/sprites/player/"
## Game reads skins from here. Source SVGs are authored in res://icons/player/skins/player/
## and copied into this folder (see _import note in SkinData). One <id>.svg per skin.
const SKINS_DIR := "res://assets/sprites/player/skins/"
const ENEMY_DIR := "res://assets/sprites/enemies/"
const BULLET_DIR := "res://assets/sprites/bullets/"
const UI_DIR := "res://assets/sprites/ui/"
const EFFECTS_DIR := "res://assets/sprites/effects/"

# ---- MONSTER TYPE → FILENAME MAPPING ----
const MONSTER_FILES: Dictionary = {
	MonsterTypes.Type.BASIC: "monster_basic.svg",
	MonsterTypes.Type.TANK: "monster_tank.svg",
	MonsterTypes.Type.SPEEDER: "monster_speeder.svg",
	MonsterTypes.Type.BRUTE: "monster_brute.svg",
	MonsterTypes.Type.HEALER: "monster_healer.svg",
	MonsterTypes.Type.SPAWNER: "monster_spawner.svg",
	MonsterTypes.Type.SPLITTER: "monster_splitter.svg",
	MonsterTypes.Type.GHOST: "monster_ghost.svg",  ## Invisible state (grey)
	MonsterTypes.Type.TANKBOMBER: "monster_tankbomber.svg",
}

## Ghost has two sprite states: visible (purple) and invisible (grey).
const GHOST_VISIBLE_FILE := "monster_ghost_visible.svg"
const GHOST_INVISIBLE_FILE := "monster_ghost.svg"

# Splitter has tier-specific sprites (gets smaller as it splits)
const SPLITTER_TIER_FILES: Dictionary = {
	0: "monster_splitter.svg",      # 128x128
	1: "monster_splitter_medium.svg", # 80x80
	2: "monster_splitter_small.svg",  # 48x48
}

# ---- TEXTURE CACHE ----
# Avoids reloading the same texture multiple times per session.
static var _cache: Dictionary = {}

# ============================================================
# MONSTER TEXTURES
# ============================================================

## Get texture for a monster type. For Splitter, pass split_tier for size variant.
static func get_monster_texture(type: MonsterTypes.Type, split_tier: int = 0) -> Texture2D:
	var filename: String
	if type == MonsterTypes.Type.SPLITTER:
		filename = SPLITTER_TIER_FILES.get(split_tier, SPLITTER_TIER_FILES[0])
	else:
		filename = MONSTER_FILES.get(type, "monster_basic.svg")

	var path := ENEMY_DIR + filename
	return _load_cached(path)

## Ghost-specific: get the visible-state sprite (purple with black eyes).
static func get_ghost_visible_texture() -> Texture2D:
	return _load_cached(ENEMY_DIR + GHOST_VISIBLE_FILE)

## Ghost-specific: get the invisible-state sprite (grey with white eyes).
static func get_ghost_invisible_texture() -> Texture2D:
	return _load_cached(ENEMY_DIR + GHOST_INVISIBLE_FILE)

## Get all monster textures (for preloading).
static func preload_monster_textures() -> void:
	for type_key: MonsterTypes.Type in MONSTER_FILES:
		get_monster_texture(type_key)
	for tier_key: int in SPLITTER_TIER_FILES:
		get_monster_texture(MonsterTypes.Type.SPLITTER, tier_key)

# ============================================================
# PLAYER TEXTURES
# ============================================================

## Get player texture by skin id. "default" is the baked-in base skin; any other
## id loads res://assets/sprites/player/skins/<id>.svg. Falls back to default if
## the skin file is missing (e.g. a stale equipped_skin in the save).
static func get_player_texture(skin_name: String = "default") -> Texture2D:
	if skin_name == "default" or skin_name.is_empty():
		return _load_cached(PLAYER_DIR + "player_default.svg")
	var path := SKINS_DIR + "%s.svg" % skin_name
	if ResourceLoader.exists(path):
		return _load_cached(path)
	# Missing skin file — fall back to the default sprite.
	return _load_cached(PLAYER_DIR + "player_default.svg")

## Get list of available player skin ids. Always starts with "default", then the
## <id>.svg files found in the skins folder (alphabetical). Dropping a new SVG in
## that folder makes it appear here automatically.
static func get_available_skins() -> PackedStringArray:
	var skins: PackedStringArray = ["default"]
	var found: PackedStringArray = []
	var dir := DirAccess.open(SKINS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# Godot exports .svg as .svg.import at runtime; match the source name.
				var fn := file_name.trim_suffix(".import")
				if fn.ends_with(".svg"):
					var skin := fn.trim_suffix(".svg")
					if skin != "" and skin not in found:
						found.append(skin)
			file_name = dir.get_next()
		dir.list_dir_end()
	found.sort()
	for s: String in found:
		skins.append(s)
	return skins

# ============================================================
# BULLET TEXTURES
# ============================================================

## Get bullet texture by variant name. "default" is the base bullet.
static func get_bullet_texture(variant: String = "default") -> Texture2D:
	var path := BULLET_DIR + "bullet_%s.svg" % variant
	return _load_cached(path)

# ============================================================
# UI TEXTURES
# ============================================================

## Get joystick base texture.
static func get_joystick_base_texture() -> Texture2D:
	return _load_cached(UI_DIR + "joystick/joystick_base.svg")

## Get joystick knob texture.
static func get_joystick_knob_texture() -> Texture2D:
	return _load_cached(UI_DIR + "joystick/joystick_knob.svg")

# ============================================================
# INTERNAL CACHING
# ============================================================

## Load and cache a texture. Returns null if file doesn't exist.
static func _load_cached(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]

	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[path] = tex
		return tex
	else:
		push_warning("SpriteLoader: Missing texture at '%s'" % path)
		return null

## Clear the texture cache (call on scene change to free memory).
static func clear_cache() -> void:
	_cache.clear()

## Get the file path for a monster type (useful for debugging / editor tools).
static func get_monster_path(type: MonsterTypes.Type, split_tier: int = 0) -> String:
	var filename: String
	if type == MonsterTypes.Type.SPLITTER:
		filename = SPLITTER_TIER_FILES.get(split_tier, SPLITTER_TIER_FILES[0])
	else:
		filename = MONSTER_FILES.get(type, "monster_basic.svg")
	return ENEMY_DIR + filename
