class_name PauseMenu
extends CanvasLayer
## Pause menu overlay. Shown when player taps the timer.
## RESUME (green) and MENU (dark blue) buttons, same style as main menu.
## process_mode = ALWAYS so it works while tree is paused.

signal resume_pressed
signal menu_pressed
signal settings_applied   ## relayed from the in-game settings popup (Apply pressed)

const Anim := preload("res://scripts/utils/popup_anim.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

# ============================================================
# COLORS (shared with main_menu / death_screen)
# ============================================================
const OVERLAY_COLOR := Color(0, 0, 0, 0.65)

const PLAY_NORMAL := Color(0.18, 0.56, 0.18)
const PLAY_HOVER := Color(0.24, 0.66, 0.24)
const PLAY_PRESSED := Color(0.14, 0.46, 0.14)
const PLAY_BORDER := Color(0.92, 0.92, 0.92)

const SEC_NORMAL := Color(0.08, 0.12, 0.28, 0.92)
const SEC_HOVER := Color(0.12, 0.18, 0.38, 0.92)
const SEC_PRESSED := Color(0.05, 0.08, 0.20, 0.92)
const SEC_BORDER := Color(0.18, 0.28, 0.52)

# MENU button — red, to signal "destructive" (you'll lose run progress).
const MENU_NORMAL := Color(0.62, 0.12, 0.12, 0.95)
const MENU_HOVER := Color(0.74, 0.18, 0.18, 0.95)
const MENU_PRESSED := Color(0.50, 0.08, 0.08, 0.95)
const MENU_BORDER := Color(0.92, 0.36, 0.36)

# DANGER (red) — destructive "leave to menu" confirm button.
const DANGER_NORMAL := Color(0.82, 0.14, 0.14)
const DANGER_HOVER := Color(0.92, 0.22, 0.22)
const DANGER_PRESSED := Color(0.65, 0.10, 0.10)
const DANGER_BORDER := Color(0.95, 0.40, 0.40)

# Confirm dialog panel.
const PANEL_COLOR := Color(0.10, 0.10, 0.12, 0.98)
const PANEL_BORDER := Color(0.22, 0.22, 0.26)
const PANEL_CORNER := 22

# ============================================================
# LAYOUT — design values for 1920x1080 (scaled at runtime via _sf)
# ============================================================
const BTN_WIDTH := 440
const BTN_HEIGHT := 100
const BTN_FONT_SIZE := 48
const BTN_CORNER := 20
const BTN_BORDER_W := 4
const BTN_GAP := 42

const TITLE_FONT_SIZE := 68
const AD_BOX_SIZE := 520            ## square AdMob placeholder (left half), design px
const AD_COOLDOWN_SEC := 60.0       ## min gap between two pause-ad impressions (frequency cap)

## Engine-clock ms when the pause ad may show again. STATIC — the cap survives across
## pause-menu instances (level reloads) within one app run; ticks keep counting while paused.
static var _ad_next_ms: int = 0

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
var _content: VBoxContainer
var _title_label: Label
var _resume_btn: Button
var _settings_btn: Button
var _skip_btn: Button
var _menu_btn: Button
var _settings_popup: SettingsPopup
var _menu_confirm_overlay: ColorRect   ## "really leave to menu?" confirmation
var _ad_box: Panel                     ## square AdMob placeholder (left half)
var _level_info_box: PanelContainer    ## level name + star-rating times, shown below the ad (levels only)
var _level_name_lbl: Label
var _level_rating_lbl: Label

var _lilita: Font

func _ready() -> void:
	layer = 55  # Above HUD and death screen
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf(vp)
	_load_font()
	_build_overlay()
	_build_content()
	visible = false

func _load_font() -> void:
	_lilita = UIT.load_font()

## Square placeholder box for an AdMob medium-rectangle ad, centered in the LEFT half
## of the pause screen. The future AdMob view should be anchored over this node ("AdBox").
func _build_ad_box() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# The ad box + (levels-only) level-info card stack vertically, so the info sits below the ad.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", _s(16))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	_ad_box = Panel.new()
	_ad_box.name = "AdBox"
	var sz := AD_BOX_SIZE * _sf
	_ad_box.custom_minimum_size = Vector2(sz, sz)
	var sb := UIT.make_sb(_sf, Color(0.05, 0.05, 0.07, 0.92), Color(0.30, 0.30, 0.36), 18.0, 3.0)
	_ad_box.add_theme_stylebox_override("panel", sb)
	col.add_child(_ad_box)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = Loc.t("ad_space")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(34))
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52))
	lbl.add_theme_constant_override("outline_size", _s(3))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_ad_box.add_child(lbl)

	_build_level_info(col, sz)

