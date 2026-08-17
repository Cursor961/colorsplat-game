class_name SkinsPopup
extends CanvasLayer
## Skin selection popup — choose the player skin.
## Left: large preview of the equipped skin with its name + description.
## Right: "PLAYER" grid of selectable skins, a divider, then a "TRAIL" section
##        (placeholder — trails not implemented yet).
## Selecting an unlocked skin equips it immediately and persists via SaveManager
## (the game reads the equipped skin in GameWorld._apply_player_sprite).
## Locked skins (milestone-gated) are greyed with their requirement shown; all
## skins are unlocked for now (see SkinData).
##
## Visual style matches StatsPopup / SettingsPopup. Designed for 1920x1080,
## scaled at runtime via _sf. Open/close animation matches the mode selector.

signal closed

# Skin metadata via preload (avoids relying on global class registration).
const SkinMeta := preload("res://scripts/data/skin_data.gd")
const TrailMeta := preload("res://scripts/data/trail_data.gd")
const Anim := preload("res://scripts/utils/popup_anim.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

## Skins unlocked via achievements (not the daily box) — shown with a different
## "unlock it with an achievement" note when locked.
const ACHIEVEMENT_SKINS := ["Player_deprived", "Player_100", "Player_skeleton"]
const LOCK_TEX_PATH := "res://assets/sprites/ui/lock.svg"

# ============================================================
# COLORS
# ============================================================
const OVERLAY_COLOR := Color(0, 0, 0, 0.75)
const PANEL_COLOR := Color(0.10, 0.10, 0.12, 0.97)
const PANEL_BORDER := Color(0.22, 0.22, 0.26)
const PANEL_CORNER := 22

const DIVIDER_COLOR := Color(0.30, 0.30, 0.34)
const HEADER_COLOR := Color.WHITE
const NAME_COLOR := Color.WHITE
const DESC_COLOR := Color(0.78, 0.78, 0.82)
const COMING_SOON_COLOR := Color(0.55, 0.55, 0.60)

const PREVIEW_BG := Color(0.07, 0.07, 0.09, 0.9)
const PREVIEW_BORDER := Color(0.28, 0.28, 0.34)

const THUMB_BG := Color(0.16, 0.16, 0.20, 0.95)
const THUMB_BG_HOVER := Color(0.22, 0.22, 0.28, 0.95)
const THUMB_BORDER := Color(0.32, 0.32, 0.40)
const THUMB_SELECTED_BORDER := Color(0.90, 0.20, 0.95)  ## Magenta highlight
const THUMB_LOCKED_TINT := Color(0.35, 0.35, 0.40, 1.0)

const CLOSE_NORMAL := Color(0.82, 0.14, 0.14)
const CLOSE_HOVER := Color(0.92, 0.22, 0.22)
const CLOSE_PRESSED := Color(0.65, 0.10, 0.10)

# ============================================================
# LAYOUT — design values for 1920x1080
# ============================================================
const PANEL_WIDTH := 1240
const PANEL_HEIGHT := 660
const PANEL_PAD := 36

const TITLE_FONT := 52
const HEADER_FONT := 40
const NAME_FONT := 40
const DESC_FONT := 26
const COMING_SOON_FONT := 30

const CLOSE_BTN_WIDTH := 320
const CLOSE_BTN_HEIGHT := 80
const CLOSE_BTN_FONT := 40
const CLOSE_BTN_CORNER := 16
const CLOSE_BORDER := Color(0.95, 0.40, 0.40)

const LEFT_COL_W := 380
const PREVIEW_SIZE := 250
const PREVIEW_CORNER := 16

const GRID_COLUMNS := 4
const THUMB_SIZE := 150
const THUMB_GAP := 18
const THUMB_CORNER := 14
const THUMB_BORDER_W := 4
const THUMB_ICON_PAD := 20
const LOCK_FONT := 22

# ============================================================
# SCALE FACTOR
# ============================================================
var _sf: float = 1.0

func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

# ============================================================
# NODES / STATE
# ============================================================
var _overlay: ColorRect
var _panel: Panel
var _close_btn: Button
var _name_label: Label
var _desc_label: Label
var _preview_tex: TextureRect
var _grid: GridContainer
var _grid_scroll: ScrollContainer  ## the scroll wrapping the grid (for touch drag)
var _grid_header: Label          ## right-column header ("PLAYER" / "TRAIL")
var _cat_btns: Dictionary = {}   ## category id -> tab Button
var _category: String = "skins"  ## "skins" or "trails"

# ---- Touch drag-to-scroll with inertia (works even when the drag starts on a skin button) ----
const DRAG_THRESHOLD := 12.0     ## px of movement before a press counts as a scroll
const FLING_DECAY := 5.0         ## inertia decay rate (higher = stops sooner)
const FLING_MIN_START := 45.0    ## min release speed (px/s) to keep gliding
const FLING_MIN_STOP := 8.0      ## speed below which the glide stops
var _drag_active: bool = false
var _drag_start_y: float = 0.0
var _drag_start_scroll: int = 0
var _drag_moved: bool = false    ## set true once a touch becomes a drag (suppresses the tap)
var _scroll_f: float = 0.0       ## float mirror of scroll_vertical for smooth momentum
var _fling_vel: float = 0.0      ## inertial scroll velocity (px/s) after release
var _last_drag_y: float = 0.0
var _last_drag_t: float = 0.0

var _lilita: Font
var _lock_tex: Texture2D
var _selected_id: String = "default"

## id -> { "button": Button, "icon": TextureRect, "lock": Label }
var _entries: Dictionary = {}

var _popup_tween: Tween

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	# Tighter fit fraction (0.92) so the CLOSE button always clears the screen edge.
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_WIDTH, PANEL_HEIGHT), 0.92)
	_load_font()
	if ResourceLoader.exists(LOCK_TEX_PATH):
		_lock_tex = load(LOCK_TEX_PATH)
	_build_overlay()
	_build_panel()
	visible = false

