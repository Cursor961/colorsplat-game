class_name ItemManager
extends Node
## Manages item spawning (map + monster drops), player inventory (max 3),
## and item activation. Items are NOT auto-used; the player chooses when.

signal item_added(type: ItemPickup.ItemType)      ## New item added to inventory
var excluded_types: Array = []   ## item types never randomly spawned (e.g. HP25 in Řezník)
signal item_removed(index: int)                    ## Item used/removed from inventory
signal item_selected(index: int)                   ## Item tapped — waiting for aim (grenade) or instant use
signal inventory_changed                           ## Inventory contents changed (for UI rebuild)

# ---- CONFIG ----
const MAX_INVENTORY := 3
const SPAWN_CHANCE_PER_SEC := 0.04   ## 4% per second (slightly less than powerups)
const SPAWN_MARGIN := 60.0
const MONSTER_DROP_CHANCE := 0.03    ## 3% chance per monster death

# ---- INVENTORY ----
## Array of ItemPickup.ItemType (max 3 entries). Order = left-to-right in HUD.
var inventory: Array = []

# ---- SELECTED ITEM ----
## Index of the item the player tapped (-1 = none selected).
## For grenade: next shot fires grenade instead of bullet.
## For katana/slowpill: instant activation on tap (selected_index stays -1).
var selected_index: int = -1

# ---- SPAWNING ----
var _spawn_check_timer: float = 0.0
var _current_pickup: ItemPickup = null
var _pickup_scene: PackedScene
var _item_container: Node2D
var is_running: bool = false

# ---- ARENA ----
var _arena_width: float = 1920.0
var _arena_height: float = 1080.0

# ---- TEXTURES ----
var _pickup_textures: Dictionary = {}  ## ItemPickup.ItemType -> Texture2D (pickup icons)

func _ready() -> void:
	_pickup_scene = load("res://scenes/game/item_pickup.tscn")
	_load_textures()

func _physics_process(delta: float) -> void:
	if not is_running:
		return

	_spawn_check_timer += delta
	if _spawn_check_timer >= 1.0:
		_spawn_check_timer -= 1.0
		if _current_pickup == null or not is_instance_valid(_current_pickup):
			_current_pickup = null
			if randf() < SPAWN_CHANCE_PER_SEC:
				_spawn_random_item()

# ============================================================
# PUBLIC API
# ============================================================

func start(arena_w: float, arena_h: float, container: Node2D) -> void:
	_arena_width = arena_w
	_arena_height = arena_h
	_item_container = container
	is_running = true
	_spawn_check_timer = 0.0

func stop() -> void:
	is_running = false
	inventory.clear()
	selected_index = -1
	if _current_pickup and is_instance_valid(_current_pickup):
		_current_pickup.queue_free()
	_current_pickup = null
	inventory_changed.emit()

## Try to add an item to inventory. Returns true if added.
func add_item(type: ItemPickup.ItemType) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		return false
	inventory.append(type)
	item_added.emit(type)
	inventory_changed.emit()
	AudioManager.play_sfx("powerup_pickup")
	return true

## Called when player taps item slot at index in inventory UI.
## Returns the item type if it was consumed (instant-use), or the type if it needs aiming.
func use_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return

	var type: ItemPickup.ItemType = inventory[index]

	match type:
		ItemPickup.ItemType.GRENADE:
			# Toggle selection — next aim fires grenade
			if selected_index == index:
				# Deselect
				selected_index = -1
				item_selected.emit(-1)
			else:
				selected_index = index
				item_selected.emit(index)
				AudioManager.play_sfx("grenade_pin")
		ItemPickup.ItemType.LASER:
			# Toggle selection — next shot fires laser
			if selected_index == index:
				selected_index = -1
				item_selected.emit(-1)
			else:
				selected_index = index
				item_selected.emit(index)
				AudioManager.play_sfx("grenade_pin")
		ItemPickup.ItemType.DECOY:
			# Toggle selection — next aim throws the decoy (like grenade)
			if selected_index == index:
				selected_index = -1
				item_selected.emit(-1)
			else:
				selected_index = index
				item_selected.emit(index)
				AudioManager.play_sfx("grenade_pin")
		ItemPickup.ItemType.SLOWPILL:
			# Instant activation
			_consume_item(index)
			AudioManager.play_sfx("powerup_pickup")
		ItemPickup.ItemType.KATANA:
			# Instant activation
			_consume_item(index)   # game_world plays "katana_equip" when the spin spawns
		ItemPickup.ItemType.HP25:
			# Instant activation — heal 25 HP
			_consume_item(index)
			AudioManager.play_sfx("heal")

## Called by game_world when grenade has been fired (consume the selected grenade).
func consume_selected_grenade() -> void:
	if selected_index >= 0 and selected_index < inventory.size():
		_consume_item(selected_index)
	selected_index = -1
	item_selected.emit(-1)

## Called by game_world when laser has been fired (consume the selected laser).
func consume_selected_laser() -> void:
	if selected_index >= 0 and selected_index < inventory.size():
		_consume_item(selected_index)
	selected_index = -1
	item_selected.emit(-1)