## Level name + star-rating times card, under the ad (only shown in numbered levels).
## A PanelContainer so it AUTO-SIZES to its text (a plain Panel stayed 0-high and the
## labels spilled off the bottom of the screen).
func _build_level_info(col: VBoxContainer, ad_sz: float) -> void:
	_level_info_box = PanelContainer.new()
	_level_info_box.name = "LevelInfo"
	_level_info_box.custom_minimum_size = Vector2(ad_sz, 0)
	_level_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIT.make_sb(_sf, Color(0.08, 0.08, 0.11, 0.92), Color(0.30, 0.30, 0.40), 16.0, 3.0)
	sb.content_margin_left = _s(20)
	sb.content_margin_right = _s(20)
	sb.content_margin_top = _s(12)
	sb.content_margin_bottom = _s(12)
	_level_info_box.add_theme_stylebox_override("panel", sb)
	_level_info_box.visible = false
	col.add_child(_level_info_box)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", _s(6))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_info_box.add_child(vb)

	_level_name_lbl = Label.new()
	_level_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _lilita:
		_level_name_lbl.add_theme_font_override("font", _lilita)
	_level_name_lbl.add_theme_font_size_override("font_size", _s(30))
	_level_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	_level_name_lbl.add_theme_constant_override("outline_size", _s(4))
	_level_name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	vb.add_child(_level_name_lbl)

	_level_rating_lbl = Label.new()
	_level_rating_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_rating_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _lilita:
		_level_rating_lbl.add_theme_font_override("font", _lilita)
	_level_rating_lbl.add_theme_font_size_override("font_size", _s(23))
	_level_rating_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))   # gold, like stars
	_level_rating_lbl.add_theme_constant_override("outline_size", _s(3))
	_level_rating_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	vb.add_child(_level_rating_lbl)

## Populate + show the level-info card (numbered levels). `desc` already holds the star-rating line.
func set_level_info(level_name: String, desc: String) -> void:
	if _level_info_box == null:
		return
	_level_name_lbl.text = level_name
	_level_rating_lbl.text = desc
	_level_info_box.visible = true

func clear_level_info() -> void:
	if _level_info_box:
		_level_info_box.visible = false

# ============================================================
# BUILD
# ============================================================

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

func _build_content() -> void:
	# Menu content sits centered in the RIGHT half; the LEFT half holds the square
	# AdMob box (see _build_ad_box).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_left = 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 0)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_content)

	_build_ad_box()

	# ---- PAUSED title ----
	_title_label = Label.new()
	_title_label.text = Loc.t("paused")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_title_label.add_theme_font_override("font", _lilita)
	_title_label.add_theme_font_size_override("font_size", _s(TITLE_FONT_SIZE))
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_constant_override("outline_size", _s(7))
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_title_label)

	# ---- Spacer ----
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 56 * _sf)
	_content.add_child(sp)

	# ---- Buttons column ----
	var btn_col := VBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", _s(BTN_GAP))
	btn_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(btn_col)

	# Center buttons inside
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_col.add_child(row1)

	_resume_btn = Button.new()
	_resume_btn.name = "ResumeButton"
	_resume_btn.text = Loc.t("resume")
	_resume_btn.custom_minimum_size = Vector2(BTN_WIDTH * _sf, BTN_HEIGHT * _sf)
	_style_primary(_resume_btn)
	_resume_btn.pressed.connect(_on_resume)
	row1.add_child(_resume_btn)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_col.add_child(row2)

	_settings_btn = Button.new()
	_settings_btn.name = "SettingsButton"
	_settings_btn.text = Loc.t("settings")
	_settings_btn.custom_minimum_size = Vector2(BTN_WIDTH * _sf, BTN_HEIGHT * _sf)
	_style_secondary(_settings_btn)
	_settings_btn.pressed.connect(_on_settings)
	row2.add_child(_settings_btn)

	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_col.add_child(row3)

	_menu_btn = Button.new()
	_menu_btn.name = "MenuButton"
	_menu_btn.text = Loc.t("menu")
	_menu_btn.custom_minimum_size = Vector2(BTN_WIDTH * _sf, BTN_HEIGHT * _sf)
	_style_menu(_menu_btn)
	_menu_btn.pressed.connect(_on_menu)
	row3.add_child(_menu_btn)

	# ---- SKIP SONG (in the same column, below MENU — dark blue) ----
	var row4 := HBoxContainer.new()
	row4.alignment = BoxContainer.ALIGNMENT_CENTER
	row4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_col.add_child(row4)

	_skip_btn = Button.new()
	_skip_btn.name = "SkipSongButton"
	_skip_btn.text = Loc.t("skip_song")
	_skip_btn.custom_minimum_size = Vector2(BTN_WIDTH * _sf, BTN_HEIGHT * _sf)
	_style_secondary(_skip_btn)   # dark blue
	_skip_btn.pressed.connect(_on_skip_song)
	row4.add_child(_skip_btn)

	# Full settings popup (CanvasLayer — renders above pause menu). Language is locked
	# (greyed) in-game because changing it reloads the scene.
	_settings_popup = SettingsPopup.new()
	_settings_popup.name = "SettingsPopup"
	_settings_popup.language_locked = true
	add_child(_settings_popup)
	_settings_popup.settings_applied.connect(func() -> void: settings_applied.emit())

	# Confirmation dialog shown before actually leaving to the menu.
	_build_menu_confirm()