## Touch/mouse drag-to-scroll for the skin grid — works even when the drag starts on a
## skin button (the button's tap is suppressed once the press becomes a drag).
func _input(event: InputEvent) -> void:
	if not visible or _grid_scroll == null:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			# Don't hijack a press that lands on the scrollbar grabber — let the native
			# VScrollBar handle it, so dragging the bar scrolls the normal way (not inverted).
			var vbar := _grid_scroll.get_v_scroll_bar()
			var on_scrollbar: bool = vbar != null and vbar.visible and vbar.get_global_rect().has_point(event.position)
			if not on_scrollbar and _grid_scroll.get_global_rect().has_point(event.position):
				_drag_active = true
				_drag_moved = false
				_drag_start_y = event.position.y
				_drag_start_scroll = _grid_scroll.scroll_vertical
				_scroll_f = float(_grid_scroll.scroll_vertical)
				_fling_vel = 0.0
				_last_drag_y = event.position.y
				_last_drag_t = float(Time.get_ticks_msec()) / 1000.0
		else:
			# Released: keep _fling_vel so _process glides; drop it for tiny flicks or
			# if the finger was held still just before lifting.
			if _drag_active:
				var held := (float(Time.get_ticks_msec()) / 1000.0) - _last_drag_t > 0.05
				if held or absf(_fling_vel) < FLING_MIN_START:
					_fling_vel = 0.0
			_drag_active = false
	elif _drag_active and (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)):
		var dy: float = event.position.y - _drag_start_y
		if absf(dy) > DRAG_THRESHOLD:
			_drag_moved = true
		var now := float(Time.get_ticks_msec()) / 1000.0
		var dt := now - _last_drag_t
		if dt > 0.0005:
			_fling_vel = -(event.position.y - _last_drag_y) / dt  # scroll moves opposite the finger
			_last_drag_y = event.position.y
			_last_drag_t = now
		_scroll_f = float(_drag_start_scroll) - dy
		_grid_scroll.scroll_vertical = int(round(_scroll_f))
		get_viewport().set_input_as_handled()  # don't let the grid double-scroll

