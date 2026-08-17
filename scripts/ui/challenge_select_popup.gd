class_name ChallengeSelectPopup
extends CanvasLayer
## Vertical list of challenges (Play → VÝZVA). Each row is a button with the earned
## stars (bronze/silver/gold — empty slots otherwise) on the right side.
## Picking one emits `challenge_selected(scene_path)`.

const Anim := preload("res://scripts/utils/popup_anim.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

signal challenge_selected(scene_path: String)
signal closed

# ---- COLORS ----
const OVERLAY_COLOR := Color(0, 0, 0, 0.78)
const PANEL_COLOR := Color(0.10, 0.10, 0.14, 0.98)
const PANEL_BORDER := Color(0.25, 0.35, 0.55)
const BTN_NORMAL := Color(0.16, 0.18, 0.30)
const BTN_HOVER := Color(0.22, 0.26, 0.42)
const BTN_PRESSED := Color(0.12, 0.14, 0.24)
const DONE_COLOR := Color(0.20, 0.62, 0.20)
# Star tier tints — matched to the bronze/silver/gold star sprites shown in the list.
const STAR_BRONZE := Color(0.78, 0.42, 0.13)
const STAR_SILVER := Color(0.82, 0.83, 0.88)
const STAR_GOLD := Color(1.0, 0.82, 0.12)

# ---- LAYOUT (design 1920x1080) ----
const PANEL_W := 820
const PANEL_H := 840
const TITLE_FONT := 60
const BTN_W := 680
const BTN_H := 124
const BTN_FONT := 44

## Registry of selectable challenges (add a row here for each new challenge scene).
const CHALLENGES := [
	{"id": "dasher", "name": "Dasher", "scene": "res://scenes/challenges/dasher.tscn"},
	{"id": "zasobnik", "name": "Zásobník", "scene": "res://scenes/challenges/zasobnik.tscn"},
	{"id": "horda", "name": "Horda", "scene": "res://scenes/challenges/horda.tscn"},
	{"id": "sniper", "name": "Sniper", "scene": "res://scenes/challenges/sniper.tscn"},
	{"id": "blackout", "name": "Blackout", "scene": "res://scenes/challenges/blackout.tscn"},
	{"id": "miniarena", "name": "Miniaréna", "scene": "res://scenes/challenges/miniarena.tscn"},
	{"id": "reznik", "name": "Řezník", "scene": "res://scenes/challenges/reznik.tscn"},
	{"id": "totem", "name": "Totem", "scene": "res://scenes/challenges/totem.tscn"},
]

# ---- Touch drag-to-scroll with inertia (same pattern as the skins grid) ----
const DRAG_THRESHOLD := 12.0     ## px of movement before a press counts as a scroll
const FLING_DECAY := 5.0
const FLING_MIN_START := 45.0
const FLING_MIN_STOP := 8.0
var _drag_active: bool = false
var _drag_start_y: float = 0.0
var _drag_start_scroll: int = 0
var _drag_moved: bool = false    ## suppresses the button tap once a press becomes a drag
var _scroll_f: float = 0.0
var _fling_vel: float = 0.0
var _last_drag_y: float = 0.0
var _last_drag_t: float = 0.0

var _sf: float = 1.0
func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

var _lilita: Font
var _overlay: ColorRect
var _panel: Panel
var _scroll: ScrollContainer
var _list: VBoxContainer

func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_W, PANEL_H))
	_lilita = UIT.load_font()
	_build()
	visible = false

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
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
	ps.set_corner_radius_all(_s(22))
	_panel.add_theme_stylebox_override("panel", ps)
	center.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = _s(40)
	vb.offset_right = -_s(40)
	vb.offset_top = _s(38)
	vb.offset_bottom = -_s(38)
	vb.add_theme_constant_override("separation", _s(26))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	var title := Label.new()
	title.text = Loc.t("challenges_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(title, TITLE_FONT, Color.WHITE, 6)
	vb.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(_scroll)
	Anim.style_scrollbar(_scroll, _sf)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", _s(18))
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)

	_build_close_x()

