class_name LevelSelectPopup
extends CanvasLayer
## Level-select screen (Play → ÚROVNĚ). A horizontal strip of level cards (1 → 30,
## left to right). Each card shows a preview image, the earned star rating and the
## best completion time (speed record). A bottom bar holds MENU (back to the play
## popup), the currently-selected level, and PLAY. Levels beyond the player's
## progress are locked (greyed + padlock, not selectable).
##
## Built entirely in code to match the rest of the menu UI. PLAY emits
## `level_selected`; main_menu loads the matching scenes/levels/level_N.tscn.

const LevelData := preload("res://scripts/data/level_data.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const Anim := preload("res://scripts/utils/popup_anim.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

signal menu_requested                   ## MENU / outside-tap → caller reopens the play popup
signal level_selected(level_num: int)   ## PLAY → caller launches the chosen level

# ---- COLORS ----
const OVERLAY_COLOR := Color(0, 0, 0, 0.80)
const PANEL_COLOR := Color(0.10, 0.10, 0.13, 0.98)
const PANEL_BORDER := Color(0.25, 0.30, 0.45)
const CARD_BG := Color(0.17, 0.18, 0.23)
const CARD_BORDER := Color(0.28, 0.30, 0.40)
const CARD_BAND := Color(0.09, 0.09, 0.12)
const PREVIEW_BG := Color(0.22, 0.23, 0.28)
const SELECT_CYAN := Color(0.26, 0.80, 1.0)
const LOCK_DIM := Color(0.04, 0.04, 0.06, 0.62)
const DIVIDER := Color(0.25, 0.30, 0.45, 0.6)
const MENU_RED := Color(0.80, 0.18, 0.18)
const PLAY_GREEN := Color(0.20, 0.66, 0.23)

# ---- LAYOUT (design 1920x1080) ----
const PANEL_W := 1500
const PANEL_H := 780
const CARD_W := 380
const CARD_H := 470
const CARD_PAD := 10      ## inset of card content, so the rounded body shows as a frame
const CARD_CORNER := 12
const PREVIEW_H := 300
const STAR_SZ := 58
const CARD_TITLE_FONT := 42
const TIME_FONT := 34
const SELECTED_HDR_FONT := 32
const SELECTED_LVL_FONT := 46
const BTN_FONT := 44
const BOTTOM_BAR_H := 124

# ---- drag-to-scroll (horizontal) ----
const DRAG_THRESHOLD := 12.0
const FLING_DECAY := 5.0
const FLING_MIN_START := 45.0
const FLING_MIN_STOP := 8.0
var _drag_active: bool = false
var _drag_start_x: float = 0.0
var _drag_start_scroll: int = 0
var _drag_moved: bool = false    ## suppresses a card tap once the press becomes a scroll
var _scroll_f: float = 0.0
var _fling_vel: float = 0.0
var _last_drag_x: float = 0.0
var _last_drag_t: float = 0.0

var _sf: float = 1.0
func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

var _lilita: Font
var _overlay: ColorRect
var _panel: Panel
var _scroll: ScrollContainer
var _strip: HBoxContainer
var _selected: int = 1
var _cards: Dictionary = {}     ## level_num -> Panel (border overlay), for restyle on selection
var _selected_label: Label
var _play_btn: Button

# ---- unlock reveal (beating 29 → level 30 unlocks with an animation) ----
var _locked_state: Dictionary = {}   ## level_num -> bool; live lock state (flipped by the reveal)
var _lock_nodes: Dictionary = {}     ## level_num -> {dim: ColorRect, lock: TextureRect}
var _force_lock_level: int = -1      ## while building: render this level locked even if unlocked

func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_W, PANEL_H), 0.98)
	_lilita = UIT.load_font()
	_build()
	visible = false