## Inertial glide after the finger lifts.
func _process(delta: float) -> void:
	if _drag_active or not visible or _grid_scroll == null:
		return
	if absf(_fling_vel) <= FLING_MIN_STOP:
		_fling_vel = 0.0
		return
	var max_scroll := 0.0
	var vbar := _grid_scroll.get_v_scroll_bar()
	if vbar:
		max_scroll = maxf(0.0, vbar.max_value - vbar.page)
	_scroll_f += _fling_vel * delta
	if _scroll_f <= 0.0:
		_scroll_f = 0.0
		_fling_vel = 0.0
	elif _scroll_f >= max_scroll:
		_scroll_f = max_scroll
		_fling_vel = 0.0
	_grid_scroll.scroll_vertical = int(round(_scroll_f))
	_fling_vel *= exp(-FLING_DECAY * delta)

func _load_font() -> void:
	_lilita = UIT.load_font()

# ============================================================
# BUILD
# ============================================================

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH * _sf, PANEL_HEIGHT * _sf)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = PANEL_COLOR
	ps.border_color = PANEL_BORDER
	ps.set_border_width_all(_s(3))
	ps.set_corner_radius_all(_s(PANEL_CORNER))
	_panel.add_theme_stylebox_override("panel", ps)
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = maxf(PANEL_PAD * _sf, 10.0)
	root.offset_right = -maxf(PANEL_PAD * _sf, 10.0)
	root.offset_top = (PANEL_PAD - 6) * _sf
	root.offset_bottom = -PANEL_PAD * _sf
	root.add_theme_constant_override("separation", _s(20))
	_panel.add_child(root)

	_build_title_bar(root)
	_build_category_tabs(root)

	# Body: left preview column | divider | right selection column
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", _s(24))
	root.add_child(body)

	body.add_child(_build_left_column())

	var vdiv := ColorRect.new()
	vdiv.color = DIVIDER_COLOR
	vdiv.custom_minimum_size = Vector2(_s(3), 0)
	vdiv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(vdiv)

	body.add_child(_build_right_column())

	_build_close_row(root)

	_refresh_category()

func _build_title_bar(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = Loc.t("select_skin")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title, TITLE_FONT, Color.WHITE, 6)
	parent.add_child(title)

func _build_close_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	_close_btn = Button.new()
	_close_btn.text = Loc.t("close")
	_close_btn.custom_minimum_size = Vector2(CLOSE_BTN_WIDTH * _sf, CLOSE_BTN_HEIGHT * _sf)
	_close_btn.add_theme_stylebox_override("normal", _make_sb(CLOSE_NORMAL, CLOSE_BORDER, CLOSE_BTN_CORNER, 3))
	_close_btn.add_theme_stylebox_override("hover", _make_sb(CLOSE_HOVER, CLOSE_BORDER, CLOSE_BTN_CORNER, 3))
	_close_btn.add_theme_stylebox_override("pressed", _make_sb(CLOSE_PRESSED, CLOSE_BORDER, CLOSE_BTN_CORNER, 3))
	_close_btn.add_theme_stylebox_override("focus", _make_sb(CLOSE_NORMAL, CLOSE_BORDER, CLOSE_BTN_CORNER, 3))
	_apply_font(_close_btn, CLOSE_BTN_FONT, Color.WHITE, 5)
	_close_btn.pressed.connect(_on_close)
	row.add_child(_close_btn)

