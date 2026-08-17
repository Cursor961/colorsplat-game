class_name LevelData
## Level definitions for Level Mode.
## Converted from Monster_Spawner.as - 75 original levels restructured.
##
## Each level = array of waves.
## Each wave = { delay, groups[] }
## Each group = { position, spread, count, type, color_variation, spawn_mode, velocity, tier_override }
##
## spawn_mode: "absolute" | "relative_player" | "relative_center"
## position: Vector2 in normalized coords (0-1 range, mapped to play area)

## Star time thresholds per level (seconds): [3-star, 2-star, 1-star]
## If player finishes under 3-star time -> 3 stars, etc.
const STAR_TIMES: Dictionary = {}  # Populated per level below

## Total level count
const TOTAL_LEVELS := 30

## Returns level data for given level number (1-based).
## Returns null if level doesn't exist.
static func get_level(level_num: int) -> Dictionary:
	if level_num < 1 or level_num > TOTAL_LEVELS:
		return {}
	return LEVELS.get(level_num, {})

## Returns star rating (1-3) based on completion time.
static func get_stars(level_num: int, time_seconds: float) -> int:
	var times: Array = STAR_TIMES.get(level_num, [30.0, 60.0, 120.0])
	if time_seconds <= times[0]:
		return 3
	elif time_seconds <= times[1]:
		return 2
	else:
		return 1

# ============================================================
# LEVEL DEFINITIONS
# ============================================================
# Inspired by original Monster_Spawner.as 75-level structure.
# Levels 1-5: Tutorial / Basic only
# Levels 6-10: Introduce Tank
# Levels 11-15: Introduce Speeder
# Levels 16-20: Introduce Brute + Healer
# Levels 21-25: Introduce Spawner + Splitter
# Levels 26-30: All types + Ghost, mixed waves
# ============================================================

