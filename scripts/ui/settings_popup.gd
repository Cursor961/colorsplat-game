class_name SettingsPopup
extends CanvasLayer
## Settings popup — paint quality toggle, volume sliders, language selector.
## Dark overlay with centered panel, same style as VolumePopup.
## process_mode = ALWAYS so it works while the tree is paused.

signal closed
signal settings_applied   ## emitted when the user presses Apply (so the game can re-read live settings)

const Anim := preload("res://scripts/utils/popup_anim.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

# ============================================================
# COLORS (match main_menu style)
# ============================================================
const OVERLAY_COLOR := Color(0, 0, 0, 0.75)
const PANEL_COLOR := Color(0.10, 0.10, 0.14, 0.95)
const PANEL_BORDER := Color(0.25, 0.35, 0.55)
const PANEL_CORNER := 20
const FOOTER_COLOR := Color(0.05, 0.05, 0.08, 0.92)   ## darker bar behind the fixed bottom (dirty label + Apply/Close)
const FOOTER_BORDER := Color(0.20, 0.28, 0.45, 0.6)

const SLIDER_BG_COLOR := Color(0.18, 0.18, 0.24)
const SLIDER_FILL_COLOR := Color(0.22, 0.58, 0.22)
const SLIDER_GRAB_COLOR := Color(0.92, 0.92, 0.92)

const CLOSE_NORMAL := Color(0.55, 0.12, 0.12)
const CLOSE_HOVER := Color(0.65, 0.18, 0.18)
const CLOSE_PRESSED := Color(0.45, 0.08, 0.08)
const CLOSE_BORDER := Color(0.75, 0.25, 0.25)

## Toggle button colors (selected vs unselected)
const TOGGLE_SELECTED := Color(0.18, 0.50, 0.18, 0.95)
const TOGGLE_UNSELECTED := Color(0.14, 0.14, 0.20, 0.85)
const TOGGLE_SELECTED_BORDER := Color(0.4, 0.85, 0.4)
const TOGGLE_UNSELECTED_BORDER := Color(0.25, 0.25, 0.35)

const LANG_NORMAL := Color(0.12, 0.14, 0.26, 0.92)
const LANG_HOVER := Color(0.16, 0.20, 0.36, 0.92)
const LANG_SELECTED := Color(0.18, 0.50, 0.18, 0.95)
const LANG_BORDER := Color(0.22, 0.30, 0.50)
const LANG_SEL_BORDER := Color(0.4, 0.85, 0.4)

## Preset colors for the player-indicator ring (first is the default).
const INDICATOR_COLORS: Array[Color] = [
	Color(0.15, 1.00, 1.00),  # cyan
	Color(1.00, 1.00, 1.00),  # white
	Color(1.00, 0.85, 0.20),  # yellow
	Color(1.00, 0.30, 0.30),  # red
	Color(0.40, 1.00, 0.40),  # green
	Color(0.85, 0.40, 1.00),  # purple
	Color(1.00, 0.55, 0.15),  # orange
]

# ============================================================
# LAYOUT — design values for 1920x1080
# ============================================================
const PANEL_WIDTH := 920
const PANEL_HEIGHT := 960
const TITLE_FONT_SIZE := 56
const SECTION_FONT_SIZE := 36
const LABEL_FONT_SIZE := 36
const VALUE_FONT_SIZE := 32
const DESC_FONT_SIZE := 23   ## small grey explanatory text under each setting
const TOGGLE_FONT_SIZE := 36
const CLOSE_FONT_SIZE := 44
const CLOSE_WIDTH := 360
const CLOSE_HEIGHT := 96
const CLOSE_CORNER := 18
const CLOSE_BORDER_W := 3
const SLIDER_HEIGHT := 84   ## taller touch target for phones
const TOGGLE_WIDTH := 210
const TOGGLE_HEIGHT := 88
const TOGGLE_CORNER := 14
const LANG_BTN_WIDTH := 130
const LANG_BTN_HEIGHT := 88
const SWATCH_SIZE := 76    ## indicator color swatch button

# ============================================================
# SCALE FACTOR
# ============================================================
var _sf: float = 1.0

func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

# ============================================================
# NODES
# ============================================================
var _overlay: ColorRect
var _panel: Panel
var _music_slider: HSlider
var _music_value_label: Label
var _sfx_slider: HSlider
var _sfx_value_label: Label
var _close_btn: Button
var _apply_btn: Button
var _dirty_label: Label            ## "Unapplied changes" / "All applied" indicator
var _dirty_tw: Tween               ## blink on the indicator while there are unapplied changes
var _confirm_overlay: ColorRect    ## shown when leaving with unapplied changes

## When true (in-game pause settings), the language stepper is shown but disabled (greyed).
var language_locked: bool = false

var _distinction_slider: HSlider
var _distinction_value_label: Label
var _swatch_btns: Array = []           ## indicator color swatch buttons
var _lang_val_lbl: Label               ## language stepper value label
var _ind_val_lbl: Label                ## player-indicator stepper value label
var _zoom_slider: HSlider              ## in-game camera zoom
var _zoom_value_label: Label
var _gui_slider: HSlider               ## global GUI scale
var _gui_value_label: Label
var _hpbar_slider: HSlider             ## HP-bar opacity
var _hpbar_value_label: Label
var _bg_slider: HSlider                ## background lightness
var _bg_value_label: Label

# ---- TABS ----
var _pages_holder: Control
var _page_audio: VBoxContainer
var _page_game: VBoxContainer
var _page_display: VBoxContainer
var _page_speedrun: VBoxContainer
var _tab_btns: Array = []   ## tab Buttons (4)

# ---- SPEEDRUN reset-confirm overlay (built lazily) ----
var _sr_overlay: ColorRect = null
var _sr_code: String = ""        ## the 3-digit code the player must retype
var _sr_input: String = ""
var _sr_code_lbl: Label = null
var _sr_input_lbl: Label = null
var _current_page: int = 0
var _lefty_val_lbl: Label              ## left-handed stepper value label
var _dynamic_val_lbl: Label            ## dynamic-opacity stepper value label

## Staged settings — controls write here; committed only on "Apply", discarded on "Close".
var _pending: Dictionary = {}

## Language stepper options (code + endonym display name; Auto = follow system).
const LANG_OPTIONS: Array = [
	{"code": "system", "name": "Auto"},
	{"code": "en", "name": "English"},
	{"code": "cz", "name": "Čeština"},
	{"code": "es", "name": "Español"},
	{"code": "de", "name": "Deutsch"},
	{"code": "fr", "name": "Français"},
]
const STEP_VALUE_W := 220   ## stepper value-label width (fits the longest language endonym)
const ARROW_SIZE := 72      ## "<" / ">" button size

var _lilita: Font

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_WIDTH, PANEL_HEIGHT))
	_load_font()
	_load_settings()
	_build_overlay()
	_build_panel()
	_build_confirm()
	_refresh_dirty()
	visible = false