## Called by game_world when a decoy has been thrown (consume the selected decoy).
func consume_selected_decoy() -> void:
	if selected_index >= 0 and selected_index < inventory.size():
		_consume_item(selected_index)
	selected_index = -1
	item_selected.emit(-1)

## Check if a grenade is currently selected (next shot should be grenade).
func is_grenade_selected() -> bool:
	if selected_index < 0 or selected_index >= inventory.size():
		selected_index = -1
		return false
	return inventory[selected_index] == ItemPickup.ItemType.GRENADE

## Check if a decoy is currently selected (next aim should throw a decoy).
func is_decoy_selected() -> bool:
	if selected_index < 0 or selected_index >= inventory.size():
		selected_index = -1
		return false
	return inventory[selected_index] == ItemPickup.ItemType.DECOY

## Check if a laser is currently selected (next shot should be laser).
func is_laser_selected() -> bool:
	if selected_index < 0 or selected_index >= inventory.size():
		selected_index = -1
		return false
	return inventory[selected_index] == ItemPickup.ItemType.LASER

func get_pickup_texture(type: ItemPickup.ItemType) -> Texture2D:
	return _pickup_textures.get(type, null)

# ============================================================
# INTERNAL
# ============================================================

func _consume_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	inventory.remove_at(index)
	# Fix selected_index if it was shifted
	if selected_index == index:
		selected_index = -1
	elif selected_index > index:
		selected_index -= 1
	item_removed.emit(index)
	inventory_changed.emit()

func _spawn_random_item() -> void:
	var types := [ItemPickup.ItemType.GRENADE, ItemPickup.ItemType.SLOWPILL, ItemPickup.ItemType.KATANA, ItemPickup.ItemType.LASER, ItemPickup.ItemType.HP25, ItemPickup.ItemType.DECOY]
	types = types.filter(func(t): return not (t in excluded_types))
	if types.is_empty():
		return
	var type: ItemPickup.ItemType = types[randi() % types.size()]
	var pos := Vector2(
		randf_range(SPAWN_MARGIN, _arena_width - SPAWN_MARGIN),
		randf_range(SPAWN_MARGIN, _arena_height - SPAWN_MARGIN)
	)
	_spawn_pickup(type, pos)

## Spawn a SPECIFIC item type at a position (used by level builders).
func spawn_item_type(type: ItemPickup.ItemType, pos: Vector2) -> void:
	_spawn_pickup(type, pos)

func _spawn_item_at(pos: Vector2) -> void:
	# Monster drop — random item type
	var types := [ItemPickup.ItemType.GRENADE, ItemPickup.ItemType.SLOWPILL, ItemPickup.ItemType.KATANA, ItemPickup.ItemType.LASER, ItemPickup.ItemType.HP25, ItemPickup.ItemType.DECOY]
	types = types.filter(func(t): return not (t in excluded_types))
	if types.is_empty():
		return
	var type: ItemPickup.ItemType = types[randi() % types.size()]
	_spawn_pickup(type, pos)

func _spawn_pickup(type: ItemPickup.ItemType, pos: Vector2) -> void:
	if _pickup_scene == null or _item_container == null:
		return
	var pickup: ItemPickup = _pickup_scene.instantiate() as ItemPickup
	var tex: Texture2D = _pickup_textures.get(type, null)
	pickup.initialize(type, tex, 60.0)
	pickup.global_position = pos
	pickup.collected.connect(_on_item_collected)
	# Crate/monster drops can run inside a collision flush (bullet→crate/monster),
	# and adding the pickup registers its CollisionShape2D with the physics server
	# on enter_tree. Defer to avoid "Can't change this state while flushing
	# queries". Position is retained since the container is at the origin.
	_item_container.call_deferred("add_child", pickup)
	# Only track as "current" for periodic spawns (monster drops are extra)
	if _current_pickup == null or not is_instance_valid(_current_pickup):
		_current_pickup = pickup

func _on_item_collected(pickup: ItemPickup) -> void:
	if inventory.size() >= MAX_INVENTORY:
		return  # Inventory full — pickup is already queue_free'd by ItemPickup
	add_item(pickup.item_type)
	if _current_pickup == pickup:
		_current_pickup = null

func _load_textures() -> void:
	var paths: Dictionary = {
		ItemPickup.ItemType.GRENADE: "res://assets/sprites/items/grenade.svg",
		ItemPickup.ItemType.SLOWPILL: "res://assets/sprites/items/slowpill.svg",
		ItemPickup.ItemType.KATANA: "res://assets/sprites/items/katana.svg",
		ItemPickup.ItemType.LASER: "res://assets/sprites/items/laser.svg",
		ItemPickup.ItemType.HP25: "res://assets/sprites/items/hp25.svg",
		ItemPickup.ItemType.DECOY: "res://assets/sprites/items/decoy.svg",
	}
	for type_key: int in paths:
		var path: String = paths[type_key]
		if ResourceLoader.exists(path):
			_pickup_textures[type_key] = load(path)
		else:
			push_warning("ItemManager: texture not found: " + path)
