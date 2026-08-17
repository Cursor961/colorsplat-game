class_name LevelPickupSpawn
extends Node2D
## Spawns a powerup, an item, or a lootcrate at this point when the level starts.
## Choose `kind`, then set the matching type (powerup_type for POWERUP, item_type for
## ITEM; LOOTCRATE ignores both). Enable `repeat` to respawn on an interval.

enum Kind { POWERUP, ITEM, LOOTCRATE }

@export var kind: Kind = Kind.POWERUP
## Used when kind == POWERUP.
@export var powerup_type: Powerup.Type = Powerup.Type.HP_BOOST
## Used when kind == ITEM.
@export var item_type: ItemPickup.ItemType = ItemPickup.ItemType.GRENADE
## Used when kind == LOOTCRATE: force a 100% ITEM drop (otherwise random 40/40/20).
@export var crate_force_item: bool = false
@export var start_delay: float = 0.0
@export_group("Repeat")
@export var repeat: bool = false
@export var repeat_interval: float = 10.0
@export var repeat_max: int = 0   ## 0 = infinite

var _lm: Node = null
var _active: bool = false
var _timer: float = 0.0
var _count: int = 0

func _ready() -> void:
	_lm = get_tree().get_first_node_in_group("level_manager")
	if _lm and _lm.has_method("register_spawner"):
		_lm.register_spawner(self)

func do_spawn() -> void:
	_active = true
	if start_delay <= 0.0:
		_spawn_one()
		_timer = repeat_interval
	else:
		_timer = start_delay

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		if _count == 0 and start_delay > 0.0:
			_spawn_one()
			_timer = repeat_interval
		elif repeat and (repeat_max == 0 or _count <= repeat_max):
			_spawn_one()
			_timer = repeat_interval
		else:
			_active = false

func _spawn_one() -> void:
	_count += 1
	var h: Node = _lm.host if _lm else null
	if h == null:
		return
	match kind:
		Kind.POWERUP:
			if h.has_method("level_spawn_powerup"):
				h.level_spawn_powerup(powerup_type, global_position)
		Kind.ITEM:
			if h.has_method("level_spawn_item"):
				h.level_spawn_item(item_type, global_position)
		Kind.LOOTCRATE:
			if h.has_method("level_spawn_lootcrate"):
				h.level_spawn_lootcrate(global_position, 0 if crate_force_item else -1)