func _load_font() -> void:
	_lilita = UIT.load_font()

## Load saved settings into the staging dict (controls edit _pending; Apply commits).
func _load_settings() -> void:
	# Paint detail is locked to medium (no UI control any more).
	SaveManager.set_setting("paint_quality", "mid")
	_pending = {
		"music_volume": int(SaveManager.get_setting("music_volume", 80)),
		"sfx_volume": int(SaveManager.get_setting("sfx_volume", 50)),
		"language": String(SaveManager.get_setting("language", "system")),
		"player_indicator": bool(SaveManager.get_setting("player_indicator", false)),
		"indicator_color": String(SaveManager.get_setting("indicator_color", INDICATOR_COLORS[0].to_html(false))),
		"color_distinction": float(SaveManager.get_setting("color_distinction", 0.5)),
		"bg_brightness": clampf(float(SaveManager.get_setting("bg_brightness", 0.3)), 0.0, 1.0),
		"game_zoom": SaveManager.get_game_zoom(),
		"game_gui_scale": SaveManager.get_game_gui_scale(),
		"left_handed": SaveManager.is_left_handed(),
		"hpbar_opacity": clampf(float(SaveManager.get_setting("hpbar_opacity", 1.0)), 0.0, 1.0),
		"dynamic_opacity": bool(SaveManager.get_setting("dynamic_opacity", true)),
	}

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
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_color = PANEL_BORDER
	panel_style.set_border_width_all(_s(3))
	panel_style.set_corner_radius_all(_s(PANEL_CORNER))
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	# Outer layout: title (fixed) + scrollable settings list + footer (fixed).
	# It hugs the panel's inner border edge (only the 3px border inset) so the bottom
	# footer can span the full panel width and reach the bottom. Side padding for the
	# settings rows is re-added on the scroll's MarginContainer below.
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = _s(3)
	outer.offset_right = -_s(3)
	outer.offset_top = 32 * _sf
	outer.offset_bottom = -_s(3)
	outer.add_theme_constant_override("separation", _s(18))
	_panel.add_child(outer)

	# ---- Title (fixed) ----
	_add_title(outer, Loc.t("settings_title"))

	# ---- Tab row (ZVUKY / HRA / ZOBRAZENÍ) ----
	_build_tab_row(outer)

	# ---- Pages content (one VBox per tab, only one visible at a time) ----
	var pages_wrap := MarginContainer.new()
	pages_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages_wrap.add_theme_constant_override("margin_left", _s(43))
	pages_wrap.add_theme_constant_override("margin_right", _s(43))
	outer.add_child(pages_wrap)

	_pages_holder = Control.new()
	_pages_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pages_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_wrap.add_child(_pages_holder)

	_page_audio = _make_page()
	_page_game = _make_page()
	_page_display = _make_page()
	_page_speedrun = _make_page()

	# ---- PAGE 1: AUDIO ----
	_add_section_label(_page_audio, Loc.t("volume_label"))
	_music_slider = _build_slider_row(_page_audio, Loc.t("music"), "_on_music_changed")
	_music_value_label = _get_value_label(_page_audio)
	_add_spacer(_page_audio, 10)
	_sfx_slider = _build_slider_row(_page_audio, Loc.t("sfx"), "_on_sfx_changed")
	_sfx_value_label = _get_value_label(_page_audio)
	_add_default_marker(_music_slider, 80.0)
	_add_default_marker(_sfx_slider, 50.0)
	_add_desc(_page_audio, Loc.t("desc_volume"))

	# ---- PAGE 2: GAME ----
	# (Indicator color swatches removed from UI — default cyan works for most.
	# Color distinction moved to DISPLAY tab to group all visual sliders there.)
	_build_lang_stepper(_page_game)
	_add_spacer(_page_game, 22)
	_build_ind_stepper(_page_game)
	_add_spacer(_page_game, 22)
	_bg_slider = _build_value_slider(_page_game, Loc.t("bg_brightness"), "bg_brightness", 0.0, 1.0, 0.05, "pct")
	_add_default_marker(_bg_slider, 0.3)
	_add_spacer(_page_game, 22)
	_lefty_val_lbl = _build_stepper(_page_game, Loc.t("left_handed"), _lefty_step)
	_refresh_lefty_label()

	# ---- PAGE 3: DISPLAY ----
	# 3 sliders — zoom + GUI + color distinction. HP-bar opacity and Dynamic-opacity
	# toggle were removed from the UI (their save defaults still apply).
	_zoom_slider = _build_value_slider(_page_display, Loc.t("game_zoom"), "game_zoom",
		SaveManager.GAME_ZOOM_MIN, SaveManager.GAME_ZOOM_MAX, 0.1, "zoom")
	_add_default_marker(_zoom_slider, SaveManager.GAME_ZOOM_DEFAULT)
	_add_spacer(_page_display, 18)
	_gui_slider = _build_value_slider(_page_display, Loc.t("gui_scale"), "game_gui_scale",
		SaveManager.GAME_GUI_MIN, SaveManager.GAME_GUI_MAX, 0.1, "x")
	_add_default_marker(_gui_slider, SaveManager.GAME_GUI_DEFAULT)
	_add_spacer(_page_display, 18)
	_build_distinction_slider(_page_display)
	_add_default_marker(_distinction_slider, 0.5)

	# ---- PAGE 4: SPEEDRUN ----
	# One thing only: the full-progress reset (guarded by a typed 3-digit code).
	_add_section_label(_page_speedrun, Loc.t("tab_speedrun"))
	_add_desc(_page_speedrun, Loc.t("sr_desc"))
	_add_spacer(_page_speedrun, 26)
	var reset_row := HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_speedrun.add_child(reset_row)
	var sr_reset_btn := Button.new()
	sr_reset_btn.text = Loc.t("sr_reset")
	sr_reset_btn.custom_minimum_size = Vector2(520 * _sf, 96 * _sf)
	sr_reset_btn.focus_mode = Control.FOCUS_NONE
	if _lilita:
		sr_reset_btn.add_theme_font_override("font", _lilita)
	sr_reset_btn.add_theme_font_size_override("font_size", _s(34))
	sr_reset_btn.add_theme_color_override("font_color", Color.WHITE)
	sr_reset_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	sr_reset_btn.add_theme_constant_override("outline_size", _s(4))
	sr_reset_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	var rbg := Color(0.62, 0.12, 0.12)
	sr_reset_btn.add_theme_stylebox_override("normal", _make_sb(rbg, rbg.lightened(0.35), 16, 3))
	sr_reset_btn.add_theme_stylebox_override("hover", _make_sb(rbg.lightened(0.10), rbg.lightened(0.4), 16, 3))
	sr_reset_btn.add_theme_stylebox_override("pressed", _make_sb(rbg.darkened(0.15), rbg.lightened(0.35), 16, 3))
	sr_reset_btn.add_theme_stylebox_override("focus", _make_sb(rbg, rbg.lightened(0.35), 16, 3))
	sr_reset_btn.pressed.connect(_open_reset_confirm)
	reset_row.add_child(sr_reset_btn)

	_show_page(0)

	# ---- Fixed bottom footer: darker bar behind the dirty label + Apply/Close ----
	# Spans the full panel width and reaches the bottom; only the bottom corners are
	# rounded to match the panel's inner corner radius. A thin top border separates it
	# from the settings list above.
	var footer := PanelContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_STOP
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = FOOTER_COLOR
	footer_style.border_color = FOOTER_BORDER
	footer_style.border_width_top = _s(2)
	footer_style.corner_radius_bottom_left = maxi(0, _s(PANEL_CORNER) - _s(3))
	footer_style.corner_radius_bottom_right = maxi(0, _s(PANEL_CORNER) - _s(3))
	footer_style.content_margin_left = _s(24)
	footer_style.content_margin_right = _s(24)
	footer_style.content_margin_top = _s(16)
	footer_style.content_margin_bottom = _s(18)
	footer.add_theme_stylebox_override("panel", footer_style)
	outer.add_child(footer)

	var footer_vb := VBoxContainer.new()
	footer_vb.add_theme_constant_override("separation", _s(10))
	footer.add_child(footer_vb)

	# ---- Unapplied-changes indicator (just above the buttons) ----
	_dirty_label = Label.new()
	_dirty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dirty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _lilita:
		_dirty_label.add_theme_font_override("font", _lilita)
	_dirty_label.add_theme_font_size_override("font_size", _s(28))
	_dirty_label.add_theme_constant_override("outline_size", _s(3))
	_dirty_label.add_theme_color_override("font_outline_color", Color.BLACK)
	footer_vb.add_child(_dirty_label)

	# ---- APPLY + CLOSE + RESET (fixed at bottom, 3 across) ----
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", _s(14))
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_vb.add_child(btn_row)

	# Narrower than the 2-button layout so all 3 fit the panel width.
	var fbw := 250.0

	_apply_btn = Button.new()
	_apply_btn.text = Loc.t("apply")
	_apply_btn.custom_minimum_size = Vector2(fbw * _sf, CLOSE_HEIGHT * _sf)
	_style_apply_button(_apply_btn)
	_apply_btn.pressed.connect(_on_apply)
	btn_row.add_child(_apply_btn)

	_close_btn = Button.new()
	_close_btn.text = Loc.t("close")
	_close_btn.custom_minimum_size = Vector2(fbw * _sf, CLOSE_HEIGHT * _sf)
	_style_close_button(_close_btn)
	_close_btn.pressed.connect(_on_close)
	btn_row.add_child(_close_btn)

	# RESET TO DEFAULTS — to the RIGHT of CLOSE.
	var reset_btn := Button.new()
	reset_btn.text = Loc.t("reset_defaults")
	reset_btn.custom_minimum_size = Vector2(fbw * _sf, CLOSE_HEIGHT * _sf)
	_style_reset_button(reset_btn)
	reset_btn.pressed.connect(_on_reset_defaults)
	btn_row.add_child(reset_btn)