# ============================================================
# BUILD
# ============================================================

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Tapping outside the panel = same as MENU (back to the play popup).
	_overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_on_menu())
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(PANEL_W * _sf, PANEL_H * _sf)
	var ps := StyleBoxFlat.new()
	ps.bg_color = PANEL_COLOR
	ps.border_color = PANEL_BORDER
	ps.set_border_width_all(_s(3))
	ps.set_corner_radius_all(_s(24))
	_panel.add_theme_stylebox_override("panel", ps)
	center.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = _s(40); vb.offset_right = -_s(40)
	vb.offset_top = _s(36); vb.offset_bottom = -_s(28)
	vb.add_theme_constant_override("separation", _s(16))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	# Card strip centred vertically in the upper area (spacers above + below).
	var top_sp := _spacer()
	vb.add_child(top_sp)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, CARD_H * _sf)
	_scroll.size_flags_horizontal = Control.SIZE_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# SHOW_NEVER hides the scrollbar but keeps scrolling (drag + programmatic) working.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(_scroll)

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", _s(26))
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_strip)

	_build_cards()

	vb.add_child(_spacer())

	# Thin divider, then the bottom bar (the screen's "second part").
	var line := ColorRect.new()
	line.color = DIVIDER
	line.custom_minimum_size = Vector2(0, _s(2))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(line)
	vb.add_child(_build_bottom_bar())

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _build_cards() -> void:
	for c in _strip.get_children():
		c.queue_free()
	_cards.clear()
	_locked_state.clear()
	_lock_nodes.clear()
	_wire_rects.clear()   # rebuilt below; old rects are being freed
	var unlocked := SaveManager.get_levels_unlocked()
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var locked := n > unlocked
		# The FINAL boss level needs at least BRONZE on every level (skips give 0 stars).
		# In DEBUG builds (editor testing) the gate is off; it applies in the release APK.
		if n == 30 and not OS.is_debug_build() and not _all_levels_bronze():
			locked = true
		# Unlock reveal: render this level locked even though it's really unlocked, so the
		# padlock is on screen for _play_unlock_animation() to break.
		if n == _force_lock_level:
			locked = true
		_strip.add_child(_make_card(n, locked))

func _all_levels_bronze() -> bool:
	for i in range(1, 30):
		if SaveManager.get_level_stars(i) < 1:
			return false
	return true

