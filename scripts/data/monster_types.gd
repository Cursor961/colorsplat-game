class_name MonsterTypes
## Monster type definitions - 8 enemy types for ColorSplat!
## All tweakable values are here for easy balancing.
## See docs/features.md for detailed descriptions.

enum Type {
	BASIC,    ## Red grunt - simple chase
	TANK,     ## Green golem - slow, high HP
	SPEEDER,  ## Blue dasher - fast, sinusoidal movement
	BRUTE,    ## Yellow smasher - charge attack
	HEALER,   ## Purple slime - heals nearby monsters
	SPAWNER,  ## Orange hive - spawns grunts
	SPLITTER, ## White divider - splits on death (max 2x)
	GHOST,    ## Translucent phantom - ignores paint, blinks invisible
	TANKBOMBER, ## Tank that detonates like a grenade on death
}

## Per-type base stats. Multiplied by tier multipliers in Endless mode.
## Keys: hp, damage, speed, radius, color, split_tier (Splitter only)
const STATS: Dictionary = {
	Type.BASIC: {
		"name": "Basic",
		"hp": 60.0,
		"damage": 50.0,
		"speed": 210.0,
		"radius": 16.0,
		"color": Color(0.85, 0.0, 0.047),  # Red (matches grunt.svg rgb(217,0,12))
		"score": 10,
		"paint_scale": 1.0,
		"contact_hp_percent": 0.10,  ## 10% of player max HP on contact
	},
	Type.TANK: {
		"name": "Tank",
		"hp": 500.0,   ## 5 normal bullet hits (100 dmg each) to kill — was 250 (3 hits).
					   ## Mutants with the tank mutation inherit this via make_special().
		"damage": 40.0,
		"speed": 105.0,
		"radius": 32.0,  ## Same size as ghost
		"color": Color(0.0, 0.27, 1.0),  # Blue (matches tank.svg rgb(0,69,255))
		"score": 25,
		"paint_scale": 1.5,
		"contact_hp_percent": 0.50,  ## 50%
	},
	Type.SPEEDER: {
		"name": "Speeder",
		"hp": 35.0,
		"damage": 30.0,
		"speed": 315.0,
		"radius": 22.0,
		"color": Color(0.0, 1.0, 0.878),  # Cyan (matches speeder.svg rgb(0,255,224))
		"score": 15,
		"paint_scale": 1.2,
		"contact_hp_percent": 0.20,  ## 20%
		# Sinusoidal movement params
		"sine_amplitude": 80.0,
		"sine_frequency": 2.5,
		"sine_fade_distance": 120.0,
	},
	Type.BRUTE: {
		"name": "Brute",
		"hp": 180.0,
		"damage": 120.0,
		"speed": 150.0,
		"radius": 25.0,  ## 1.25x bigger
		"color": Color(1.0, 0.549, 0.0),  # Orange (matches brute.svg rgb(255,140,0))
		"score": 30,
		"paint_scale": 1.5,
		"contact_hp_percent": 0.40,  ## 40%
		# Charge attack params
		"charge_range": 150.0,
		"charge_speed_mult": 3.0,
		"charge_warning_time": 0.4,
	},
	Type.HEALER: {
		"name": "Healer",
		"hp": 200.0,  ## 2x HP
		"damage": 25.0,
		"speed": 165.0,
		"radius": 32.0,  ## 2x size
		"color": Color(0.557, 1.0, 0.0),  # Lime green (matches healer.svg rgb(142,255,0))
		"score": 35,
		"paint_scale": 1.0,
		"contact_hp_percent": 0.25,  ## 25%
		# Heal aura params
		"heal_interval": 3.0,
		"heal_percent": 0.20,
		"heal_radius": 165.0,
		# Ranged attack params (fires a paint projectile at the player)
		"shoot_interval": 3.0,           ## One projectile every 3 seconds
		"bullet_speed": 320.0,
		"bullet_damage_percent": 0.10,   ## 10% of player max HP on hit
	},
	Type.SPAWNER: {
		"name": "Spawner",
		"hp": 400.0,  ## 2x HP
		"damage": 20.0,
		"speed": 90.0,
		"radius": 55.0,  ## 2.5x bigger (22 * 2.5)
		"color": Color(1.0, 1.0, 1.0),  # White (matches spawner.svg)
		"score": 40,
		"paint_scale": 2.0,
		"contact_hp_percent": 0.40,  ## 40%
		# Spawn params
		"spawn_interval": 5.0,
		"spawn_count": 4,
		"spawn_spread": 40.0,  ## Spawn inside body (smaller than radius)
		"spawn_max_monsters": 60,
		"spawn_warning_time": 1.0,
	},
	Type.SPLITTER: {
		"name": "Splitter",
		"hp": 120.0,
		"damage": 45.0,
		"speed": 128.0,
		"radius": 40.0,  ## 2x bigger
		"color": Color(0.631, 0.196, 1.0),  # Purple (matches spliter.svg rgb(161,50,255))
		"score": 20,
		"paint_scale": 2.0,
		"contact_hp_percent": 0.10,  ## 10%
		# Split params
		"split_count": 3,
		"max_split_tier": 2,
		"split_hp_mult": 0.5,
		"split_speed_mult": 1.3,
		"split_radius_mult": 0.65,
		"split_damage_mult": 0.6,
	},
	Type.GHOST: {
		"name": "Ghost",
		"hp": 50.0,
		"damage": 45.0,
		"speed": 360.0,  ## 2x speed
		"radius": 32.0,  ## 2x size
		"color": Color(1.0, 0.4, 0.7),  # Pink death paint
		"score": 20,
		"paint_scale": 0.8,
		"contact_hp_percent": 0.50,  ## 50%
		# Visibility params — 3s visible / 3s invisible cycle
		"visible_duration": 3.0,
		"invisible_duration": 3.0,
		"ignores_paint": true,
	},
	Type.TANKBOMBER: {
		"name": "Tankbomber",
		"hp": 250.0,        ## Same toughness as Tank
		"damage": 40.0,
		"speed": 105.0,
		"radius": 32.0,
		"color": Color(0.95, 0.45, 0.1),  # Explosive orange (death paint)
		"score": 40,
		"paint_scale": 1.5,
		"contact_hp_percent": 0.50,  ## 50% like Tank
		"explodes_on_death": true,   ## game_world detonates a grenade-style blast
	},
}