# ============================================================
# PLAYER INDICATOR COLOR PICKER (preset swatches)
# ============================================================

func _build_indicator_color_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	_swatch_btns.clear()
	for col: Color in INDICATOR_COLORS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(SWATCH_SIZE * _sf, SWATCH_SIZE * _sf)
		btn.set_meta("swatch_color", col)
		btn.pressed.connect(_on_indicator_color_selected.bind(col))
		row.add_child(btn)
		_swatch_btns.append(btn)

	_update_swatch_visuals()

func _on_indicator_color_selected(col: Color) -> void:
	_pending["indicator_color"] = col.to_html(false)
	_update_swatch_visuals()
	_refresh_dirty()

func _update_swatch_visuals() -> void:
	var cur := String(_pending.get("indicator_color", INDICATOR_COLORS[0].to_html(false)))
	for btn: Button in _swatch_btns:
		var col: Color = btn.get_meta("swatch_color")
		var selected: bool = col.to_html(false) == cur
		var border := Color.WHITE if selected else Color(0.0, 0.0, 0.0, 0.5)
		var bw := 5 if selected else 2
		btn.add_theme_stylebox_override("normal", _make_sb(col, border, 10, bw))
		btn.add_theme_stylebox_override("hover", _make_sb(col.lightened(0.12), border, 10, bw))
		btn.add_theme_stylebox_override("pressed", _make_sb(col.darkened(0.12), border, 10, bw))
		btn.add_theme_stylebox_override("focus", _make_sb(col, border, 10, bw))

# ============================================================
# LANGUAGE ROW
# ============================================================

## Generic "< value >" row: left label + "<" + value label + ">". `on_step`
## receives -1/+1. Returns the value Label so it can be refreshed on show.
func _build_stepper(parent: VBoxContainer, label_text: String, on_step: Callable, locked: bool = false) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(10))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		row.modulate = Color(1, 1, 1, 0.4)   # greyed: not changeable here
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_constant_override("outline_size", _s(4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(lbl)

	var left := _make_arrow("<")
	left.disabled = locked
	left.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		on_step.call(-1))
	row.add_child(left)

	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.custom_minimum_size = Vector2(STEP_VALUE_W * _sf, 0)
	if _lilita:
		val.add_theme_font_override("font", _lilita)
	val.add_theme_font_size_override("font_size", _s(TOGGLE_FONT_SIZE))
	val.add_theme_color_override("font_color", Color.WHITE)
	val.add_theme_constant_override("outline_size", _s(4))
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(val)

	var right := _make_arrow(">")
	right.disabled = locked
	right.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		on_step.call(1))
	row.add_child(right)

	return val

func _make_arrow(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(ARROW_SIZE * _sf, ARROW_SIZE * _sf)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _make_sb(LANG_NORMAL, LANG_BORDER, TOGGLE_CORNER, 2))
	b.add_theme_stylebox_override("hover", _make_sb(LANG_HOVER, LANG_BORDER, TOGGLE_CORNER, 2))
	b.add_theme_stylebox_override("pressed", _make_sb(LANG_NORMAL.darkened(0.1), LANG_BORDER, TOGGLE_CORNER, 2))
	b.add_theme_stylebox_override("focus", _make_sb(LANG_NORMAL, LANG_BORDER, TOGGLE_CORNER, 2))
	if _lilita:
		b.add_theme_font_override("font", _lilita)
	b.add_theme_font_size_override("font_size", _s(TOGGLE_FONT_SIZE))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", _s(3))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	return b

# ---- Language stepper (staged; applied on "Apply", which reloads the menu) ----
func _build_lang_stepper(parent: VBoxContainer) -> void:
	_lang_val_lbl = _build_stepper(parent, Loc.t("language"), _lang_step, language_locked)
	_refresh_lang_label()