func _make_card(n: int, locked: bool) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(CARD_W * _sf, CARD_H * _sf)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_card_body(card)

	# Content is inset so the card's rounded body shows as a thin frame around it.
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = _s(CARD_PAD); content.offset_right = -_s(CARD_PAD)
	content.offset_top = _s(CARD_PAD); content.offset_bottom = -_s(CARD_PAD)
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	# --- preview (top) ---
	var preview := Panel.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(0, PREVIEW_H * _sf)
	preview.clip_contents = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pst := StyleBoxFlat.new()
	pst.bg_color = PREVIEW_BG
	preview.add_theme_stylebox_override("panel", pst)
	content.add_child(preview)

	var tex := _level_wireframe_texture(n)
	if tex:
		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.offset_left = _s(10); img.offset_right = -_s(10)
		img.offset_top = _s(10); img.offset_bottom = -_s(10)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # whole minimap visible
		img.texture = tex
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(img)
		_wire_rects.append({"rect": img, "n": n})   # registered for the hazard blink

	var title := Label.new()
	title.text = "%s %d" % [Loc.t("level"), n]
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = _s(14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font(title, CARD_TITLE_FONT, Color.WHITE, 6)
	preview.add_child(title)

	# --- band (bottom): stars + best time ---
	var band := Panel.new()
	band.custom_minimum_size = Vector2(0, (CARD_H - PREVIEW_H) * _sf)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bst := StyleBoxFlat.new()
	bst.bg_color = CARD_BAND
	band.add_theme_stylebox_override("panel", bst)
	content.add_child(band)

	var bvb := VBoxContainer.new()
	bvb.set_anchors_preset(Control.PRESET_FULL_RECT)
	bvb.alignment = BoxContainer.ALIGNMENT_CENTER
	bvb.add_theme_constant_override("separation", _s(12))
	bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(bvb)

	bvb.add_child(_make_star_row(SaveManager.get_level_stars(n)))

	var time_lbl := Label.new()
	var best := SaveManager.get_level_time(n)
	time_lbl.text = _format_time(best)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# GREEN when a best time exists (personal record on the card), grey placeholder otherwise.
	_font(time_lbl, TIME_FONT, Color(0.35, 1.0, 0.45) if best > 0.0 else Color(0.85, 0.88, 0.95), 4)
	bvb.add_child(time_lbl)

	# --- locked overlay ---
	_locked_state[n] = locked
	if locked:
		var dim := ColorRect.new()
		dim.color = LOCK_DIM
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(dim)
		var lsz := _s(120)
		var lock := TextureRect.new()
		if ResourceLoader.exists("res://assets/sprites/ui/lock.svg"):
			lock.texture = load("res://assets/sprites/ui/lock.svg")
		lock.set_anchors_preset(Control.PRESET_CENTER)
		lock.offset_left = -lsz * 0.5; lock.offset_right = lsz * 0.5
		lock.offset_top = -lsz * 0.5; lock.offset_bottom = lsz * 0.5
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.pivot_offset = Vector2(lsz, lsz) * 0.5
		card.add_child(lock)
		_lock_nodes[n] = {"dim": dim, "lock": lock}

	# Border overlay on top of everything — carries the selection highlight (cyan) so it
	# is never hidden behind the preview/band panels.
	var bord := Panel.new()
	bord.set_anchors_preset(Control.PRESET_FULL_RECT)
	bord.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bord)
	_apply_card_style(bord, n == _selected)

	card.pressed.connect(func() -> void:
		# A drag that started on this card scrolled the strip → don't treat as a tap.
		if _drag_moved:
			_drag_moved = false
			return
		AudioManager.play_sfx("button_click_menu")
		if _locked_state.get(n, false):
			return   # locked levels can't be selected (live state — the reveal flips it)
		_set_selected(n))

	_cards[n] = bord
	return card

func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, BOTTOM_BAR_H * _sf)
	bar.add_theme_constant_override("separation", _s(20))

	var menu_b := Button.new()
	menu_b.text = Loc.t("menu")
	menu_b.custom_minimum_size = Vector2(280 * _sf, 100 * _sf)
	menu_b.focus_mode = Control.FOCUS_NONE
	menu_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_btn(menu_b, MENU_RED, MENU_RED.lightened(0.12), MENU_RED.darkened(0.12))
	_font(menu_b, BTN_FONT, Color.WHITE, 5)
	menu_b.pressed.connect(_on_menu)
	bar.add_child(menu_b)

	var center_vb := VBoxContainer.new()
	center_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vb.add_theme_constant_override("separation", _s(2))
	center_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hdr := Label.new()
	hdr.text = Loc.t("selected")
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(hdr, SELECTED_HDR_FONT, SELECT_CYAN, 4)
	center_vb.add_child(hdr)
	_selected_label = Label.new()
	_selected_label.text = "%s %d" % [Loc.t("level"), _selected]
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_selected_label, SELECTED_LVL_FONT, Color.WHITE, 5)
	center_vb.add_child(_selected_label)
	bar.add_child(center_vb)

	_play_btn = Button.new()
	_play_btn.text = Loc.t("play")
	_play_btn.custom_minimum_size = Vector2(300 * _sf, 110 * _sf)
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_btn(_play_btn, PLAY_GREEN, PLAY_GREEN.lightened(0.12), PLAY_GREEN.darkened(0.12))
	_font(_play_btn, BTN_FONT, Color.WHITE, 5)
	_play_btn.pressed.connect(_on_play)
	bar.add_child(_play_btn)
	return bar

# ============================================================
# SELECTION
# ============================================================

func _set_selected(n: int) -> void:
	var prev := _selected
	_selected = n
	if prev != n and _cards.has(prev) and is_instance_valid(_cards[prev]):
		_apply_card_style(_cards[prev], false)
	if _cards.has(n) and is_instance_valid(_cards[n]):
		_apply_card_style(_cards[n], true)
	if _selected_label:
		_selected_label.text = "%s %d" % [Loc.t("level"), n]