## "Really leave to the menu?" confirmation overlay.
func _build_menu_confirm() -> void:
	_menu_confirm_overlay = ColorRect.new()
	_menu_confirm_overlay.name = "MenuConfirm"
	_menu_confirm_overlay.color = Color(0, 0, 0, 0.6)
	_menu_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_confirm_overlay.visible = false
	add_child(_menu_confirm_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_confirm_overlay.add_child(cc)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(860 * _sf, 360 * _sf)
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
	ttl.text = Loc.t("leave_to_menu_title")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _lilita:
		ttl.add_theme_font_override("font", _lilita)
	ttl.add_theme_font_size_override("font_size", _s(46))
	ttl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	ttl.add_theme_constant_override("outline_size", _s(4))
	ttl.add_theme_color_override("font_outline_color", Color.BLACK)
	vb.add_child(ttl)

	var msg := Label.new()
	msg.text = Loc.t("leave_to_menu_msg")
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

	var dlg_btn_w := 320.0
	var dlg_btn_h := 92.0

	# Stay (green = safe) on the left.
	var stay_btn := Button.new()
	stay_btn.text = Loc.t("stay")
	stay_btn.custom_minimum_size = Vector2(dlg_btn_w * _sf, dlg_btn_h * _sf)
	_style_primary(stay_btn)
	stay_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_hide_menu_confirm())
	row.add_child(stay_btn)

	# Leave to menu (red = destructive) on the right.
	var leave_btn := Button.new()
	leave_btn.text = Loc.t("menu")
	leave_btn.custom_minimum_size = Vector2(dlg_btn_w * _sf, dlg_btn_h * _sf)
	_style_danger(leave_btn)
	leave_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_hide_menu_confirm()
		Anim.close(_overlay, _content, func() -> void: menu_pressed.emit()))
	row.add_child(leave_btn)

func _show_menu_confirm() -> void:
	if _menu_confirm_overlay:
		_menu_confirm_overlay.visible = true

func _hide_menu_confirm() -> void:
	if _menu_confirm_overlay:
		_menu_confirm_overlay.visible = false

# ============================================================
# STYLING
# ============================================================

func _style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(PLAY_NORMAL, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(PLAY_HOVER, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(PLAY_PRESSED, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(PLAY_NORMAL, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _style_secondary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(SEC_NORMAL, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(SEC_HOVER, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(SEC_PRESSED, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(SEC_NORMAL, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _style_menu(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(MENU_NORMAL, MENU_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(MENU_HOVER, MENU_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(MENU_PRESSED, MENU_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(MENU_NORMAL, MENU_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _style_danger(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(DANGER_NORMAL, DANGER_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(DANGER_HOVER, DANGER_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(DANGER_PRESSED, DANGER_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(DANGER_NORMAL, DANGER_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _apply_btn_font(btn: Button) -> void:
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(BTN_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_constant_override("outline_size", _s(6))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

func _make_sb(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 24.0, 14.0)

# ============================================================
# PUBLIC
# ============================================================

## `user_initiated` = false for the automatic focus-loss pause: that one NEVER shows the
## ad (the returning finger lands where the game was — classic accidental-click source).
func show_pause(user_initiated: bool = true) -> void:
	visible = true
	_update_ad_slot(user_initiated)
	_hide_menu_confirm()   # always start without the confirm dialog up
	Anim.open(_overlay, _content, OVERLAY_COLOR.a)

## Frequency cap (AdMob accidental-click protection): the ad slot appears only on a
## player-initiated pause and at most once per AD_COOLDOWN_SEC. Re-pausing sooner keeps
## the slot empty until the timer runs out. When the real MREC is integrated, load/show
## the native ad view here (and hide it in hide_pause()).
func _update_ad_slot(user_initiated: bool) -> void:
	if _ad_box == null:
		return
	var now := Time.get_ticks_msec()
	var show_ad := user_initiated and now >= _ad_next_ms
	_ad_box.visible = show_ad
	if show_ad:
		_ad_next_ms = now + int(AD_COOLDOWN_SEC * 1000.0)

func hide_pause() -> void:
	_hide_menu_confirm()
	visible = false

# ============================================================
# ACTIONS
# ============================================================

func _on_resume() -> void:
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _content, func() -> void: resume_pressed.emit())

func _on_settings() -> void:
	AudioManager.play_sfx("button_click_menu")
	if _settings_popup:
		_settings_popup.show_popup()

func _on_skip_song() -> void:
	AudioManager.play_sfx("button_click_menu")
	AudioManager.skip_track()

func _on_menu() -> void:
	AudioManager.play_sfx("button_click_menu")
	# Don't leave immediately — confirm first.
	_show_menu_confirm()