func _lang_idx() -> int:
	var code: String = _pending.get("language", "system")
	for i in LANG_OPTIONS.size():
		if LANG_OPTIONS[i]["code"] == code:
			return i
	return 0

func _lang_step(dir: int) -> void:
	if language_locked:
		return
	var n := LANG_OPTIONS.size()
	var i := (_lang_idx() + dir + n) % n
	_pending["language"] = LANG_OPTIONS[i]["code"]
	_refresh_lang_label()
	_refresh_dirty()

func _refresh_lang_label() -> void:
	if _lang_val_lbl:
		_lang_val_lbl.text = String(LANG_OPTIONS[_lang_idx()]["name"])

# ---- Player-indicator stepper (On / Off) ----
func _build_ind_stepper(parent: VBoxContainer) -> void:
	_ind_val_lbl = _build_stepper(parent, Loc.t("player_indicator"), _ind_step)
	_refresh_ind_label()

func _ind_step(_dir: int) -> void:
	_pending["player_indicator"] = not bool(_pending.get("player_indicator", false))
	_refresh_ind_label()
	_refresh_dirty()

func _refresh_ind_label() -> void:
	if _ind_val_lbl:
		var on := bool(_pending.get("player_indicator", false))
		_ind_val_lbl.text = Loc.t("opt_on") if on else Loc.t("opt_off")

# ============================================================
# COLOR DISTINCTION SLIDER (0..1 — floor splat darkness)
# ============================================================

func _build_distinction_slider(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)

	# Left-aligned name label (matches the zoom / GUI rows).
	var name_lbl := Label.new()
	name_lbl.text = Loc.t("color_distinction")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lilita:
		name_lbl.add_theme_font_override("font", _lilita)
	name_lbl.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	name_lbl.add_theme_constant_override("outline_size", _s(4))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_child(name_lbl)

	_distinction_value_label = Label.new()
	_distinction_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _lilita:
		_distinction_value_label.add_theme_font_override("font", _lilita)
	_distinction_value_label.add_theme_font_size_override("font_size", _s(VALUE_FONT_SIZE))
	_distinction_value_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_distinction_value_label.add_theme_constant_override("outline_size", _s(3))
	_distinction_value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_distinction_value_label.custom_minimum_size = Vector2(90 * _sf, 0)
	header.add_child(_distinction_value_label)

	_distinction_slider = HSlider.new()
	_distinction_slider.min_value = 0.0
	_distinction_slider.max_value = 1.0
	_distinction_slider.step = 0.05
	_distinction_slider.value = float(SaveManager.get_setting("color_distinction", 0.5))
	_distinction_slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT * _sf)
	_distinction_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(_distinction_slider)
	_distinction_slider.value_changed.connect(_on_distinction_changed)
	parent.add_child(_distinction_slider)

	_update_distinction_label(_distinction_slider.value)

func _on_distinction_changed(value: float) -> void:
	_pending["color_distinction"] = value
	_update_distinction_label(value)
	_refresh_dirty()

func _update_distinction_label(value: float) -> void:
	if _distinction_value_label:
		_distinction_value_label.text = "%d%%" % int(round(value * 100.0))

# ============================================================
# DISPLAY / MOBILE (generic value slider + left-handed stepper)
# ============================================================

## A labelled slider that stages `key` into _pending. `fmt`: "zoom" -> "1.5×",
## "pct" -> "120%". Returns the HSlider (caller stores it for show_popup refresh).
func _build_value_slider(parent: VBoxContainer, label_text: String, key: String,
		minv: float, maxv: float, step: float, fmt: String) -> HSlider:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_constant_override("outline_size", _s(4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_child(lbl)

	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _lilita:
		val.add_theme_font_override("font", _lilita)
	val.add_theme_font_size_override("font_size", _s(VALUE_FONT_SIZE))
	val.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	val.add_theme_constant_override("outline_size", _s(3))
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.custom_minimum_size = Vector2(100 * _sf, 0)
	header.add_child(val)
	if key == "game_zoom":
		_zoom_value_label = val
	elif key == "game_gui_scale":
		_gui_value_label = val
	elif key == "hpbar_opacity":
		_hpbar_value_label = val
	elif key == "bg_brightness":
		_bg_value_label = val

	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.value = float(_pending.get(key, minv))
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT * _sf)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)
	slider.value_changed.connect(func(v: float) -> void:
		_pending[key] = v
		_set_value_text(val, v, fmt)
		_refresh_dirty())
	parent.add_child(slider)
	_set_value_text(val, slider.value, fmt)
	return slider

func _set_value_text(lbl: Label, v: float, fmt: String) -> void:
	if lbl == null:
		return
	if fmt == "zoom":
		# Slider shows `stored − 1.2` → default stored 2.2 = "1.0×" (middle); range "0.5×–1.5×".
		lbl.text = "%.1f×" % (v - 1.2)
	elif fmt == "x":
		# Plain ×-multiplier (e.g. the game-GUI slider 0.5×-1.5×).
		lbl.text = "%.1f×" % v
	else:
		lbl.text = "%d%%" % int(round(v * 100.0))

func _lefty_step(_dir: int) -> void:
	_pending["left_handed"] = not bool(_pending.get("left_handed", false))
	_refresh_lefty_label()
	_refresh_dirty()

func _refresh_lefty_label() -> void:
	if _lefty_val_lbl:
		var on := bool(_pending.get("left_handed", false))
		_lefty_val_lbl.text = Loc.t("opt_on") if on else Loc.t("opt_off")

func _dynamic_step(_dir: int) -> void:
	_pending["dynamic_opacity"] = not bool(_pending.get("dynamic_opacity", true))
	_refresh_dynamic_label()
	_refresh_dirty()

func _refresh_dynamic_label() -> void:
	if _dynamic_val_lbl:
		var on := bool(_pending.get("dynamic_opacity", true))
		_dynamic_val_lbl.text = Loc.t("opt_on") if on else Loc.t("opt_off")

## A small blue dot on a slider marking its DEFAULT value, so the player can see the
## default while the white grabber shows the current value.
func _add_default_marker(slider: HSlider, default_val: float) -> void:
	if slider == null:
		return
	var rng := slider.max_value - slider.min_value
	if rng <= 0.0:
		return
	var frac := clampf((default_val - slider.min_value) / rng, 0.0, 1.0)
	var sz := 24.0 * _sf
	var grab_half := 22.0 * _sf   # half the 44px grabber, so the dot tracks the grabber path
	var dot := Panel.new()
	dot.name = "DefaultMarker"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.anchor_left = frac
	dot.anchor_right = frac
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	var cx := grab_half * (1.0 - 2.0 * frac)   # align with the grabber's position at this value
	dot.offset_left = cx - sz * 0.5
	dot.offset_right = cx + sz * 0.5
	dot.offset_top = -sz * 0.5
	dot.offset_bottom = sz * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.45, 0.95)
	sb.set_corner_radius_all(int(sz * 0.5))
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(maxi(1, _s(2)))
	dot.add_theme_stylebox_override("panel", sb)
	slider.add_child(dot)