## Touch/mouse drag-to-scroll with inertia for the challenge list (drags can start on
## the buttons; the tap is suppressed once the press becomes a drag).
func _input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			var vbar := _scroll.get_v_scroll_bar()
			var on_scrollbar: bool = vbar != null and vbar.visible and vbar.get_global_rect().has_point(event.position)
			if not on_scrollbar and _scroll.get_global_rect().has_point(event.position):
				_drag_active = true
				_drag_moved = false
				_drag_start_y = event.position.y
				_drag_start_scroll = _scroll.scroll_vertical
				_scroll_f = float(_scroll.scroll_vertical)
				_fling_vel = 0.0
				_last_drag_y = event.position.y
				_last_drag_t = float(Time.get_ticks_msec()) / 1000.0
		else:
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
			_fling_vel = -(event.position.y - _last_drag_y) / dt
			_last_drag_y = event.position.y
			_last_drag_t = now
		_scroll_f = float(_drag_start_scroll) - dy
		_scroll.scroll_vertical = int(round(_scroll_f))
		get_viewport().set_input_as_handled()

## Inertial glide after the finger lifts.
func _process(delta: float) -> void:
	if _drag_active or not visible or _scroll == null:
		return
	if absf(_fling_vel) <= FLING_MIN_STOP:
		_fling_vel = 0.0
		return
	var max_scroll := 0.0
	var vbar := _scroll.get_v_scroll_bar()
	if vbar:
		max_scroll = maxf(0.0, vbar.max_value - vbar.page)
	_scroll_f += _fling_vel * delta
	if _scroll_f <= 0.0:
		_scroll_f = 0.0
		_fling_vel = 0.0
	elif _scroll_f >= max_scroll:
		_scroll_f = max_scroll
		_fling_vel = 0.0
	_scroll.scroll_vertical = int(round(_scroll_f))
	_fling_vel *= exp(-FLING_DECAY * delta)

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for ch: Dictionary in CHALLENGES:
		_list.add_child(_make_challenge_button(ch))

func _make_challenge_button(ch: Dictionary) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := Button.new()
	btn.text = String(ch["name"])
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(BTN_W * _sf, BTN_H * _sf)
	_style_btn(btn, BTN_NORMAL, BTN_HOVER, BTN_PRESSED)
	_font(btn, BTN_FONT, Color.WHITE, 5)
	btn.pressed.connect(func() -> void:
		# If this press was actually a scroll drag, ignore it (don't launch).
		if _drag_moved:
			_drag_moved = false
			return
		AudioManager.play_sfx("button_click_menu")
		_show_confirm(ch))
	# Earned stars (bronze, silver, gold — empty placeholders) on the right side.
	btn.add_child(_make_star_row(SaveManager.get_challenge_stars(String(ch["id"]))))
	holder.add_child(btn)
	return holder

## A right-anchored row of 3 star slots: bronze/silver/gold when earned, empty otherwise.
func _make_star_row(stars: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(6))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star_sz := _s(88)
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = -(star_sz * 3 + _s(6) * 2) - _s(26)
	row.offset_right = -_s(26)
	row.offset_top = -star_sz * 0.5
	row.offset_bottom = star_sz * 0.5
	var files := ["bronzestar", "silverstar", "goldstar"]
	for i in 3:
		var tex := TextureRect.new()
		var fname: String = files[i] if stars > i else "emptystar"
		var path := "res://assets/sprites/ui/challenges/%s.svg" % fname
		if ResourceLoader.exists(path):
			tex.texture = load(path)
		tex.custom_minimum_size = Vector2(star_sz, star_sz)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	return row

## Bare grey "X" close button in the panel's top-right corner.
func _build_close_x() -> void:
	var btn := Button.new()
	btn.text = "✕"
	btn.focus_mode = Control.FOCUS_NONE
	var sz := _s(64)
	var margin := _s(16)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -sz - margin
	btn.offset_right = -margin
	btn.offset_top = margin
	btn.offset_bottom = sz + margin
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(42))
	btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	btn.add_theme_color_override("font_hover_color", Color(0.90, 0.90, 0.95))
	btn.add_theme_constant_override("outline_size", _s(2))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	btn.pressed.connect(_close)
	_panel.add_child(btn)