## The card body (background) — constant; the selection highlight lives on the overlay.
func _apply_card_body(card: Button) -> void:
	var bgs := {"normal": CARD_BG, "hover": CARD_BG.lightened(0.06), "pressed": CARD_BG.darkened(0.05), "focus": CARD_BG}
	for st: String in bgs:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bgs[st]
		sb.set_corner_radius_all(_s(CARD_CORNER))
		card.add_theme_stylebox_override(st, sb)

## Border overlay style: bright cyan + thick when selected, subtle otherwise.
func _apply_card_style(bord: Panel, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = SELECT_CYAN if selected else CARD_BORDER
	sb.set_border_width_all(_s(6) if selected else _s(2))
	sb.set_corner_radius_all(_s(CARD_CORNER))
	bord.add_theme_stylebox_override("panel", sb)

## First unlocked level that isn't completed yet (the natural "continue" point); if
## everything unlocked is already done, the newest unlocked level.
func _default_selected_level() -> int:
	var cap := mini(SaveManager.get_levels_unlocked(), LevelData.TOTAL_LEVELS)
	for n in range(1, cap + 1):
		if SaveManager.get_level_stars(n) <= 0:
			return n
	return maxi(1, cap)

# ============================================================
# OPEN / CLOSE
# ============================================================

func show_popup() -> void:
	_build_cards()   # refresh stars / times / locks from the latest save
	_selected = _default_selected_level()
	for k in _cards.keys():
		if is_instance_valid(_cards[k]):
			_apply_card_style(_cards[k], k == _selected)
	if _selected_label:
		_selected_label.text = "%s %d" % [Loc.t("level"), _selected]
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)
	_scroll_to_selected()

## Open the popup focused on `level_num` and play its unlock reveal: the level renders
## LOCKED (padlock on screen), then the padlock shakes, bursts and fades while the dim
## overlay clears and the border flashes — with the level30unlock sound. Used when the
## player beats level 29 (which unlocks the finale). If the level isn't genuinely unlocked
## yet (e.g. an earlier level was ad-skipped to 0 stars), falls back to a normal open.
func show_with_unlock(level_num: int) -> void:
	var truly_unlocked := level_num <= SaveManager.get_levels_unlocked()
	if level_num == 30 and not OS.is_debug_build() and not _all_levels_bronze():
		truly_unlocked = false
	if not truly_unlocked:
		show_popup()
		return
	_force_lock_level = level_num     # render the target locked so the padlock is there to break
	_build_cards()
	_force_lock_level = -1
	_selected = level_num
	for k in _cards.keys():
		if is_instance_valid(_cards[k]):
			_apply_card_style(_cards[k], k == _selected)
	if _selected_label:
		_selected_label.text = "%s %d" % [Loc.t("level"), level_num]
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)
	await _scroll_to_selected()
	await get_tree().create_timer(0.5).timeout    # let the panel settle before the reveal
	_play_unlock_animation(level_num)