func _build_left_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(LEFT_COL_W * _sf, 0)
	col.add_theme_constant_override("separation", _s(12))

	_name_label = Label.new()
	_name_label.text = ""
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_name_label, NAME_FONT, NAME_COLOR, 5)
	col.add_child(_name_label)

	var top_sp := Control.new()
	top_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top_sp)

	# Preview box (centered)
	var prev_row := HBoxContainer.new()
	prev_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prev_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(prev_row)

	var prev_panel := Panel.new()
	prev_panel.custom_minimum_size = Vector2(PREVIEW_SIZE * _sf, PREVIEW_SIZE * _sf)
	var pbs := StyleBoxFlat.new()
	pbs.bg_color = PREVIEW_BG
	pbs.border_color = PREVIEW_BORDER
	pbs.set_border_width_all(_s(3))
	pbs.set_corner_radius_all(_s(PREVIEW_CORNER))
	prev_panel.add_theme_stylebox_override("panel", pbs)
	prev_row.add_child(prev_panel)

	_preview_tex = TextureRect.new()
	_preview_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_tex.offset_left = PANEL_PAD * _sf
	_preview_tex.offset_right = -PANEL_PAD * _sf
	_preview_tex.offset_top = PANEL_PAD * _sf
	_preview_tex.offset_bottom = -PANEL_PAD * _sf
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev_panel.add_child(_preview_tex)

	var bot_sp := Control.new()
	bot_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bot_sp)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, _s(90))
	_apply_font(_desc_label, DESC_FONT, DESC_COLOR, 3)
	col.add_child(_desc_label)

	return col

func _build_right_column() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", _s(10))

	_grid_header = Label.new()
	_grid_header.text = Loc.t("player")
	_apply_font(_grid_header, HEADER_FONT, HEADER_COLOR, 5)
	col.add_child(_grid_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	Anim.style_scrollbar(scroll, _sf)
	_grid_scroll = scroll

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", _s(THUMB_GAP))
	_grid.add_theme_constant_override("v_separation", _s(THUMB_GAP))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	return col

# ============================================================
# CATEGORY TABS (Skins / Trails / ...)
# ============================================================

func _build_category_tabs(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(14))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	for cat: Array in [[Loc.t("cat_skins"), "skins"], [Loc.t("cat_trails"), "trails"]]:
		var key: String = cat[1]
		var btn := Button.new()
		btn.text = cat[0]
		btn.custom_minimum_size = Vector2(_s(230), _s(64))
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_category_selected.bind(key))
		_apply_font(btn, HEADER_FONT, Color.WHITE, 4)
		row.add_child(btn)
		_cat_btns[key] = btn

	_update_category_visuals()

func _on_category_selected(cat: String) -> void:
	if cat == _category:
		return
	AudioManager.play_sfx("button_click_menu")
	_category = cat
	_refresh_category()

## Repopulate the grid + preview + header for the active category.
func _refresh_category() -> void:
	_update_category_visuals()
	if _grid_header:
		_grid_header.text = Loc.t("player") if _category == "skins" else Loc.t("trail")
	_populate_grid()
	_select_item(_cat_equipped(), false)

func _update_category_visuals() -> void:
	for key: String in _cat_btns:
		var btn: Button = _cat_btns[key]
		var sel := key == _category
		var bg := THUMB_SELECTED_BORDER if sel else THUMB_BG
		var border := THUMB_SELECTED_BORDER if sel else THUMB_BORDER
		btn.add_theme_stylebox_override("normal", _make_sb(bg if sel else THUMB_BG, border, THUMB_CORNER, 2 if not sel else 3))
		btn.add_theme_stylebox_override("hover", _make_sb(THUMB_BG_HOVER, border, THUMB_CORNER, 2 if not sel else 3))
		btn.add_theme_stylebox_override("pressed", _make_sb(THUMB_BG_HOVER, border, THUMB_CORNER, 3))
		btn.add_theme_stylebox_override("focus", _make_sb(THUMB_BG, border, THUMB_CORNER, 2))

# ============================================================
# CATEGORY DATA HELPERS (skins vs trails)
# ============================================================

