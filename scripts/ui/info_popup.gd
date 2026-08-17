class_name InfoPopup
extends CanvasLayer
## Info / credits popup — opened by tapping the version text in the main menu.
## ColorSplat logo up top, then author, game description, testing thanks, a good-luck
## wish and the AI-assistance note (all via Loc). Same dark-panel style as the other
## menu popups; tap the X or outside the panel to close.

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

const CLOSE_NORMAL := Color(0.55, 0.12, 0.12)
const CLOSE_HOVER := Color(0.65, 0.18, 0.18)
const CLOSE_PRESSED := Color(0.45, 0.08, 0.08)
const CLOSE_BORDER := Color(0.75, 0.25, 0.25)

# ============================================================
# LAYOUT — design values for 1920x1080 (scaled at runtime via _sf)
# ============================================================
const PANEL_WIDTH := 1150
const PANEL_HEIGHT := 820
const LOGO_WIDTH := 420
const AUTHOR_FONT_SIZE := 36
const BODY_FONT_SIZE := 27
const AI_FONT_SIZE := 22
const CLOSE_FONT_SIZE := 38
const CLOSE_WIDTH := 300
const CLOSE_HEIGHT := 80
const CLOSE_CORNER := 16
const CLOSE_BORDER_W := 3

# ---- Legal links (privacy policy / ad privacy) — same shape as CLOSE, but neutral dark
# instead of red (red reads as "destructive", these are informational). ----
const LEGAL_NORMAL := Color(0.13, 0.14, 0.20)
const LEGAL_HOVER := Color(0.19, 0.21, 0.29)
const LEGAL_PRESSED := Color(0.09, 0.10, 0.15)
const LEGAL_BORDER := Color(0.32, 0.38, 0.55)
const LEGAL_FONT_SIZE := 26
const LEGAL_WIDTH := 380
const LEGAL_HEIGHT := 72

var _sf: float = 1.0

func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

var _overlay: ColorRect
var _panel: Panel
var _lilita: Font

func _ready() -> void:
	layer = 60  # Above pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_WIDTH, PANEL_HEIGHT))
	_lilita = UIT.load_font()
	_build_overlay()
	_build_panel()
	visible = false

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

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = maxf(64 * _sf, 10.0)
	vbox.offset_right = -maxf(64 * _sf, 10.0)
	vbox.offset_top = 36 * _sf
	vbox.offset_bottom = -36 * _sf
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", _s(20))
	_panel.add_child(vbox)

	# ---- Logo (top center) ----
	var logo_path := "res://assets/sprites/ui/logo.png"
	if ResourceLoader.exists(logo_path):
		var logo := TextureRect.new()
		logo.texture = load(logo_path)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_size: Vector2 = logo.texture.get_size()
		var w := LOGO_WIDTH * _sf
		logo.custom_minimum_size = Vector2(w, w * tex_size.y / maxf(tex_size.x, 1.0))
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(logo)

	# ---- Text blocks ----
	_add_label(vbox, Loc.t("info_author"), AUTHOR_FONT_SIZE, Color(1.0, 0.85, 0.3))
	_add_label(vbox, Loc.t("info_desc"), BODY_FONT_SIZE, Color.WHITE)
	_add_label(vbox, Loc.t("info_thanks"), BODY_FONT_SIZE, Color.WHITE)
	_add_label(vbox, Loc.t("info_wish"), BODY_FONT_SIZE, Color(0.55, 0.95, 0.55))
	_add_label(vbox, Loc.t("info_ai"), AI_FONT_SIZE, Color(0.55, 0.55, 0.6))

	# ---- Close button ----
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6 * _sf)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = Loc.t("close")
	close_btn.custom_minimum_size = Vector2(CLOSE_WIDTH * _sf, CLOSE_HEIGHT * _sf)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _lilita:
		close_btn.add_theme_font_override("font", _lilita)
	close_btn.add_theme_font_size_override("font_size", _s(CLOSE_FONT_SIZE))
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	close_btn.add_theme_constant_override("outline_size", _s(4))
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var bg := CLOSE_NORMAL
		if st == "hover": bg = CLOSE_HOVER
		elif st == "pressed": bg = CLOSE_PRESSED
		close_btn.add_theme_stylebox_override(st, _make_sb(bg, CLOSE_BORDER, CLOSE_CORNER, CLOSE_BORDER_W))
	close_btn.pressed.connect(_on_close)
	vbox.add_child(close_btn)

	# ---- Legal links (under the buttons) ----
	# Google Play requires a reachable privacy policy for ad-supported apps, and Google requires
	# the GDPR consent choice to stay changeable at any time — both live here.
	_build_legal_links(vbox)

## Two small grey text links under the close button: privacy policy + ad-privacy (consent).
func _build_legal_links(vbox: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10 * _sf)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(28))
	vbox.add_child(row)

	row.add_child(_make_legal_link(Loc.t("privacy_policy"),
		func() -> void: OS.shell_open(AdManager.PRIVACY_POLICY_URL)))
	row.add_child(_make_legal_link(Loc.t("privacy_settings"),
		func() -> void: AdManager.show_consent_form()))

func _make_legal_link(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(LEGAL_WIDTH * _sf, LEGAL_HEIGHT * _sf)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long translations (DE/FR) still fit
	if _lilita:
		b.add_theme_font_override("font", _lilita)
	b.add_theme_font_size_override("font_size", _s(LEGAL_FONT_SIZE))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", _s(3))
	# Same rounded/bordered treatment as the close button, in neutral dark.
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var bg := LEGAL_NORMAL
		if st == "hover": bg = LEGAL_HOVER
		elif st == "pressed": bg = LEGAL_PRESSED
		b.add_theme_stylebox_override(st, _make_sb(bg, LEGAL_BORDER, CLOSE_CORNER, CLOSE_BORDER_W))
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		on_press.call())
	return b

func _add_label(parent: VBoxContainer, text: String, font_size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(font_size))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", _s(3))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

func _make_sb(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_corner_radius_all(_s(corner))
	sb.set_border_width_all(_s(border_w))
	return sb

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _on_close() -> void:
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _panel, func() -> void:
		visible = false
		closed.emit())

func show_popup() -> void:
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)