# ============================================================
# VOLUME SLIDERS (same pattern as VolumePopup)
# ============================================================

func _build_slider_row(parent: VBoxContainer, label_text: String, callback: String) -> HSlider:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_constant_override("outline_size", _s(4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.name = label_text + "Value"
	val_lbl.text = "100%"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _lilita:
		val_lbl.add_theme_font_override("font", _lilita)
	val_lbl.add_theme_font_size_override("font_size", _s(VALUE_FONT_SIZE))
	val_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	val_lbl.add_theme_constant_override("outline_size", _s(3))
	val_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	val_lbl.custom_minimum_size = Vector2(80 * _sf, 0)
	header.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 10.0
	slider.value = 100.0
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT * _sf)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)
	slider.value_changed.connect(Callable(self, callback))
	parent.add_child(slider)

	return slider

func _get_value_label(vbox: VBoxContainer) -> Label:
	var header: HBoxContainer = vbox.get_child(vbox.get_child_count() - 2) as HBoxContainer
	return header.get_child(1) as Label

# ============================================================
# HELPERS
# ============================================================

func _add_title(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(TITLE_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", _s(6))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(lbl)

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(SECTION_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	lbl.add_theme_constant_override("outline_size", _s(4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(lbl)

func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, height * _sf)
	parent.add_child(sp)

## Small grey explanatory line under a setting (says what it actually does).
func _add_desc(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(DESC_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color(0.62, 0.64, 0.72))
	lbl.add_theme_constant_override("outline_size", _s(2))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(lbl)

# ============================================================
# RESET TO DEFAULTS
# ============================================================

func _build_reset_button(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var btn := Button.new()
	btn.text = Loc.t("reset_defaults")
	btn.custom_minimum_size = Vector2(CLOSE_WIDTH * _sf, CLOSE_HEIGHT * _sf)
	_style_reset_button(btn)
	btn.pressed.connect(_on_reset_defaults)
	row.add_child(btn)

func _style_reset_button(btn: Button) -> void:
	var c := Color(0.40, 0.31, 0.10)
	var cb := Color(0.85, 0.65, 0.25)
	btn.add_theme_stylebox_override("normal", _make_sb(c, cb, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(c.lightened(0.12), cb, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(c.darkened(0.12), cb, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(c, cb, CLOSE_CORNER, CLOSE_BORDER_W))
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(CLOSE_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_constant_override("outline_size", _s(5))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

## Stage all settings back to their defaults (committed only when the user presses Apply).
func _on_reset_defaults() -> void:
	AudioManager.play_sfx("button_click_menu")
	# Don't reset language while in-game (it's locked there).
	var keep_lang: String = String(SaveManager.get_setting("language", "system")) if language_locked else "system"
	_pending = {
		"music_volume": 80,
		"sfx_volume": 50,
		"language": keep_lang,
		"player_indicator": false,
		"indicator_color": INDICATOR_COLORS[0].to_html(false),
		"color_distinction": 0.5,
		"bg_brightness": 0.3,
		"game_zoom": SaveManager.GAME_ZOOM_DEFAULT,
		"game_gui_scale": SaveManager.GAME_GUI_DEFAULT,
		"left_handed": false,
		"hpbar_opacity": 1.0,
		"dynamic_opacity": true,
	}
	# Reflect the defaults into every control.
	if _music_slider:
		_music_slider.set_value_no_signal(80)
		_update_value_label(_music_value_label, 80)
	if _sfx_slider:
		_sfx_slider.set_value_no_signal(50)
		_update_value_label(_sfx_value_label, 50)
	_refresh_lang_label()
	_refresh_ind_label()
	_update_swatch_visuals()
	if _distinction_slider:
		_distinction_slider.set_value_no_signal(0.5)
		_update_distinction_label(0.5)
	if _zoom_slider:
		_zoom_slider.set_value_no_signal(SaveManager.GAME_ZOOM_DEFAULT)
		_set_value_text(_zoom_value_label, SaveManager.GAME_ZOOM_DEFAULT, "zoom")
	if _gui_slider:
		_gui_slider.set_value_no_signal(SaveManager.GAME_GUI_DEFAULT)
		_set_value_text(_gui_value_label, SaveManager.GAME_GUI_DEFAULT, "x")
	if _hpbar_slider:
		_hpbar_slider.set_value_no_signal(1.0)
		_set_value_text(_hpbar_value_label, 1.0, "pct")
	if _bg_slider:
		_bg_slider.set_value_no_signal(0.3)
		_set_value_text(_bg_value_label, 0.3, "pct")
	_refresh_lefty_label()
	_refresh_dynamic_label()
	_refresh_dirty()

func _style_slider(slider: HSlider) -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = SLIDER_BG_COLOR
	bg_style.set_corner_radius_all(_s(11))
	bg_style.content_margin_top = 13 * _sf   ## thicker track bar (easier to see/hit)
	bg_style.content_margin_bottom = 13 * _sf
	slider.add_theme_stylebox_override("slider", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = SLIDER_FILL_COLOR
	fill_style.set_corner_radius_all(_s(11))
	fill_style.content_margin_top = 13 * _sf
	fill_style.content_margin_bottom = 13 * _sf
	slider.add_theme_stylebox_override("grabber_area", fill_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)

	var grab_size := _s(44)   ## bigger grabber knob for thumbs
	slider.add_theme_icon_override("grabber", _make_grabber_texture(SLIDER_GRAB_COLOR, grab_size))
	slider.add_theme_icon_override("grabber_highlight", _make_grabber_texture(Color.WHITE, grab_size))

func _make_grabber_texture(color: Color, p_size: int = 24) -> ImageTexture:
	var img := Image.create(p_size, p_size, false, Image.FORMAT_RGBA8)
	var center_pt := Vector2(p_size / 2.0, p_size / 2.0)
	var radius := p_size / 2.0
	for y in p_size:
		for x in p_size:
			if Vector2(x, y).distance_to(center_pt) <= radius:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _style_close_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(CLOSE_NORMAL, CLOSE_BORDER, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(CLOSE_HOVER, CLOSE_BORDER, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(CLOSE_PRESSED, CLOSE_BORDER, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(CLOSE_NORMAL, CLOSE_BORDER, CLOSE_CORNER, CLOSE_BORDER_W))
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(CLOSE_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_constant_override("outline_size", _s(5))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

func _style_apply_button(btn: Button) -> void:
	var g := Color(0.20, 0.58, 0.20)
	var gb := Color(0.40, 0.85, 0.40)
	btn.add_theme_stylebox_override("normal", _make_sb(g, gb, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(g.lightened(0.12), gb, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(g.darkened(0.12), gb, CLOSE_CORNER, CLOSE_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(g, gb, CLOSE_CORNER, CLOSE_BORDER_W))
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(CLOSE_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_constant_override("outline_size", _s(5))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

## Build the row of 3 tab buttons (AUDIO / GAME / DISPLAY) above the page content.
func _build_tab_row(parent: VBoxContainer) -> void:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", _s(43))
	wrap.add_theme_constant_override("margin_right", _s(43))
	parent.add_child(wrap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(10))
	wrap.add_child(row)
	var titles := [Loc.t("volume_label"), Loc.t("tab_game"), Loc.t("display_label"), Loc.t("tab_speedrun")]
	_tab_btns.clear()
	for i in titles.size():
		var b := Button.new()
		b.text = String(titles[i])
		b.custom_minimum_size = Vector2(196 * _sf, 76 * _sf)   # 4 tabs must fit the 920 panel
		b.focus_mode = Control.FOCUS_NONE
		if _lilita:
			b.add_theme_font_override("font", _lilita)
		b.add_theme_font_size_override("font_size", _s(28))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_constant_override("outline_size", _s(3))
		b.add_theme_color_override("font_outline_color", Color.BLACK)
		var idx := i
		b.pressed.connect(func() -> void: _show_page(idx))
		row.add_child(b)
		_tab_btns.append(b)
	_style_tabs()

func _style_tabs() -> void:
	for i in _tab_btns.size():
		var b: Button = _tab_btns[i]
		var sel: bool = (i == _current_page)
		var bg: Color = Color(0.18, 0.40, 0.78, 0.95) if sel else Color(0.10, 0.12, 0.20, 0.85)
		var border: Color = Color(0.55, 0.78, 1.0) if sel else Color(0.22, 0.26, 0.36)
		b.add_theme_stylebox_override("normal", _make_sb(bg, border, 14, 2))
		b.add_theme_stylebox_override("hover", _make_sb(bg.lightened(0.08), border, 14, 2))
		b.add_theme_stylebox_override("pressed", _make_sb(bg.darkened(0.08), border, 14, 2))
		b.add_theme_stylebox_override("focus", _make_sb(bg, border, 14, 2))

## Each tab page lives inside its own ScrollContainer so any small overflow stays
## scrollable (no visible scrollbar when the content fits the holder). Returns the
## inner VBox the caller fills with rows.
func _make_page() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	_pages_holder.add_child(sc)
	# Styled, 3x-wider scrollbar (thumb-friendly) — the default one was a thin sliver
	# pressed right against the row text/value labels.
	Anim.style_scrollbar(sc, _sf)
	var vbar := sc.get_v_scroll_bar()
	if vbar:
		vbar.custom_minimum_size = Vector2(_s(36), 0)
	# Gap between the rows and the bar so text/values never touch it.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", _s(24))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(pad)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", _s(14))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(v)
	return v

## Show one tab's content, hide the others, restyle the tab row.
## The page vbox is wrapped in a ScrollContainer; toggle visibility on that wrapper.
func _show_page(idx: int) -> void:
	_current_page = idx
	_set_page_visible(_page_audio, idx == 0)
	_set_page_visible(_page_game, idx == 1)
	_set_page_visible(_page_display, idx == 2)
	_set_page_visible(_page_speedrun, idx == 3)
	_style_tabs()

func _set_page_visible(page: VBoxContainer, on: bool) -> void:
	# The page VBox now lives ScrollContainer → MarginContainer → VBox (the margin was added
	# for the wider scrollbar), so walk UP to the ScrollContainer instead of assuming it's the
	# direct parent — otherwise no page ever hides and all four stack on top of each other.
	var n: Node = page
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n is ScrollContainer:
		(n as ScrollContainer).visible = on

func _make_sb(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 16.0, 10.0)

# ============================================================
# CALLBACKS
# ============================================================

func _on_music_changed(value: float) -> void:
	_update_value_label(_music_value_label, value)
	_pending["music_volume"] = int(value)
	_refresh_dirty()

func _on_sfx_changed(value: float) -> void:
	_update_value_label(_sfx_value_label, value)
	_pending["sfx_volume"] = int(value)
	_refresh_dirty()

func _update_value_label(lbl: Label, value: float) -> void:
	lbl.text = "%d%%" % int(value)

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _on_close() -> void:
	# If there are unapplied changes, ask before leaving (nothing was applied live).
	if _is_dirty():
		_show_confirm()
		return
	_do_close()

func _do_close() -> void:
	Anim.close(_overlay, _panel, func() -> void:
		visible = false
		closed.emit())

## Commit all staged settings. Reloads the menu if the language changed.
func _on_apply() -> void:
	AudioManager.play_sfx("button_click_menu")
	var lang_changed := String(_pending.get("language", "system")) != String(SaveManager.get_setting("language", "system"))
	SaveManager.set_setting("music_volume", int(_pending.get("music_volume", 80)))
	SaveManager.set_setting("sfx_volume", int(_pending.get("sfx_volume", 50)))
	SaveManager.set_setting("player_indicator", bool(_pending.get("player_indicator", false)))
	SaveManager.set_setting("indicator_color", String(_pending.get("indicator_color", "26ffff")))
	SaveManager.set_setting("color_distinction", float(_pending.get("color_distinction", 0.5)))
	SaveManager.set_setting("bg_brightness", clampf(float(_pending.get("bg_brightness", 0.3)), 0.0, 1.0))
	SaveManager.set_setting("language", String(_pending.get("language", "system")))
	# Mobile / display settings.

	SaveManager.set_game_zoom(float(_pending.get("game_zoom", SaveManager.GAME_ZOOM_DEFAULT)))
	SaveManager.set_game_gui_scale(float(_pending.get("game_gui_scale", SaveManager.GAME_GUI_DEFAULT)))
	SaveManager.set_left_handed(bool(_pending.get("left_handed", false)))
	SaveManager.set_setting("hpbar_opacity", clampf(float(_pending.get("hpbar_opacity", 1.0)), 0.0, 1.0))
	SaveManager.set_setting("dynamic_opacity", bool(_pending.get("dynamic_opacity", true)))
	AudioManager.apply_settings(float(_pending.get("music_volume", 80)), float(_pending.get("sfx_volume", 50)))
	_refresh_dirty()
	settings_applied.emit()   # let the game re-read live settings (player indicator, distinction, zoom…)
	# Language or GUI-scale changes rebuild the whole UI. In-game (language_locked) we
	# defer the GUI-scale rebuild to the next menu so we don't drop the player's run.
	if lang_changed:
		get_tree().call_deferred("reload_current_scene")

# ============================================================
# UNAPPLIED-CHANGES INDICATOR + EXIT CONFIRM
# ============================================================

## Any staged value differs from what's saved?
func _is_dirty() -> bool:
	if int(_pending.get("music_volume", 80)) != int(SaveManager.get_setting("music_volume", 80)): return true
	if int(_pending.get("sfx_volume", 50)) != int(SaveManager.get_setting("sfx_volume", 50)): return true
	if String(_pending.get("language", "system")) != String(SaveManager.get_setting("language", "system")): return true
	if bool(_pending.get("player_indicator", false)) != bool(SaveManager.get_setting("player_indicator", false)): return true
	if String(_pending.get("indicator_color", "26ffff")) != String(SaveManager.get_setting("indicator_color", "26ffff")): return true
	if not is_equal_approx(float(_pending.get("color_distinction", 0.5)), float(SaveManager.get_setting("color_distinction", 0.5))): return true
	if not is_equal_approx(float(_pending.get("bg_brightness", 0.3)), float(SaveManager.get_setting("bg_brightness", 0.3))): return true
	if not is_equal_approx(float(_pending.get("game_zoom", SaveManager.GAME_ZOOM_DEFAULT)), SaveManager.get_game_zoom()): return true
	if not is_equal_approx(float(_pending.get("game_gui_scale", SaveManager.GAME_GUI_DEFAULT)), SaveManager.get_game_gui_scale()): return true
	if bool(_pending.get("left_handed", false)) != SaveManager.is_left_handed(): return true
	if not is_equal_approx(float(_pending.get("hpbar_opacity", 1.0)), float(SaveManager.get_setting("hpbar_opacity", 1.0))): return true
	if bool(_pending.get("dynamic_opacity", true)) != bool(SaveManager.get_setting("dynamic_opacity", true)): return true
	return false

## Update the indicator label + Apply button to reflect whether changes are pending.
func _refresh_dirty() -> void:
	var dirty := _is_dirty()
	if _dirty_tw and _dirty_tw.is_valid():
		_dirty_tw.kill()
	if _dirty_label:
		_dirty_label.text = Loc.t("settings_unsaved") if dirty else Loc.t("settings_saved")
		_dirty_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2) if dirty else Color(0.55, 0.9, 0.55))
		_dirty_label.modulate.a = 1.0
		if dirty:
			_dirty_tw = _dirty_label.create_tween().set_loops()
			_dirty_tw.tween_property(_dirty_label, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
			_dirty_tw.tween_property(_dirty_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	if _apply_btn:
		# Bright + emphasised when there's something to apply; dimmed when already applied.
		_apply_btn.modulate = Color.WHITE if dirty else Color(1, 1, 1, 0.45)

func _build_confirm() -> void:
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.color = Color(0, 0, 0, 0.6)
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(cc)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(840 * _sf, 360 * _sf)
	var psb := StyleBoxFlat.new()
	psb.bg_color = PANEL_COLOR
	psb.border_color = PANEL_BORDER
	psb.set_border_width_all(_s(3))
	psb.set_corner_radius_all(_s(PANEL_CORNER))
	psb.shadow_size = _s(26)
	psb.shadow_color = Color(0, 0, 0, 0.55)
	panel.add_theme_stylebox_override("panel", psb)
	cc.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = _s(40); vb.offset_right = -_s(40)
	vb.offset_top = _s(36); vb.offset_bottom = -_s(36)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", _s(20))
	panel.add_child(vb)

	var ttl := Label.new()
	ttl.text = Loc.t("unsaved_title")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _lilita:
		ttl.add_theme_font_override("font", _lilita)
	ttl.add_theme_font_size_override("font_size", _s(44))
	ttl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	ttl.add_theme_constant_override("outline_size", _s(4))
	ttl.add_theme_color_override("font_outline_color", Color.BLACK)
	vb.add_child(ttl)

	var msg := Label.new()
	msg.text = Loc.t("unsaved_msg")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _lilita:
		msg.add_theme_font_override("font", _lilita)
	msg.add_theme_font_size_override("font_size", _s(30))
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	msg.add_theme_constant_override("outline_size", _s(3))
	msg.add_theme_color_override("font_outline_color", Color.BLACK)
	vb.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(18))
	vb.add_child(row)

	var dlg_btn_w := 300.0   ## narrower than the main CLOSE/APPLY so both fit the dialog
	var discard_btn := Button.new()
	discard_btn.text = Loc.t("discard_leave")
	discard_btn.custom_minimum_size = Vector2(dlg_btn_w * _sf, CLOSE_HEIGHT * _sf)
	_style_close_button(discard_btn)   # red = leaving / destructive
	discard_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_hide_confirm()
		_do_close())
	row.add_child(discard_btn)

	var stay_btn := Button.new()
	stay_btn.text = Loc.t("stay")
	stay_btn.custom_minimum_size = Vector2(dlg_btn_w * _sf, CLOSE_HEIGHT * _sf)
	_style_apply_button(stay_btn)      # green = safe choice
	stay_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_hide_confirm())
	row.add_child(stay_btn)

func _show_confirm() -> void:
	if _confirm_overlay:
		_confirm_overlay.visible = true

func _hide_confirm() -> void:
	if _confirm_overlay:
		_confirm_overlay.visible = false

# ============================================================
# PUBLIC
# ============================================================

func show_popup() -> void:
	_load_settings()
	_music_slider.set_value_no_signal(float(_pending["music_volume"]))
	_sfx_slider.set_value_no_signal(float(_pending["sfx_volume"]))
	_update_value_label(_music_value_label, _music_slider.value)
	_update_value_label(_sfx_value_label, _sfx_slider.value)
	_refresh_lang_label()
	_refresh_ind_label()
	_update_swatch_visuals()
	if _distinction_slider:
		_distinction_slider.set_value_no_signal(float(_pending["color_distinction"]))
		_update_distinction_label(_distinction_slider.value)
	if _zoom_slider:
		_zoom_slider.set_value_no_signal(float(_pending["game_zoom"]))
		_set_value_text(_zoom_value_label, _zoom_slider.value, "zoom")
	if _gui_slider:
		_gui_slider.set_value_no_signal(float(_pending["game_gui_scale"]))
		_set_value_text(_gui_value_label, _gui_slider.value, "x")
	if _hpbar_slider:
		_hpbar_slider.set_value_no_signal(float(_pending["hpbar_opacity"]))
		_set_value_text(_hpbar_value_label, _hpbar_slider.value, "pct")
	if _bg_slider:
		_bg_slider.set_value_no_signal(float(_pending["bg_brightness"]))
		_set_value_text(_bg_value_label, _bg_slider.value, "pct")
	_refresh_lefty_label()
	_refresh_dynamic_label()
	_hide_confirm()
	if _sr_overlay:
		_sr_overlay.visible = false
	_refresh_dirty()
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)

func hide_popup() -> void:
	visible = false

# ============================================================
# SPEEDRUN — full progress reset behind a typed 3-digit code
# ============================================================

## Open the confirm overlay with a FRESH random 3-digit code the player must retype.
func _open_reset_confirm() -> void:
	AudioManager.play_sfx("button_click_menu")
	if _sr_overlay == null:
		_build_reset_confirm()
	_sr_code = "%03d" % randi_range(100, 999)
	_sr_input = ""
	_sr_code_lbl.text = _sr_code
	_sr_input_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_refresh_sr_input()
	_sr_overlay.visible = true

func _build_reset_confirm() -> void:
	_sr_overlay = ColorRect.new()
	_sr_overlay.color = Color(0, 0, 0, 0.82)
	_sr_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sr_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sr_overlay)   # last child of the CanvasLayer → above the settings panel

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sr_overlay.add_child(center)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.10, 0.14, 0.98)
	ps.border_color = Color(0.75, 0.25, 0.25)
	ps.set_border_width_all(_s(3))
	ps.set_corner_radius_all(_s(20))
	ps.content_margin_left = _s(46); ps.content_margin_right = _s(46)
	ps.content_margin_top = _s(30); ps.content_margin_bottom = _s(30)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", _s(12))
	panel.add_child(v)

	var prompt := Label.new()
	prompt.text = Loc.t("sr_code_prompt")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sr_font(prompt, 30, Color(0.9, 0.9, 0.95))
	v.add_child(prompt)

	_sr_code_lbl = Label.new()
	_sr_code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sr_font(_sr_code_lbl, 64, Color(0.55, 0.85, 1.0))
	v.add_child(_sr_code_lbl)

	_sr_input_lbl = Label.new()
	_sr_input_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sr_font(_sr_input_lbl, 52, Color(1.0, 0.9, 0.2))
	v.add_child(_sr_input_lbl)

	# Keypad 1-9 …
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", _s(12))
	grid.add_theme_constant_override("v_separation", _s(12))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for d in range(1, 10):
		grid.add_child(_sr_key(str(d)))
	# … bottom keypad row: backspace, 0
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", _s(12))
	v.add_child(bottom)
	bottom.add_child(_sr_key("<"))
	bottom.add_child(_sr_key("0"))

	# Confirm row: CANCEL + RESET. The reset ONLY fires from the RESET button here — typing the
	# last digit never triggers it, so a mistyped final digit can't wipe the save.
	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.add_theme_constant_override("separation", _s(16))
	v.add_child(confirm_row)

	var cancel := Button.new()
	cancel.text = Loc.t("sr_cancel")
	cancel.custom_minimum_size = Vector2(240 * _sf, 96 * _sf)
	cancel.focus_mode = Control.FOCUS_NONE
	_sr_font(cancel, 28, Color.WHITE)
	var cbg := Color(0.20, 0.22, 0.30)
	cancel.add_theme_stylebox_override("normal", _make_sb(cbg, cbg.lightened(0.3), 14, 2))
	cancel.add_theme_stylebox_override("hover", _make_sb(cbg.lightened(0.1), cbg.lightened(0.35), 14, 2))
	cancel.add_theme_stylebox_override("pressed", _make_sb(cbg.darkened(0.15), cbg.lightened(0.3), 14, 2))
	cancel.add_theme_stylebox_override("focus", _make_sb(cbg, cbg.lightened(0.3), 14, 2))
	cancel.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_sr_overlay.visible = false)
	confirm_row.add_child(cancel)

	var confirm := Button.new()
	confirm.text = Loc.t("sr_reset")
	confirm.custom_minimum_size = Vector2(400 * _sf, 96 * _sf)
	confirm.focus_mode = Control.FOCUS_NONE
	_sr_font(confirm, 28, Color.WHITE)
	var rbg := Color(0.62, 0.12, 0.12)
	confirm.add_theme_stylebox_override("normal", _make_sb(rbg, rbg.lightened(0.35), 14, 2))
	confirm.add_theme_stylebox_override("hover", _make_sb(rbg.lightened(0.1), rbg.lightened(0.4), 14, 2))
	confirm.add_theme_stylebox_override("pressed", _make_sb(rbg.darkened(0.15), rbg.lightened(0.35), 14, 2))
	confirm.add_theme_stylebox_override("focus", _make_sb(rbg, rbg.lightened(0.35), 14, 2))
	confirm.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_sr_check())
	confirm_row.add_child(confirm)

## One keypad button: a digit, or "<" for backspace.
func _sr_key(ch: String) -> Button:
	var b := Button.new()
	b.text = "⌫" if ch == "<" else ch
	b.custom_minimum_size = Vector2(92 * _sf, 92 * _sf)
	b.focus_mode = Control.FOCUS_NONE
	_sr_font(b, 34, Color.WHITE)
	var bg := Color(0.14, 0.18, 0.30)
	b.add_theme_stylebox_override("normal", _make_sb(bg, Color(0.30, 0.38, 0.58), 14, 2))
	b.add_theme_stylebox_override("hover", _make_sb(bg.lightened(0.08), Color(0.38, 0.48, 0.70), 14, 2))
	b.add_theme_stylebox_override("pressed", _make_sb(bg.darkened(0.12), Color(0.30, 0.38, 0.58), 14, 2))
	b.add_theme_stylebox_override("focus", _make_sb(bg, Color(0.30, 0.38, 0.58), 14, 2))
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		if ch == "<":
			_sr_input = _sr_input.substr(0, maxi(0, _sr_input.length() - 1))
		elif _sr_input.length() < 3:
			_sr_input += ch
		_refresh_sr_input())
		# NB: no auto-check — the reset only fires when the RESET button is pressed.
	return b

func _sr_font(c: Control, px: int, col: Color) -> void:
	if _lilita:
		c.add_theme_font_override("font", _lilita)
	c.add_theme_font_size_override("font_size", _s(px))
	c.add_theme_color_override("font_color", col)
	if c is Button:
		c.add_theme_color_override("font_hover_color", col)
	c.add_theme_constant_override("outline_size", _s(4))
	c.add_theme_color_override("font_outline_color", Color.BLACK)

func _refresh_sr_input() -> void:
	var shown := ""
	for i in 3:
		shown += (_sr_input[i] if i < _sr_input.length() else "_")
		if i < 2:
			shown += " "
	_sr_input_lbl.text = shown

## 3 digits typed: match → wipe progress + reload the game; mismatch → flash red,
## clear the input and roll a NEW code (no brute-mashing through it).
func _sr_check() -> void:
	if _sr_input == _sr_code:
		AudioManager.play_sfx("box_reveal")
		SaveManager.reset_all_progress()
		Engine.time_scale = 1.0
		get_tree().paused = false
		GameManager.set_state(GameManager.GameState.MAIN_MENU)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		_sr_input_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		var tw := create_tween()
		tw.tween_interval(0.45)
		tw.tween_callback(func() -> void:
			_sr_input = ""
			_sr_code = "%03d" % randi_range(100, 999)
			_sr_code_lbl.text = _sr_code
			_sr_input_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			_refresh_sr_input())