## The padlock-break reveal on card `n`. Flips the live lock state (so the card becomes
## selectable), plays the sound, and animates the padlock + dim + border.
func _play_unlock_animation(n: int) -> void:
	_locked_state[n] = false
	AudioManager.play_sfx("level30unlock")
	var nodes: Dictionary = _lock_nodes.get(n, {})
	var lock := (nodes.get("lock") as TextureRect)
	var dim := (nodes.get("dim") as ColorRect)
	var bord := (_cards.get(n) as Panel)

	# Padlock: rattle, then burst outward while fading to nothing.
	if is_instance_valid(lock):
		var lt := create_tween()
		lt.tween_property(lock, "rotation", deg_to_rad(14), 0.05)
		lt.tween_property(lock, "rotation", deg_to_rad(-14), 0.07)
		lt.tween_property(lock, "rotation", deg_to_rad(9), 0.06)
		lt.tween_property(lock, "rotation", deg_to_rad(-5), 0.05)
		lt.tween_property(lock, "scale", Vector2(1.8, 1.8), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		lt.parallel().tween_property(lock, "modulate:a", 0.0, 0.16)
		lt.tween_callback(lock.queue_free)

	# Dim overlay clears just after the rattle.
	if is_instance_valid(dim):
		var dt := create_tween()
		dt.tween_interval(0.23)
		dt.tween_property(dim, "color:a", 0.0, 0.28)
		dt.tween_callback(dim.queue_free)

	# Border flashes bright, then settles to the normal selected (cyan) style.
	if is_instance_valid(bord):
		var flash := StyleBoxFlat.new()
		flash.draw_center = false
		flash.border_color = Color(0.7, 1.0, 1.0)
		flash.set_border_width_all(_s(10))
		flash.set_corner_radius_all(_s(CARD_CORNER))
		bord.add_theme_stylebox_override("panel", flash)
		var bt := create_tween()
		bt.tween_interval(0.30)
		bt.tween_callback(func() -> void:
			if is_instance_valid(bord):
				_apply_card_style(bord, n == _selected))

func _scroll_to_selected() -> void:
	await get_tree().process_frame
	if _scroll == null:
		return
	var card_w := CARD_W * _sf + _s(26)
	var target := int((_selected - 1) * card_w + CARD_W * _sf * 0.5 - _scroll.size.x * 0.5)
	target = clampi(target, 0, maxi(0, int(_strip.size.x - _scroll.size.x)))
	_scroll.scroll_horizontal = target
	_scroll_f = float(target)

func _on_menu() -> void:
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _panel, func() -> void:
		visible = false
		menu_requested.emit())

func _on_play() -> void:
	AudioManager.play_sfx("button_click_menu")
	level_selected.emit(_selected)   # main_menu loads scenes/levels/level_N.tscn

# ============================================================
# HORIZONTAL DRAG-TO-SCROLL (with inertia)
# ============================================================

func _input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			if _scroll.get_global_rect().has_point(event.position):
				_drag_active = true
				_drag_moved = false
				_drag_start_x = event.position.x
				_drag_start_scroll = _scroll.scroll_horizontal
				_scroll_f = float(_scroll.scroll_horizontal)
				_fling_vel = 0.0
				_last_drag_x = event.position.x
				_last_drag_t = float(Time.get_ticks_msec()) / 1000.0
		else:
			if _drag_active:
				var held := (float(Time.get_ticks_msec()) / 1000.0) - _last_drag_t > 0.05
				if held or absf(_fling_vel) < FLING_MIN_START:
					_fling_vel = 0.0
			_drag_active = false
	elif _drag_active and (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)):
		var dx: float = event.position.x - _drag_start_x
		if absf(dx) > DRAG_THRESHOLD:
			_drag_moved = true
		var now := float(Time.get_ticks_msec()) / 1000.0
		var dt := now - _last_drag_t
		if dt > 0.0005:
			_fling_vel = -(event.position.x - _last_drag_x) / dt
			_last_drag_x = event.position.x
			_last_drag_t = now
		_scroll_f = float(_drag_start_scroll) - dx
		_scroll.scroll_horizontal = int(round(_scroll_f))
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Blink the hazard dots on the wireframe previews (toggle between the two cached frames).
	if visible and not _wire_rects.is_empty():
		_wire_blink_t += delta
		if _wire_blink_t >= 0.55:
			_wire_blink_t = 0.0
			_wire_blink_on = not _wire_blink_on
			for e: Dictionary in _wire_rects:
				var tr: TextureRect = e["rect"]
				if is_instance_valid(tr):
					var pair := _wire_pair(int(e["n"]))
					if not pair.is_empty():
						tr.texture = pair[0] if _wire_blink_on else pair[1]
	if _drag_active or not visible or _scroll == null:
		return
	if absf(_fling_vel) <= FLING_MIN_STOP:
		_fling_vel = 0.0
		return
	var max_scroll := 0.0
	var hbar := _scroll.get_h_scroll_bar()
	if hbar:
		max_scroll = maxf(0.0, hbar.max_value - hbar.page)
	_scroll_f += _fling_vel * delta
	if _scroll_f <= 0.0:
		_scroll_f = 0.0
		_fling_vel = 0.0
	elif _scroll_f >= max_scroll:
		_scroll_f = max_scroll
		_fling_vel = 0.0
	_scroll.scroll_horizontal = int(round(_scroll_f))
	_fling_vel *= exp(-FLING_DECAY * delta)