# LEVELS contains function calls (_g, _wall, _transport) so it can't be const.
# Use static var so static methods can access it without an instance.
static var LEVELS: Dictionary = {
	# --- TUTORIAL ARC (1-5): Basic grunts only ---
	1: {
		"name": "First Blood",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.2), 40.0, 3, MonsterTypes.Type.BASIC),
			]},
		],
	},
	2: {
		"name": "Warm Up",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 60.0, 5, MonsterTypes.Type.BASIC),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.2, 0.5), 40.0, 3, MonsterTypes.Type.BASIC),
				_g(Vector2(0.8, 0.5), 40.0, 3, MonsterTypes.Type.BASIC),
			]},
		],
	},
	3: {
		"name": "Surrounded",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.1, 0.1), 30.0, 3, MonsterTypes.Type.BASIC),
				_g(Vector2(0.9, 0.1), 30.0, 3, MonsterTypes.Type.BASIC),
				_g(Vector2(0.1, 0.9), 30.0, 3, MonsterTypes.Type.BASIC),
				_g(Vector2(0.9, 0.9), 30.0, 3, MonsterTypes.Type.BASIC),
			]},
		],
	},
	4: {
		"name": "The Line",
		"waves": [
			{"delay": 0.0, "groups": [
				_wall(Vector2(0.5, 0.1), 8, MonsterTypes.Type.BASIC, true),
			]},
			{"delay": 4.0, "groups": [
				_wall(Vector2(0.5, 0.9), 8, MonsterTypes.Type.BASIC, true),
			]},
		],
	},
	5: {
		"name": "Rush",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.05), 80.0, 10, MonsterTypes.Type.BASIC),
			]},
			{"delay": 2.0, "groups": [
				_g(Vector2(0.05, 0.5), 80.0, 8, MonsterTypes.Type.BASIC),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.95, 0.5), 80.0, 8, MonsterTypes.Type.BASIC),
			]},
		],
	},

	# --- TANK INTRODUCTION (6-10) ---
	6: {
		"name": "Heavy Hitters",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.15), 30.0, 2, MonsterTypes.Type.TANK),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.5, 0.15), 50.0, 5, MonsterTypes.Type.BASIC),
			]},
		],
	},
	7: {
		"name": "Shield Wall",
		"waves": [
			{"delay": 0.0, "groups": [
				_wall(Vector2(0.5, 0.15), 5, MonsterTypes.Type.TANK, true),
			]},
			{"delay": 2.0, "groups": [
				_g(Vector2(0.5, 0.05), 100.0, 10, MonsterTypes.Type.BASIC),
			]},
		],
	},
	8: {
		"name": "Pincer",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.1, 0.5), 20.0, 2, MonsterTypes.Type.TANK),
				_g(Vector2(0.9, 0.5), 20.0, 2, MonsterTypes.Type.TANK),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.5, 0.1), 60.0, 8, MonsterTypes.Type.BASIC),
			]},
		],
	},
	9: {
		"name": "Escort",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 20.0, 1, MonsterTypes.Type.TANK),
				_g(Vector2(0.5, 0.1), 60.0, 6, MonsterTypes.Type.BASIC),
			]},
			{"delay": 5.0, "groups": [
				_g(Vector2(0.3, 0.1), 20.0, 1, MonsterTypes.Type.TANK),
				_g(Vector2(0.7, 0.1), 20.0, 1, MonsterTypes.Type.TANK),
				_g(Vector2(0.5, 0.1), 80.0, 8, MonsterTypes.Type.BASIC),
			]},
		],
	},
	10: {
		"name": "Fortress",
		"waves": [
			{"delay": 0.0, "groups": [
				_transport(Vector2(0.5, 0.15), MonsterTypes.Type.TANK),
			]},
			{"delay": 5.0, "groups": [
				_g(Vector2(0.2, 0.8), 40.0, 5, MonsterTypes.Type.BASIC),
				_g(Vector2(0.8, 0.8), 40.0, 5, MonsterTypes.Type.BASIC),
			]},
		],
	},

	# --- SPEEDER INTRODUCTION (11-15) ---
	11: {
		"name": "Fast Approach",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.05), 40.0, 4, MonsterTypes.Type.SPEEDER),
			]},
		],
	},
	12: {
		"name": "Blitz",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.1, 0.1), 20.0, 3, MonsterTypes.Type.SPEEDER),
				_g(Vector2(0.9, 0.9), 20.0, 3, MonsterTypes.Type.SPEEDER),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.5, 0.5), 80.0, 6, MonsterTypes.Type.BASIC),
			]},
		],
	},
	13: {
		"name": "Mixed Pace",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 40.0, 3, MonsterTypes.Type.TANK),
				_g(Vector2(0.2, 0.1), 30.0, 4, MonsterTypes.Type.SPEEDER),
				_g(Vector2(0.8, 0.1), 30.0, 4, MonsterTypes.Type.SPEEDER),
			]},
		],
	},
	14: {
		"name": "Speed Demon",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.05), 30.0, 6, MonsterTypes.Type.SPEEDER),
			]},
			{"delay": 2.0, "groups": [
				_g(Vector2(0.05, 0.5), 30.0, 6, MonsterTypes.Type.SPEEDER),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.95, 0.5), 30.0, 6, MonsterTypes.Type.SPEEDER),
			]},
		],
	},
	15: {
		"name": "All Kinds",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.3, 0.1), 50.0, 6, MonsterTypes.Type.BASIC),
				_g(Vector2(0.7, 0.1), 30.0, 3, MonsterTypes.Type.TANK),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.1, 0.5), 30.0, 5, MonsterTypes.Type.SPEEDER),
				_g(Vector2(0.9, 0.5), 30.0, 5, MonsterTypes.Type.SPEEDER),
			]},
		],
	},

	# --- BRUTE + HEALER INTRODUCTION (16-20) ---
	16: {
		"name": "Brute Force",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 40.0, 2, MonsterTypes.Type.BRUTE),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.5, 0.1), 60.0, 8, MonsterTypes.Type.BASIC),
			]},
		],
	},
	17: {
		"name": "Charge!",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.2, 0.1), 20.0, 2, MonsterTypes.Type.BRUTE),
				_g(Vector2(0.8, 0.1), 20.0, 2, MonsterTypes.Type.BRUTE),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.5, 0.9), 60.0, 6, MonsterTypes.Type.SPEEDER),
			]},
		],
	},
	18: {
		"name": "Medic!",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 40.0, 1, MonsterTypes.Type.HEALER),
				_g(Vector2(0.5, 0.1), 60.0, 6, MonsterTypes.Type.BASIC),
			]},
		],
	},
	19: {
		"name": "Resilience",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.3, 0.1), 30.0, 2, MonsterTypes.Type.HEALER),
				_g(Vector2(0.5, 0.1), 40.0, 3, MonsterTypes.Type.TANK),
			]},
			{"delay": 5.0, "groups": [
				_g(Vector2(0.7, 0.9), 30.0, 2, MonsterTypes.Type.BRUTE),
				_g(Vector2(0.3, 0.9), 50.0, 5, MonsterTypes.Type.BASIC),
			]},
		],
	},
	20: {
		"name": "Commander",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 20.0, 1, MonsterTypes.Type.HEALER),
				_g(Vector2(0.3, 0.1), 20.0, 2, MonsterTypes.Type.BRUTE),
				_g(Vector2(0.7, 0.1), 20.0, 2, MonsterTypes.Type.BRUTE),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.5, 0.9), 80.0, 10, MonsterTypes.Type.BASIC),
			]},
		],
	},

	# --- SPAWNER + SPLITTER INTRODUCTION (21-25) ---
	21: {
		"name": "The Hive",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.15), 20.0, 1, MonsterTypes.Type.SPAWNER),
			]},
		],
	},
	22: {
		"name": "Shatter",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.15), 40.0, 3, MonsterTypes.Type.SPLITTER),
			]},
		],
	},
	23: {
		"name": "Nest Defense",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.3, 0.1), 20.0, 1, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.7, 0.1), 20.0, 1, MonsterTypes.Type.HEALER),
			]},
			{"delay": 5.0, "groups": [
				_g(Vector2(0.5, 0.9), 60.0, 4, MonsterTypes.Type.BRUTE),
			]},
		],
	},
	24: {
		"name": "Fracture Zone",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.3, 0.1), 30.0, 3, MonsterTypes.Type.SPLITTER),
				_g(Vector2(0.7, 0.1), 30.0, 3, MonsterTypes.Type.SPEEDER),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.5, 0.9), 30.0, 2, MonsterTypes.Type.TANK),
				_g(Vector2(0.5, 0.9), 60.0, 6, MonsterTypes.Type.BASIC),
			]},
		],
	},
	25: {
		"name": "Swarm Master",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.2, 0.1), 20.0, 1, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.8, 0.1), 20.0, 1, MonsterTypes.Type.SPAWNER),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.5, 0.5), 30.0, 2, MonsterTypes.Type.HEALER),
			]},
			{"delay": 6.0, "groups": [
				_g(Vector2(0.5, 0.9), 60.0, 4, MonsterTypes.Type.SPLITTER),
			]},
		],
	},

	# --- ALL TYPES + GHOST (26-30) ---
	26: {
		"name": "Phantom Menace",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 40.0, 4, MonsterTypes.Type.GHOST),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.5, 0.9), 60.0, 8, MonsterTypes.Type.BASIC),
			]},
		],
	},
	27: {
		"name": "Full Spectrum",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.15, 0.1), 20.0, 3, MonsterTypes.Type.BASIC),
				_g(Vector2(0.38, 0.1), 20.0, 2, MonsterTypes.Type.TANK),
				_g(Vector2(0.62, 0.1), 20.0, 3, MonsterTypes.Type.SPEEDER),
				_g(Vector2(0.85, 0.1), 20.0, 2, MonsterTypes.Type.BRUTE),
			]},
			{"delay": 5.0, "groups": [
				_g(Vector2(0.3, 0.9), 20.0, 1, MonsterTypes.Type.HEALER),
				_g(Vector2(0.5, 0.9), 20.0, 1, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.7, 0.9), 20.0, 2, MonsterTypes.Type.GHOST),
			]},
		],
	},
	28: {
		"name": "Chaos Theory",
		"waves": [
			{"delay": 0.0, "groups": [
				_g(Vector2(0.5, 0.1), 20.0, 2, MonsterTypes.Type.SPLITTER),
				_g(Vector2(0.5, 0.1), 30.0, 1, MonsterTypes.Type.HEALER),
			]},
			{"delay": 3.0, "groups": [
				_g(Vector2(0.1, 0.5), 30.0, 4, MonsterTypes.Type.GHOST),
				_g(Vector2(0.9, 0.5), 30.0, 4, MonsterTypes.Type.SPEEDER),
			]},
			{"delay": 6.0, "groups": [
				_g(Vector2(0.5, 0.9), 20.0, 1, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.5, 0.9), 40.0, 3, MonsterTypes.Type.BRUTE),
			]},
		],
	},
	29: {
		"name": "Onslaught",
		"waves": [
			{"delay": 0.0, "groups": [
				_wall(Vector2(0.5, 0.05), 10, MonsterTypes.Type.BASIC, true),
			]},
			{"delay": 2.0, "groups": [
				_g(Vector2(0.1, 0.5), 20.0, 3, MonsterTypes.Type.BRUTE),
				_g(Vector2(0.9, 0.5), 20.0, 3, MonsterTypes.Type.BRUTE),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.5, 0.9), 20.0, 2, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.5, 0.9), 20.0, 2, MonsterTypes.Type.HEALER),
			]},
			{"delay": 6.0, "groups": [
				_g(Vector2(0.3, 0.1), 30.0, 4, MonsterTypes.Type.GHOST),
				_g(Vector2(0.7, 0.1), 30.0, 4, MonsterTypes.Type.SPLITTER),
			]},
		],
	},
	30: {
		"name": "Final Stand",
		"waves": [
			{"delay": 0.0, "groups": [
				_transport(Vector2(0.5, 0.1), MonsterTypes.Type.TANK),
				_g(Vector2(0.5, 0.1), 20.0, 2, MonsterTypes.Type.HEALER),
			]},
			{"delay": 4.0, "groups": [
				_g(Vector2(0.1, 0.5), 20.0, 1, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.9, 0.5), 20.0, 1, MonsterTypes.Type.SPAWNER),
				_g(Vector2(0.5, 0.9), 30.0, 4, MonsterTypes.Type.BRUTE),
			]},
			{"delay": 7.0, "groups": [
				_g(Vector2(0.2, 0.1), 30.0, 5, MonsterTypes.Type.GHOST),
				_g(Vector2(0.8, 0.1), 30.0, 5, MonsterTypes.Type.SPEEDER),
				_g(Vector2(0.5, 0.1), 40.0, 4, MonsterTypes.Type.SPLITTER),
			]},
			{"delay": 10.0, "groups": [
				_wall(Vector2(0.5, 0.95), 12, MonsterTypes.Type.BASIC, true),
				_g(Vector2(0.5, 0.05), 20.0, 3, MonsterTypes.Type.BRUTE),
			]},
		],
	},
}

# ============================================================
# HELPER FUNCTIONS for level building
# ============================================================

## Creates a basic group definition.
static func _g(pos: Vector2, spread: float, count: int, type: MonsterTypes.Type, spawn_mode: String = "absolute") -> Dictionary:
	return {
		"position": pos,
		"spread": spread,
		"count": count,
		"type": type,
		"spawn_mode": spawn_mode,
	}

## Creates a wall/line formation (horizontal or vertical).
static func _wall(center: Vector2, count: int, type: MonsterTypes.Type, horizontal: bool = true) -> Dictionary:
	return {
		"position": center,
		"count": count,
		"type": type,
		"spawn_mode": "absolute",
		"formation": "wall",
		"horizontal": horizontal,
		"spacing": 0.08,  # Normalized spacing between units
	}

## Creates a 3x3 transport formation.
static func _transport(center: Vector2, type: MonsterTypes.Type) -> Dictionary:
	return {
		"position": center,
		"count": 9,
		"type": type,
		"spawn_mode": "absolute",
		"formation": "grid",
		"grid_size": Vector2i(3, 3),
		"spacing": 0.06,
	}