func _cat_ids() -> Array:
	if _category == "trails":
		var out: Array = []
		for t: Dictionary in TrailMeta.TRAILS:
			out.append(t.get("id", ""))
		return out
	var ids: Array = []
	for s in SpriteLoader.get_available_skins():
		ids.append(s)
	return ids

func _cat_texture(id: String) -> Texture2D:
	if _category == "trails":
		# Use the dedicated preview ("nahled") art for menu thumbnails + preview.
		var p := TrailMeta.preview_path(id)
		return load(p) if p != "" and ResourceLoader.exists(p) else null
	return SpriteLoader.get_player_texture(id)

func _cat_name(id: String) -> String:
	return TrailMeta.display_name(id) if _category == "trails" else SkinMeta.get_display_name(id)

func _cat_desc(id: String) -> String:
	return TrailMeta.get_desc(id) if _category == "trails" else SkinMeta.get_description(id)

func _cat_equipped() -> String:
	return SaveManager.get_equipped_trail() if _category == "trails" else SaveManager.get_equipped_skin()

func _cat_equip(id: String) -> void:
	if _category == "trails":
		SaveManager.equip_trail(id)
	else:
		SaveManager.equip_skin(id)

func _cat_unlocked(id: String) -> bool:
	# "Unlocked" now means OWNED — everything except default/none must be won from
	# the daily lucky box (Odměny).
	return SaveManager.is_trail_owned(id) if _category == "trails" else SaveManager.is_skin_owned(id)

# ============================================================
# SKIN GRID
# ============================================================

func _populate_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_entries.clear()
	for id in _cat_ids():
		_grid.add_child(_make_item_button(String(id)))

func _make_item_button(id: String) -> Control:
	var unlocked := _cat_unlocked(id)

	var btn := Button.new()
	btn.name = "Item_" + id
	btn.custom_minimum_size = Vector2(THUMB_SIZE * _sf, THUMB_SIZE * _sf)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_item_pressed.bind(id))

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = THUMB_ICON_PAD * _sf
	icon.offset_right = -THUMB_ICON_PAD * _sf
	icon.offset_top = THUMB_ICON_PAD * _sf
	icon.offset_bottom = -THUMB_ICON_PAD * _sf
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _cat_texture(id)
	if not unlocked:
		icon.modulate = THUMB_LOCKED_TINT
	btn.add_child(icon)

	# Overlay: a custom lock icon when locked; otherwise (for the blank "none" trail)
	# the item's name so the thumbnail isn't empty.
	var overlay: Control = null
	if not unlocked:
		var lock_icon := TextureRect.new()
		lock_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		var lpad := THUMB_SIZE * 0.30
		lock_icon.offset_left = lpad * _sf
		lock_icon.offset_right = -lpad * _sf
		lock_icon.offset_top = lpad * _sf
		lock_icon.offset_bottom = -lpad * _sf
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.texture = _lock_tex
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_icon)
		overlay = lock_icon
	elif icon.texture == null:
		var name_lbl := Label.new()
		name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_font(name_lbl, LOCK_FONT, Color(0.7, 0.7, 0.75), 3)
		name_lbl.text = _cat_name(id)
		btn.add_child(name_lbl)
		overlay = name_lbl

	_entries[id] = {"button": btn, "icon": icon, "lock": overlay}
	_apply_thumb_style(btn, false)
	return btn

func _apply_thumb_style(btn: Button, selected: bool) -> void:
	var border_col := THUMB_SELECTED_BORDER if selected else THUMB_BORDER
	var bw := THUMB_BORDER_W if selected else 2
	btn.add_theme_stylebox_override("normal", _make_sb(THUMB_BG, border_col, THUMB_CORNER, bw))
	btn.add_theme_stylebox_override("hover", _make_sb(THUMB_BG_HOVER, border_col, THUMB_CORNER, bw))
	btn.add_theme_stylebox_override("pressed", _make_sb(THUMB_BG_HOVER, border_col, THUMB_CORNER, bw))
	btn.add_theme_stylebox_override("focus", _make_sb(THUMB_BG, border_col, THUMB_CORNER, bw))

