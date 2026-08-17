class_name LevelMetinSpawner
extends Node2D
## Keeps `count` Metin totems alive on the map. On level start it spawns the initial set;
## whenever one is destroyed it spawns a replacement at a random spot that doesn't overlap
## the remaining totems (or sit on the player). Drives the "Totem" challenge — the
## LevelManager scores stars by how many totems the player destroys (target_destroyed).

@export var count: int = 3
@export var metin_size: float = 80.0
@export var metin_hp: float = 1000.0
@export var spawn_per_damage: float = 350.0
@export var metin_spawn_count: int = 3        ## monsters per damage burst from each totem
@export var min_separation: float = 420.0     ## min gap between totems
@export var edge_margin: float = 220.0
@export var player_clearance: float = 280.0   ## don't spawn a totem on top of the player

const METIN := preload("res://scripts/game/level/level_metin.gd")

var _lm: Node = null
var _active: bool = false

func _ready() -> void:
	_lm = get_tree().get_first_node_in_group("level_manager")
	if _lm and _lm.has_method("register_spawner"):
		_lm.register_spawner(self)

## Called by LevelManager.begin().
func do_spawn() -> void:
	_active = true
	for i in count:
		_spawn_one()

func _process(_delta: float) -> void:
	if not _active:
		return
	# Refill to keep `count` totems on the map (a destroyed one is replaced elsewhere).
	if get_tree().get_nodes_in_group("metins").size() < count:
		_spawn_one()

func _spawn_one() -> void:
	var m := StaticBody2D.new()
	m.set_script(METIN)
	m.set("color", ["blue", "green", "red"].pick_random())
	m.set("size", metin_size)
	m.set("max_hp", metin_hp)
	m.set("random_type", true)
	m.set("spawn_count", metin_spawn_count)
	m.set("spawn_per_damage", spawn_per_damage)
	m.set("drop_count", 1)
	m.global_position = _find_pos()
	get_parent().add_child(m)

func _find_pos() -> Vector2:
	var aw := 1920.0
	var ah := 1080.0
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw:
		aw = float(gw.arena_width)
		ah = float(gw.arena_height)
	var ppos := Vector2(aw * 0.5, ah * 0.5)
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0 and players[0] is Node2D:
		ppos = (players[0] as Node2D).global_position
	var fallback := Vector2(randf_range(edge_margin, aw - edge_margin), randf_range(edge_margin, ah - edge_margin))
	for attempt in 24:
		var p := Vector2(randf_range(edge_margin, aw - edge_margin), randf_range(edge_margin, ah - edge_margin))
		if p.distance_to(ppos) < player_clearance:
			continue
		var ok := true
		for m in get_tree().get_nodes_in_group("metins"):
			if m is Node2D and p.distance_to((m as Node2D).global_position) < min_separation:
				ok = false
				break
		if ok:
			return p
	return fallback