# ============================================================
# HELPERS
# ============================================================

## A centred row of 3 stars: bronze/silver/gold for earned, empty otherwise.
func _make_star_row(stars: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(8))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var files := ["bronzestar", "silverstar", "goldstar"]
	for i in 3:
		var tex := TextureRect.new()
		var fname: String = files[i] if stars > i else "emptystar"
		var path := "res://assets/sprites/ui/challenges/%s.svg" % fname
		if ResourceLoader.exists(path):
			tex.texture = load(path)
		tex.custom_minimum_size = Vector2(_s(STAR_SZ), _s(STAR_SZ))
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	return row

## Per-level preview art. Drop an image at res://assets/sprites/ui/levels/level_<n>.png
## (or .svg/.jpg/.webp) and it is picked up automatically; until then the card just
## shows the neutral placeholder background.
func _level_preview_texture(n: int) -> Texture2D:
	for ext in ["png", "svg", "jpg", "webp"]:
		var p := "res://assets/sprites/ui/levels/level_%d.%s" % [n, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null

# ---- WIREFRAME MINIMAP PREVIEW ------------------------------------------------
## Session-wide cache: level number -> [tex hazards-bright, tex hazards-dim] (built once).
static var _wire_cache: Dictionary = {}
var _wire_rects: Array = []        ## [{rect: TextureRect, n: int}] — for the hazard blink
var _wire_blink_t: float = 0.0
var _wire_blink_on: bool = true

## A tiny top-down wireframe of the level layout: walls (dark), ice (blue patches),
## hazards (red dots — blink via two cached frames), keys/metins (yellow), exit (blue),
## start (green). Built by instantiating the level scene OFF-TREE (no _ready runs).
func _level_wireframe_texture(n: int) -> Texture2D:
	var pair := _wire_pair(n)
	return null if pair.is_empty() else pair[0]

## Both blink frames come from a SINGLE scene instantiation. Building them separately meant
## instantiating all 30 level scenes TWICE (60 instantiations) on the first open of the level
## select — a very visible hitch, worst on the huge levels 25-29.
func _wire_pair(n: int) -> Array:
	if _wire_cache.has(n):
		return _wire_cache[n]
	var path := "res://scenes/levels/level_%d.tscn" % n
	if not ResourceLoader.exists(path):
		return []
	var ps: PackedScene = load(path)
	if ps == null:
		return []
	var inst: Node = ps.instantiate()
	if inst == null:
		return []
	var a := _render_wire(inst, true)
	var b := _render_wire(inst, false)
	inst.free()
	if a == null or b == null:
		return []
	_wire_cache[n] = [a, b]
	return _wire_cache[n]

## Draw one wireframe frame from an ALREADY-instantiated (off-tree) level scene.
func _render_wire(inst: Node, hazards_bright: bool) -> Texture2D:
	var aw: float = maxf(float(inst.get("arena_width_override")), 1.0)
	var ah: float = maxf(float(inst.get("arena_height_override")), 1.0)
	if aw <= 1.0 or ah <= 1.0:
		aw = 1920.0; ah = 1080.0
	const MAXW := 340.0
	const MAXH := 220.0
	var s: float = minf(MAXW / aw, MAXH / ah)
	var iw: int = maxi(int(aw * s), 8)
	var ih: int = maxi(int(ah * s), 8)
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.30, 0.30, 0.35, 1.0))   # floor (matches the in-game grey floor)
	var walls: Array = []      # draw walls LAST (over ice)
	for c in inst.get_children():
		if not (c is Node2D) or c.get_script() == null:
			continue
		var sp := String(c.get_script().resource_path)
		var pos: Vector2 = (c as Node2D).position * s
		if sp.ends_with("level_wall.gd") or sp.ends_with("level_gate.gd") \
		or sp.ends_with("locked_wall.gd") or sp.ends_with("level_breakable_wall.gd"):
			walls.append(c)
		elif sp.ends_with("level_icetile.gd"):
			var isz: Vector2 = c.get("size") * s
			_wire_rect(img, pos - isz * 0.5, isz, Color(0.35, 0.65, 0.95, 0.55))
		elif sp.ends_with("level_exit.gd"):
			_wire_dot(img, pos, 4, Color(0.3, 0.65, 1.0))
		elif sp.ends_with("level_key.gd") or sp.ends_with("level_metin.gd"):
			_wire_dot(img, pos, 3, Color(1.0, 0.85, 0.25))
		elif sp.ends_with("level_saw.gd") or sp.ends_with("level_spike.gd") \
		or sp.ends_with("level_piston.gd") or sp.ends_with("level_turret.gd") \
		or sp.ends_with("level_laserpointer.gd") or sp.ends_with("level_barrel.gd"):
			var hz := Color(0.95, 0.30, 0.28) if hazards_bright else Color(0.45, 0.13, 0.12)
			_wire_dot(img, pos, 2, hz)
	for w in walls:
		var wsz: Vector2 = w.get("wall_size") * s
		var wpos: Vector2 = (w as Node2D).position * s
		var col := Color(0.04, 0.04, 0.06)   # walls near-black, like in-game
		var wsp := String(w.get_script().resource_path)
		if wsp.ends_with("level_gate.gd"):
			col = Color(0.35, 0.55, 1.0)
		elif wsp.ends_with("level_breakable_wall.gd"):
			col = Color(0.72, 0.55, 0.35)
		_wire_rect(img, wpos - wsz * 0.5, wsz, col)
	# start dot on top
	var start: Vector2 = inst.get("player_start_pos") * s
	_wire_dot(img, start, 4, Color(0.35, 1.0, 0.45))
	return ImageTexture.create_from_image(img)   # caller owns `inst` and frees it once