# ============================================================
# SELECTION
# ============================================================

func _on_item_pressed(id: String) -> void:
	# If this press was actually a scroll drag, ignore it (don't equip).
	if _drag_moved:
		_drag_moved = false
		return
	AudioManager.play_sfx("button_click_menu")
	# Always preview the clicked item — even when it's locked or already equipped
	# (fixes the preview getting stuck on a locked item).
	_update_preview(id)
	if not _cat_unlocked(id):
		# Locked: blink the lock, don't equip.
		var entry: Dictionary = _entries.get(id, {})
		var lock: Control = entry.get("lock")
		if lock:
			var tw := lock.create_tween()
			tw.tween_property(lock, "modulate:a", 0.3, 0.1)
			tw.tween_property(lock, "modulate:a", 1.0, 0.1)
		return
	if id == _selected_id:
		return
	_select_item(id, true)

func _select_item(id: String, persist: bool) -> void:
	# Restyle borders: clear old, highlight new.
	if _entries.has(_selected_id):
		_apply_thumb_style(_entries[_selected_id]["button"], false)
	_selected_id = id
	if _entries.has(id):
		_apply_thumb_style(_entries[id]["button"], true)
	_update_preview(id)
	if persist:
		_cat_equip(id)

func _update_preview(id: String) -> void:
	if _preview_tex:
		_preview_tex.texture = _cat_texture(id)
	if _name_label:
		_name_label.text = _cat_name(id)
	if _desc_label:
		if _cat_unlocked(id):
			_desc_label.text = _cat_desc(id)
		elif _category == "skins" and id in ACHIEVEMENT_SKINS:
			_desc_label.text = Loc.t("locked_in_achievement")
		else:
			_desc_label.text = Loc.t("locked_in_rewards")

# ============================================================
# OPEN / CLOSE + ANIMATION
# ============================================================

## Open the popup directly on a given category ("skins" / "trails").
func show_category(cat: String) -> void:
	_category = cat
	show_popup()

func show_popup() -> void:
	# Refresh in case skins/trails or equipped selection changed since last open.
	_refresh_category()
	visible = true
	_animate_open()

func hide_popup() -> void:
	visible = false

func _animate_open() -> void:
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_overlay.color = Color(OVERLAY_COLOR.r, OVERLAY_COLOR.g, OVERLAY_COLOR.b, 0.0)
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_overlay, "color:a", OVERLAY_COLOR.a, 0.25).set_ease(Tween.EASE_OUT)
	if _panel:
		_panel.pivot_offset = _panel.size / 2.0
		_panel.scale = Vector2(0.5, 0.5)
		_panel.modulate.a = 0.0
		_popup_tween.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_popup_tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

func _on_close() -> void:
	AudioManager.play_sfx("button_click_menu")
	_animate_close()

func _animate_close() -> void:
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_overlay, "color:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	if _panel:
		_panel.pivot_offset = _panel.size / 2.0
		_popup_tween.tween_property(_panel, "scale", Vector2(0.7, 0.7), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		_popup_tween.tween_property(_panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	_popup_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)

# ============================================================
# CALLBACKS / HELPERS
# ============================================================

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _apply_font(ctrl: Control, size: int, color: Color, outline: int) -> void:
	if _lilita:
		ctrl.add_theme_font_override("font", _lilita)
	ctrl.add_theme_font_size_override("font_size", _s(size))
	ctrl.add_theme_color_override("font_color", color)
	if ctrl is Button:
		ctrl.add_theme_color_override("font_hover_color", color)
		ctrl.add_theme_color_override("font_pressed_color", color)
	if outline > 0:
		ctrl.add_theme_constant_override("outline_size", _s(outline))
		ctrl.add_theme_color_override("font_outline_color", Color.BLACK)

func _make_sb(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 12.0, 8.0)
