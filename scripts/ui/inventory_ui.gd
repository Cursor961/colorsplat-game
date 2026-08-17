class_name InventoryUI
extends Control
## Item inventory display — vertical column of item icons on the RIGHT edge,
## within easy thumb reach. Dark rounded backgrounds distinguish inventory items
## from map pickups. Max 3 slots. Tap an icon to activate/select the item.
## Selected item (grenade) gets a yellow tint.

signal item_tapped(index: int)

const SLOT_SIZE := 156.0   ## 130 × 1.2 (matches HUD_MAG in hud.gd); auto-shrinks if 3 won't fit
const SLOT_GAP := 18.0
const MAX_SLOTS := 3
const EDGE_MARGIN := 24.0  ## Distance from the right screen edge
const TOP_MARGIN := 200.0  ## Below the pause button (top of the column)
const BOTTOM_MARGIN := 24.0 ## To the bottom-right corner

## Touch target padding — invisible area around each icon for easier taps.
const TOUCH_PAD := 10.0

var _slot_containers: Array = []     ## Array of Control (touch wrapper)
var _slot_icons: Array = []          ## Array of TextureRect
var _selected_index: int = -1

# ============================================================
# SCALE FACTOR
# ============================================================
var _sf: float = 1.0

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_game(vp)
	_build_ui()

func _build_ui() -> void:
	# Compute the target slot size and shrink it if 3 slots + gaps don't fit in the
	# available vertical column (viewport height − top/bottom margins). This guarantees
	# the inventory NEVER spills off the screen, no matter the GUI scale.
	var vp := get_viewport().get_visible_rect().size
	var top := TOP_MARGIN * _sf
	var bot := BOTTOM_MARGIN * _sf
	var gap := SLOT_GAP * _sf
	var column_h: float = vp.y - top - bot
	var max_slot_size: float = maxf(48.0, (column_h - gap * (MAX_SLOTS - 1)) / float(MAX_SLOTS))
	var slot_size: float = minf(SLOT_SIZE * _sf, max_slot_size)
	var slot_gap := gap
	var touch_pad := TOUCH_PAD * _sf
	var edge_margin := EDGE_MARGIN * _sf

	# Position: vertical column anchored to the RIGHT edge — spans from BELOW the
	# pause button down to the bottom-right corner. Slots distribute evenly so the
	# tap region covers the whole right-side column (thumb-friendly).
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -(edge_margin + slot_size)
	offset_right = -edge_margin
	offset_top = TOP_MARGIN * _sf
	offset_bottom = -BOTTOM_MARGIN * _sf

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var corner_r := maxi(1, int(16 * _sf))
	var icon_pad := 8.0 * _sf

	# Stack the slots from the TOP of the column with a gap between each.
	for i in MAX_SLOTS:
		var container := Control.new()
		container.size = Vector2(slot_size, slot_size)
		container.position = Vector2(0, i * (slot_size + slot_gap))
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Dark rounded background panel
		var bg := Panel.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.08, 0.12, 0.78)
		style.border_color = Color(0.30, 0.34, 0.46, 0.9)
		style.set_border_width_all(maxi(1, int(2 * _sf)))
		style.corner_radius_top_left = corner_r
		style.corner_radius_top_right = corner_r
		style.corner_radius_bottom_left = corner_r
		style.corner_radius_bottom_right = corner_r
		bg.add_theme_stylebox_override("panel", style)
		container.add_child(bg)

		# Item icon — fills the container with small padding
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = icon_pad
		icon.offset_top = icon_pad
		icon.offset_right = -icon_pad
		icon.offset_bottom = -icon_pad
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon)

		# Invisible touch button — slightly larger than icon for easier taps
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.offset_left = -touch_pad
		btn.offset_top = -touch_pad
		btn.offset_right = touch_pad
		btn.offset_bottom = touch_pad
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_slot_pressed.bind(i))
		container.add_child(btn)

		add_child(container)
		_slot_containers.append(container)
		_slot_icons.append(icon)

		container.visible = false  # Hidden until items are added

## Re-apply the game-GUI scale LIVE: rebuild the slots at the new scale and
## re-populate them from the current inventory.
func rescale_live(inventory: Array, item_manager: ItemManager) -> void:
	for c in _slot_containers:
		if is_instance_valid(c):
			c.queue_free()
	_slot_containers.clear()
	_slot_icons.clear()
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_game(vp)
	_build_ui()
	update_inventory(inventory, item_manager)

## Rebuild slot visuals from current inventory state.
func update_inventory(inventory: Array, item_manager: ItemManager) -> void:
	for i in MAX_SLOTS:
		if i < inventory.size():
			var type: ItemPickup.ItemType = inventory[i]
			var tex: Texture2D = null
			if item_manager:
				tex = item_manager.get_pickup_texture(type)
			_slot_icons[i].texture = tex
			_slot_containers[i].visible = true
		else:
			_slot_icons[i].texture = null
			_slot_containers[i].visible = false
	_apply_selection()

## Highlight/unhighlight the selected slot (grenade aim mode).
func set_selected(index: int) -> void:
	_selected_index = index
	_apply_selection()

func _apply_selection() -> void:
	for i in MAX_SLOTS:
		if not _slot_containers[i].visible:
			continue
		if i == _selected_index:
			# Gold tint for selected grenade
			_slot_icons[i].modulate = Color(1.0, 0.9, 0.3, 1.0)
		else:
			_slot_icons[i].modulate = Color.WHITE

func _on_slot_pressed(index: int) -> void:
	item_tapped.emit(index)
