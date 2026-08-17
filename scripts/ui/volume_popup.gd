class_name VolumePopup
extends CanvasLayer
## Volume settings popup — dark overlay with Music + SFX sliders.
## Sliders go from 0% to 100% in 10% steps.
## Reusable — can be added to MainMenu, PauseMenu, etc.
## process_mode = ALWAYS so it works while the tree is paused.

signal closed

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

const SLIDER_BG_COLOR := Color(0.18, 0.18, 0.24)
const SLIDER_FILL_COLOR := Color(0.22, 0.58, 0.22)
const SLIDER_GRAB_COLOR := Color(0.92, 0.92, 0.92)

const CLOSE_NORMAL := Color(0.55, 0.12, 0.12)
const CLOSE_HOVER := Color(0.65, 0.18, 0.18)
const CLOSE_PRESSED := Color(0.45, 0.08, 0.08)
const CLOSE_BORDER := Color(0.75, 0.25, 0.25)

# ============================================================
# LAYOUT — design values for 1920x1080 (scaled at runtime via _sf)
# ============================================================
const PANEL_WIDTH := 600
const PANEL_HEIGHT := 500
const TITLE_FONT_SIZE := 52
const LABEL_FONT_SIZE := 34
const VALUE_FONT_SIZE := 30
const CLOSE_FONT_SIZE := 38
const CLOSE_WIDTH := 300
const CLOSE_HEIGHT := 80
const CLOSE_CORNER := 16
const CLOSE_BORDER_W := 3
const SLIDER_HEIGHT := 40

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

var _lilita: Font

func _ready() -> void:
	layer = 60  # Above pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_WIDTH, PANEL_HEIGHT))
	_load_font()
	_build_overlay()
	_build_panel()
	visible = false

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
	# Tap outside panel to close
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

func _build_panel() -> void:
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Panel background
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

	# VBox inside panel
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = maxf(48 * _sf, 10.0)
	vbox.offset_right = -maxf(48 * _sf, 10.0)
	vbox.offset_top = 40 * _sf
	vbox.offset_bottom = -40 * _sf
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", _s(18))
	_panel.add_child(vbox)

	# ---- Title ----
	var title := Label.new()
	title.text = Loc.t("volume_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		title.add_theme_font_override("font", _lilita)
	title.add_theme_font_size_override("font_size", _s(TITLE_FONT_SIZE))
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", _s(6))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)

	# ---- Spacer ----
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 10 * _sf)
	vbox.add_child(sp1)

	# ---- Music slider ----
	_music_slider = _build_slider_row(vbox, Loc.t("music"), "_on_music_changed")
	_music_value_label = _get_value_label(vbox)

	# ---- Spacer ----
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 6 * _sf)
	vbox.add_child(sp2)

	# ---- SFX slider ----
	_sfx_slider = _build_slider_row(vbox, Loc.t("sfx"), "_on_sfx_changed")
	_sfx_value_label = _get_value_label(vbox)

	# ---- Spacer ----
	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 16 * _sf)
	vbox.add_child(sp3)

	# ---- Close button ----
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(close_row)

	_close_btn = Button.new()
	_close_btn.text = Loc.t("close")
	_close_btn.custom_minimum_size = Vector2(CLOSE_WIDTH * _sf, CLOSE_HEIGHT * _sf)
	_style_close_button(_close_btn)
	_close_btn.pressed.connect(_on_close)
	close_row.add_child(_close_btn)

	# Load current values from AudioManager
	_music_slider.value = AudioManager._music_volume * 100.0
	_sfx_slider.value = AudioManager._effect_volume * 100.0
	_update_value_label(_music_value_label, _music_slider.value)
	_update_value_label(_sfx_value_label, _sfx_slider.value)

func _build_slider_row(parent: VBoxContainer, label_text: String, callback: String) -> HSlider:
	# Label + value on same line
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

	# Value label (right-aligned)
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

	# Slider
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

## Get the most recently added value label from the header row.
func _get_value_label(vbox: VBoxContainer) -> Label:
	# The label is in the header HBox (2nd child from last, before the slider)
	var header: HBoxContainer = vbox.get_child(vbox.get_child_count() - 2) as HBoxContainer
	return header.get_child(1) as Label

func _style_slider(slider: HSlider) -> void:
	# Background (groove)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = SLIDER_BG_COLOR
	bg_style.set_corner_radius_all(_s(8))
	bg_style.content_margin_top = 8 * _sf
	bg_style.content_margin_bottom = 8 * _sf
	slider.add_theme_stylebox_override("slider", bg_style)

	# Filled portion
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = SLIDER_FILL_COLOR
	fill_style.set_corner_radius_all(_s(8))
	fill_style.content_margin_top = 8 * _sf
	fill_style.content_margin_bottom = 8 * _sf
	slider.add_theme_stylebox_override("grabber_area", fill_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)

	# Grabber (thumb)
	var grab_size := _s(28)
	slider.add_theme_icon_override("grabber", _make_grabber_texture(SLIDER_GRAB_COLOR, grab_size))
	slider.add_theme_icon_override("grabber_highlight", _make_grabber_texture(Color.WHITE, grab_size))

func _make_grabber_texture(color: Color, p_size: int = 28) -> ImageTexture:
	var img := Image.create(p_size, p_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(p_size / 2.0, p_size / 2.0)
	var radius := p_size / 2.0
	for y in p_size:
		for x in p_size:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
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

func _make_sb(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 20.0, 12.0)

# ============================================================
# CALLBACKS
# ============================================================

func _on_music_changed(value: float) -> void:
	_update_value_label(_music_value_label, value)
	AudioManager.apply_settings(value, _sfx_slider.value)

func _on_sfx_changed(value: float) -> void:
	_update_value_label(_sfx_value_label, value)
	AudioManager.apply_settings(_music_slider.value, value)

func _update_value_label(lbl: Label, value: float) -> void:
	lbl.text = "%d%%" % int(value)

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _on_close() -> void:
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _panel, func() -> void:
		visible = false
		closed.emit())

# ============================================================
# PUBLIC
# ============================================================

func show_popup() -> void:
	# Sync with current AudioManager values
	_music_slider.value = AudioManager._music_volume * 100.0
	_sfx_slider.value = AudioManager._effect_volume * 100.0
	_update_value_label(_music_value_label, _music_slider.value)
	_update_value_label(_sfx_value_label, _sfx_slider.value)
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)

func hide_popup() -> void:
	visible = false