func _wire_rect(img: Image, pos: Vector2, size: Vector2, col: Color) -> void:
	var x0 := clampi(int(pos.x), 0, img.get_width())
	var y0 := clampi(int(pos.y), 0, img.get_height())
	var x1 := clampi(int(pos.x + size.x) + 1, 0, img.get_width())
	var y1 := clampi(int(pos.y + size.y) + 1, 0, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), col)

func _wire_dot(img: Image, pos: Vector2, r: int, col: Color) -> void:
	_wire_rect(img, pos - Vector2(r, r), Vector2(r * 2, r * 2), col)

func _format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "—:——"
	@warning_ignore("integer_division")
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	var cs := int(fmod(seconds, 1.0) * 100)
	return "%d:%02d.%02d" % [m, s, cs]

func _font(c: Control, px: float, col: Color, outline: int) -> void:
	if _lilita:
		c.add_theme_font_override("font", _lilita)
	c.add_theme_font_size_override("font_size", _s(px))
	c.add_theme_color_override("font_color", col)
	if c is Button:
		c.add_theme_color_override("font_hover_color", col)
		c.add_theme_color_override("font_pressed_color", col)
	c.add_theme_constant_override("outline_size", _s(outline))
	c.add_theme_color_override("font_outline_color", Color.BLACK)

func _style_btn(b: Button, normal: Color, hover: Color, pressed: Color) -> void:
	b.add_theme_stylebox_override("normal", _sb(normal))
	b.add_theme_stylebox_override("hover", _sb(hover))
	b.add_theme_stylebox_override("pressed", _sb(pressed))
	b.add_theme_stylebox_override("focus", _sb(normal))

func _sb(bg: Color) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg, bg.lightened(0.3), 16.0, 3.0, 30.0, 0.0)