# ============================================================
# HELPERS
# ============================================================
func _font(c: Control, px: float, col: Color, outline: int) -> void:
	if _lilita:
		c.add_theme_font_override("font", _lilita)
	c.add_theme_font_size_override("font_size", _s(px))
	c.add_theme_color_override("font_color", col)
	if c is Button:
		c.add_theme_color_override("font_hover_color", col)
	c.add_theme_constant_override("outline_size", _s(outline))
	c.add_theme_color_override("font_outline_color", Color.BLACK)

## Turns a star-threshold line ("★ 100 · ★★ 200 · ★★★ 350 zabití") into BBCode with each
## tier on its OWN line, its stars tinted by tier: 1★ bronze, 2★ silver, 3★ gold. The
## numbers/units keep the label's neutral default colour.
func _colorize_stars(s: String) -> String:
	var parts: PackedStringArray = []
	for g in s.split(" · ", false):
		var grp := String(g)
		var n := 0
		while n < grp.length() and grp[n] == "★":
			n += 1
		var col := STAR_GOLD
		if n == 1:
			col = STAR_BRONZE
		elif n == 2:
			col = STAR_SILVER
		parts.append("[color=#%s]%s[/color]%s" % [col.to_html(false), grp.substr(0, n), grp.substr(n)])
	return "\n".join(parts)

func _style_btn(b: Button, normal: Color, hover: Color, pressed: Color) -> void:
	b.add_theme_stylebox_override("normal", _sb(normal))
	b.add_theme_stylebox_override("hover", _sb(hover))
	b.add_theme_stylebox_override("pressed", _sb(pressed))
	b.add_theme_stylebox_override("focus", _sb(normal))

## Confirm-panel buttons: symmetric padding. The list-row _sb() adds a huge right
## content margin (to clear the star row) which would blow these buttons past the panel.
func _btn_sb(bg: Color) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg, bg.lightened(0.3), 16.0, 3.0, 28.0, 0.0)

func _style_btn_plain(b: Button, normal: Color, hover: Color, pressed: Color) -> void:
	b.add_theme_stylebox_override("normal", _btn_sb(normal))
	b.add_theme_stylebox_override("hover", _btn_sb(hover))
	b.add_theme_stylebox_override("pressed", _btn_sb(pressed))
	b.add_theme_stylebox_override("focus", _btn_sb(normal))

func _sb(bg: Color) -> StyleBoxFlat:
	# Left padding for the name; large right padding so the text never runs under the
	# right-anchored star row.
	var sb := UIT.make_sb(_sf, bg, bg.lightened(0.3), 16.0, 3.0, 44.0, 0.0)
	sb.content_margin_right = 330.0 * _sf
	return sb

# ============================================================
# PUBLIC
# ============================================================
func show_popup() -> void:
	_rebuild_list()
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)

func _close() -> void:
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _panel, func() -> void:
		visible = false
		closed.emit())

# ============================================================
# CONFIRM SUB-MENU (goal description + ZAVŘÍT / HRÁT)
# ============================================================