## Returns the (constant) stats for a monster type. Monster stats NO LONGER scale with
## time — they stay at their starting values for the whole run (time-scaling removed by
## request). `_elapsed_time` is kept for call-site compatibility but is unused.
static func get_stats(type: Type, _elapsed_time: float = 0.0, split_tier: int = 0) -> Dictionary:
	var base: Dictionary = STATS[type].duplicate(true)

	base["max_hp"] = base["hp"]  # Store max for healer reference

	# Apply split tier reduction (for Splitter children)
	if type == Type.SPLITTER and split_tier > 0:
		for i in split_tier:
			base["hp"] *= base.get("split_hp_mult", 0.5)
			base["speed"] *= base.get("split_speed_mult", 1.3)
			base["radius"] *= base.get("split_radius_mult", 0.65)
			base["damage"] *= base.get("split_damage_mult", 0.6)
			base["paint_scale"] *= base.get("split_radius_mult", 0.65)
		base["max_hp"] = base["hp"]

	base["split_tier"] = split_tier
	return base

## Returns the Color for a given monster type.
static func get_color(type: Type) -> Color:
	return STATS[type]["color"]

## Returns display name for a given monster type.
static func get_name(type: Type) -> String:
	return STATS[type]["name"]

## Returns the fraction of player max HP dealt on contact (0.0 – 1.0).
static func get_contact_percent(type: Type) -> float:
	return STATS[type].get("contact_hp_percent", 0.10)