## Overlay shown after picking a challenge: its name + goal description and two
## buttons (close → back to the list, play → launch it).
func _show_confirm(ch: Dictionary) -> void:
	var scene_path: String = String(ch["scene"])
	# Read the challenge's name + description from its LevelManager scene root.
	var cname := String(ch.get("name", ""))
	var cdesc := ""
	var rec_field := ""   # "time" (survival) | "kills" | "targets"
	var rec_id := String(ch.get("id", ""))
	var ps := load(scene_path) as PackedScene
	if ps:
		var inst := ps.instantiate()
		if "level_name" in inst and String(inst.level_name) != "":
			cname = String(inst.level_name)
		if "description" in inst:
			cdesc = String(inst.description)
		if "stars_by_survival" in inst and bool(inst.stars_by_survival):
			rec_field = "time"
		elif "stars_by_kills" in inst and bool(inst.stars_by_kills):
			rec_field = "kills"
		elif "stars_by_targets" in inst and bool(inst.stars_by_targets):
			rec_field = "targets"
		inst.free()

	var ov := ColorRect.new()
	ov.name = "ConfirmOverlay"
	ov.color = Color(0, 0, 0, 0.82)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(760 * _sf, 540 * _sf)
	var ps2 := StyleBoxFlat.new()
	ps2.bg_color = PANEL_COLOR
	ps2.border_color = PANEL_BORDER
	ps2.set_border_width_all(_s(3))
	ps2.set_corner_radius_all(_s(22))
	panel.add_theme_stylebox_override("panel", ps2)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = _s(48); vb.offset_right = -_s(48)
	vb.offset_top = _s(44); vb.offset_bottom = -_s(44)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", _s(28))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	# Fixed wrap width, comfortably narrower than the 760-wide panel so the text keeps a
	# clear margin on both sides. Labels are SHRINK_CENTER so the VBox can't stretch them
	# back out to the full panel width.
	var inner_w := 624.0 * _sf

	var ttl := Label.new()
	ttl.text = cname
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(ttl, 56, Color.WHITE, 6)
	vb.add_child(ttl)

	# Split the description at the first "★": main text (white) + star thresholds (yellow).
	var desc_main := cdesc
	var star_info := ""
	var star_idx := cdesc.find("★")
	if star_idx >= 0:
		desc_main = cdesc.substr(0, star_idx).strip_edges()
		star_info = cdesc.substr(star_idx).strip_edges()

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(spacer_top)

	var desc := Label.new()
	desc.text = desc_main
	desc.custom_minimum_size = Vector2(inner_w, 0)
	desc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font(desc, 34, Color(0.85, 0.88, 1.0), 4)
	vb.add_child(desc)

	if star_info != "":
		# Per-tier coloured stars (1★ bronze, 2★ silver, 3★ gold) via BBCode.
		var stars_lbl := RichTextLabel.new()
		stars_lbl.bbcode_enabled = true
		stars_lbl.fit_content = true
		stars_lbl.scroll_active = false
		stars_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stars_lbl.custom_minimum_size = Vector2(inner_w, 0)
		stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _lilita:
			stars_lbl.add_theme_font_override("normal_font", _lilita)
		stars_lbl.add_theme_font_size_override("normal_font_size", _s(34))
		stars_lbl.add_theme_color_override("default_color", Color(0.90, 0.92, 0.98))
		stars_lbl.add_theme_constant_override("outline_size", _s(4))
		stars_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		stars_lbl.text = "[center]%s[/center]" % _colorize_stars(star_info)
		vb.add_child(stars_lbl)

	# Personal record under the star thresholds (best time / most kills / most totems).
	if rec_field != "":
		var rec := SaveManager.get_challenge_record(rec_id, rec_field)
		var rec_lbl := Label.new()
		rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rec_val := "—"
		if rec > 0.0:
			if rec_field == "time":
				var m := int(rec) / 60
				var sec := int(rec) % 60
				var cs := int(fmod(rec, 1.0) * 100)
				rec_val = "%d:%02d.%02d" % [m, sec, cs]
			else:
				rec_val = "%d" % int(rec)
		rec_lbl.text = "%s: %s" % [Loc.t("record"), rec_val]
		_font(rec_lbl, 32, Color(0.45, 0.95, 0.55), 4)   # green — personal best
		vb.add_child(rec_lbl)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(spacer_bot)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(24))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)

	var close_b := Button.new()
	close_b.text = Loc.t("close")
	close_b.custom_minimum_size = Vector2(300 * _sf, 110 * _sf)
	_style_btn_plain(close_b, Color(0.55, 0.12, 0.12), Color(0.66, 0.18, 0.18), Color(0.45, 0.08, 0.08))
	_font(close_b, BTN_FONT, Color.WHITE, 5)
	close_b.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		ov.queue_free())
	row.add_child(close_b)

	var play_b := Button.new()
	play_b.text = Loc.t("play")
	play_b.custom_minimum_size = Vector2(300 * _sf, 110 * _sf)
	_style_btn_plain(play_b, Color(0.18, 0.56, 0.18), Color(0.24, 0.66, 0.24), Color(0.14, 0.46, 0.14))
	_font(play_b, BTN_FONT, Color.WHITE, 5)
	play_b.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		challenge_selected.emit(scene_path))
	row.add_child(play_b)
