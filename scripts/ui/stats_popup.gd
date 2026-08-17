class_name StatsPopup
extends CanvasLayer
## Stats & Achievements popup — dark overlay with scrollable stats grid.
## Two tabs at top: STATS / ACHIEVEMENTS.
## Stats: total kills, per-type kills (icon + name + count),
##        best endless time, total play time, longest session, best endless kills.
## Achievements: placeholder (coming soon).
## Uses same visual style as VolumePopup / MainMenu.

signal closed

const Anim := preload("res://scripts/utils/popup_anim.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")
const Ach := preload("res://scripts/data/achievement_data.gd")
const LevelData := preload("res://scripts/data/level_data.gd")
const ChallengeReg := preload("res://scripts/ui/challenge_select_popup.gd")

## Grayscale + dim filter applied to locked achievement icons.
const GRAYSCALE_SHADER := "
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * 0.65, c.a);
}
"

# ============================================================
# COLORS (match main_menu / volume_popup style)
# ============================================================
const OVERLAY_COLOR := Color(0, 0, 0, 0.75)
const PANEL_COLOR := Color(0.10, 0.10, 0.14, 0.95)
const PANEL_BORDER := Color(0.25, 0.35, 0.55)
const PANEL_CORNER := 20

const TAB_ACTIVE_BG := Color(0.18, 0.22, 0.40, 0.95)
const TAB_INACTIVE_BG := Color(0.08, 0.10, 0.18, 0.80)
const TAB_ACTIVE_BORDER := Color(0.35, 0.50, 0.80)
const TAB_INACTIVE_BORDER := Color(0.18, 0.22, 0.36)

const CLOSE_NORMAL := Color(0.55, 0.12, 0.12)
const CLOSE_HOVER := Color(0.65, 0.18, 0.18)
const CLOSE_PRESSED := Color(0.45, 0.08, 0.08)
const CLOSE_BORDER := Color(0.75, 0.25, 0.25)

const ROW_BG_A := Color(0.12, 0.12, 0.18, 0.6)
const ROW_BG_B := Color(0.09, 0.09, 0.14, 0.6)

const STAT_VALUE_COLOR := Color(1.0, 0.9, 0.2)        ## Yellow for numbers
const STAT_LABEL_COLOR := Color(0.78, 0.78, 0.82)     ## Light grey for labels
const HEADER_COLOR := Color(0.55, 0.75, 1.0)          ## Light blue for section headers

# ============================================================
# LAYOUT — design values for 1920x1080 (scaled at runtime via _sf)
# ============================================================
const PANEL_WIDTH := 920   ## match the Settings popup width
const PANEL_HEIGHT := 820
const TITLE_FONT_SIZE := 48
const TAB_FONT_SIZE := 34
const SECTION_FONT_SIZE := 34
const LABEL_FONT_SIZE := 32
const VALUE_FONT_SIZE := 32
const CLOSE_FONT_SIZE := 36
const CLOSE_WIDTH := 280
const CLOSE_HEIGHT := 74
const CLOSE_CORNER := 16
const CLOSE_BORDER_W := 3
const TAB_WIDTH := 340
const TAB_HEIGHT := 70
const TAB_CORNER := 14
const TAB_BORDER_W := 2
const ICON_SIZE := 48            ## Monster icon size
const ROW_HEIGHT := 60           ## Height per stat row
const ROW_PADDING_H := 18       ## Horizontal padding inside rows
const ROW_CORNER := 8

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
var _tab_stats_btn: Button
var _tab_achievements_btn: Button
var _stats_container: ScrollContainer
var _achievements_container: ScrollContainer
var _close_btn: Button

var _lilita: Font

# ---- Touch drag-to-scroll with inertia (swipe) for the stats / achievements lists ----
const FLING_DECAY := 5.0         ## inertia decay rate (higher = stops sooner)
const FLING_MIN_START := 45.0    ## min release speed (px/s) to keep gliding
const FLING_MIN_STOP := 8.0      ## speed below which the glide stops
var _drag_active: bool = false
var _drag_start_y: float = 0.0
var _drag_start_scroll: int = 0
var _drag_scroll: ScrollContainer = null
var _scroll_f: float = 0.0       ## float mirror of scroll_vertical for smooth momentum
var _fling_vel: float = 0.0      ## inertial scroll velocity (px/s) after release
var _last_drag_y: float = 0.0
var _last_drag_t: float = 0.0

# ============================================================
# MONSTER TYPE ORDER (for display)
# ============================================================
const MONSTER_ORDER: Array = [
	MonsterTypes.Type.BASIC,
	MonsterTypes.Type.TANK,
	MonsterTypes.Type.TANKBOMBER,
	MonsterTypes.Type.SPEEDER,
	MonsterTypes.Type.BRUTE,
	MonsterTypes.Type.HEALER,
	MonsterTypes.Type.SPAWNER,
	MonsterTypes.Type.SPLITTER,
	MonsterTypes.Type.GHOST,
]

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	layer = 60  # Same level as VolumePopup
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_WIDTH, PANEL_HEIGHT))
	_load_font()
	_build_overlay()
	_build_panel()
	visible = false

## Touch/mouse drag-to-scroll (swipe) for whichever list (stats/achievements) is showing.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			var sc := _active_scroll()
			if sc == null:
				return
			# Don't hijack a press on the scrollbar grabber — let the native bar handle it.
			var vbar := sc.get_v_scroll_bar()
			var on_scrollbar: bool = vbar != null and vbar.visible and vbar.get_global_rect().has_point(event.position)
			if not on_scrollbar and sc.get_global_rect().has_point(event.position):
				_drag_scroll = sc
				_drag_active = true
				_drag_start_y = event.position.y
				_drag_start_scroll = sc.scroll_vertical
				_scroll_f = float(sc.scroll_vertical)
				_fling_vel = 0.0
				_last_drag_y = event.position.y
				_last_drag_t = float(Time.get_ticks_msec()) / 1000.0
		else:
			# Released: keep _drag_scroll + _fling_vel so _process glides; drop the
			# fling for tiny flicks or if the finger was held still before lifting.
			if _drag_active:
				var held := (float(Time.get_ticks_msec()) / 1000.0) - _last_drag_t > 0.05
				if held or absf(_fling_vel) < FLING_MIN_START:
					_fling_vel = 0.0
			_drag_active = false
	elif _drag_active and _drag_scroll != null and (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)):
		var dy: float = event.position.y - _drag_start_y
		var now := float(Time.get_ticks_msec()) / 1000.0
		var dt := now - _last_drag_t
		if dt > 0.0005:
			_fling_vel = -(event.position.y - _last_drag_y) / dt  # scroll moves opposite the finger
			_last_drag_y = event.position.y
			_last_drag_t = now
		_scroll_f = float(_drag_start_scroll) - dy
		_drag_scroll.scroll_vertical = int(round(_scroll_f))
		get_viewport().set_input_as_handled()  # don't let the list double-scroll

## Inertial glide after the finger lifts.
func _process(delta: float) -> void:
	if _drag_active or not visible or _drag_scroll == null:
		return
	if absf(_fling_vel) <= FLING_MIN_STOP:
		_fling_vel = 0.0
		return
	var max_scroll := 0.0
	var vbar := _drag_scroll.get_v_scroll_bar()
	if vbar:
		max_scroll = maxf(0.0, vbar.max_value - vbar.page)
	_scroll_f += _fling_vel * delta
	if _scroll_f <= 0.0:
		_scroll_f = 0.0
		_fling_vel = 0.0
	elif _scroll_f >= max_scroll:
		_scroll_f = max_scroll
		_fling_vel = 0.0
	_drag_scroll.scroll_vertical = int(round(_scroll_f))
	_fling_vel *= exp(-FLING_DECAY * delta)

## The scroll container of the currently-visible tab.
func _active_scroll() -> ScrollContainer:
	if _achievements_container and _achievements_container.visible:
		return _achievements_container
	if _stats_container and _stats_container.visible:
		return _stats_container
	return null

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
	vbox.offset_left = maxf(30 * _sf, 10.0)
	vbox.offset_right = -maxf(30 * _sf, 10.0)
	vbox.offset_top = 24 * _sf
	vbox.offset_bottom = -24 * _sf
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	# ---- Create scroll containers first (needed by _set_active_tab) ----
	_stats_container = ScrollContainer.new()
	_stats_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stats_container.mouse_filter = Control.MOUSE_FILTER_PASS
	Anim.style_scrollbar(_stats_container, _sf)

	_achievements_container = ScrollContainer.new()
	_achievements_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_achievements_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_achievements_container.mouse_filter = Control.MOUSE_FILTER_PASS
	Anim.style_scrollbar(_achievements_container, _sf)

	# ---- Tab row ----
	_build_tab_row(vbox)

	# ---- Spacer ----
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 14 * _sf)
	vbox.add_child(sp1)

	# ---- Add scroll containers to layout ----
	vbox.add_child(_stats_container)
	vbox.add_child(_achievements_container)

	# ---- Spacer ----
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 14 * _sf)
	vbox.add_child(sp2)

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

	# Build initial content
	_rebuild_achievements_content()

# ============================================================
# TABS
# ============================================================

func _build_tab_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	_tab_stats_btn = Button.new()
	_tab_stats_btn.text = Loc.t("tab_stats")
	_tab_stats_btn.custom_minimum_size = Vector2(TAB_WIDTH * _sf, TAB_HEIGHT * _sf)
	_tab_stats_btn.pressed.connect(_on_tab_stats)
	row.add_child(_tab_stats_btn)

	_tab_achievements_btn = Button.new()
	_tab_achievements_btn.text = Loc.t("tab_achievements")
	_tab_achievements_btn.custom_minimum_size = Vector2(TAB_WIDTH * _sf, TAB_HEIGHT * _sf)
	_tab_achievements_btn.pressed.connect(_on_tab_achievements)
	row.add_child(_tab_achievements_btn)

	_apply_tab_font(_tab_stats_btn)
	_apply_tab_font(_tab_achievements_btn)
	_set_active_tab(true)  # Stats active by default

func _apply_tab_font(btn: Button) -> void:
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(TAB_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_constant_override("outline_size", _s(4))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

func _set_active_tab(stats_active: bool) -> void:
	if stats_active:
		_tab_stats_btn.add_theme_stylebox_override("normal", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_stats_btn.add_theme_stylebox_override("hover", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_stats_btn.add_theme_stylebox_override("pressed", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_stats_btn.add_theme_stylebox_override("focus", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))

		_tab_achievements_btn.add_theme_stylebox_override("normal", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_achievements_btn.add_theme_stylebox_override("hover", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_achievements_btn.add_theme_stylebox_override("pressed", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_achievements_btn.add_theme_stylebox_override("focus", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))

		_stats_container.visible = true
		_achievements_container.visible = false
	else:
		_tab_achievements_btn.add_theme_stylebox_override("normal", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_achievements_btn.add_theme_stylebox_override("hover", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_achievements_btn.add_theme_stylebox_override("pressed", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_achievements_btn.add_theme_stylebox_override("focus", _make_sb(TAB_ACTIVE_BG, TAB_ACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))

		_tab_stats_btn.add_theme_stylebox_override("normal", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_stats_btn.add_theme_stylebox_override("hover", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_stats_btn.add_theme_stylebox_override("pressed", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))
		_tab_stats_btn.add_theme_stylebox_override("focus", _make_sb(TAB_INACTIVE_BG, TAB_INACTIVE_BORDER, TAB_CORNER, TAB_BORDER_W))

		_stats_container.visible = false
		_achievements_container.visible = true

func _on_tab_stats() -> void:
	AudioManager.play_sfx("button_click_menu")
	_set_active_tab(true)

func _on_tab_achievements() -> void:
	AudioManager.play_sfx("button_click_menu")
	_set_active_tab(false)

# ============================================================
# STATS CONTENT (rebuilt each time popup opens for fresh data)
# ============================================================

func _rebuild_stats_content() -> void:
	# Clear previous content
	for child in _stats_container.get_children():
		child.queue_free()

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", _s(30))
	_stats_container.add_child(pad)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", _s(4))
	pad.add_child(content)

	var row_idx := 0

	# ==== RUN group — this run's progress (wiped by a speedrun reset). Shown FIRST. ====
	_add_group_header(content, Loc.t("stats_run"), Loc.t("stats_run_sub"))
	_add_section_header(content, Loc.t("sec_progress"))
	_add_stat_row(content, Loc.t("st_levels_done"),
		"%d/%d" % [_levels_completed_count(), LevelData.TOTAL_LEVELS], row_idx)
	row_idx += 1
	_add_stat_row(content, Loc.t("st_challenges_done"),
		"%d/%d" % [_challenges_completed_count(), ChallengeReg.CHALLENGES.size()], row_idx)
	row_idx += 1
	_add_stat_row(content, Loc.t("st_game_completion"),
		"%d%%" % _game_completion_percent(), row_idx)
	row_idx += 1

	# ---- Spacer ----
	var sp_glob := Control.new()
	sp_glob.custom_minimum_size = Vector2(0, 18 * _sf)
	content.add_child(sp_glob)

	# ==== GLOBAL group — survives a speedrun reset ====
	_add_group_header(content, Loc.t("stats_global"), Loc.t("stats_global_sub"))

	# ---- COMBAT section header ----
	_add_section_header(content, Loc.t("sec_combat"))

	# Total kills
	_add_stat_row(content, Loc.t("st_total_kills"), _format_int(SaveManager.get_stat("total_kills")), row_idx)
	row_idx += 1

	# Total deaths
	_add_stat_row(content, Loc.t("st_total_deaths"), _format_int(SaveManager.get_stat("total_deaths")), row_idx)
	row_idx += 1

	# Total bullets fired
	_add_stat_row(content, Loc.t("st_bullets"), _format_int(SaveManager.get_stat("total_bullets_fired")), row_idx)
	row_idx += 1

	# ---- Spacer ----
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 10 * _sf)
	content.add_child(sp1)

	# ---- PER-TYPE KILLS section header ----
	_add_section_header(content, Loc.t("sec_kills_type"))
	row_idx = 0

	for type: MonsterTypes.Type in MONSTER_ORDER:
		var type_name: String = Loc.t("mon_" + MonsterTypes.Type.keys()[type].to_lower())
		var stat_key := "kills_%s" % MonsterTypes.Type.keys()[type].to_lower()
		var kill_count := int(SaveManager.get_stat(stat_key))
		_add_monster_stat_row(content, type, type_name, kill_count, row_idx)
		row_idx += 1

	# ---- Spacer ----
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 10 * _sf)
	content.add_child(sp2)

	# ---- ENDLESS MODE section ----
	_add_section_header(content, Loc.t("sec_endless"))
	row_idx = 0

	# Best survival time
	var best_time := SaveManager.get_endless_best()
	_add_stat_row(content, Loc.t("st_best_survival"), _format_time(best_time), row_idx)
	row_idx += 1

	# Most kills in endless — shown as a full integer (no k/m abbreviation)
	var best_kills := int(SaveManager.get_stat("endless_best_kills"))
	_add_stat_row(content, Loc.t("st_most_kills"), str(best_kills), row_idx)
	row_idx += 1

	# ---- Spacer ----
	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 10 * _sf)
	content.add_child(sp3)

	# ---- TIME section ----
	_add_section_header(content, Loc.t("sec_time"))
	row_idx = 0

	# Total play time
	var total_time := SaveManager.get_stat("total_play_time")
	_add_stat_row(content, Loc.t("st_total_time"), _format_duration(total_time), row_idx)
	row_idx += 1

	# Longest session
	var longest := SaveManager.get_stat("longest_session_time")
	_add_stat_row(content, Loc.t("st_longest"), _format_duration(longest), row_idx)
	row_idx += 1

# ============================================================
# PROGRESS COUNTS
# ============================================================

## Levels with at least bronze (a completed level always earns ≥1 star).
func _levels_completed_count() -> int:
	var n := 0
	for i in range(1, LevelData.TOTAL_LEVELS + 1):
		if SaveManager.get_level_stars(i) >= 1:
			n += 1
	return n

## Challenges marked complete (out of the 8 in the challenge registry).
func _challenges_completed_count() -> int:
	var n := 0
	for ch: Dictionary in ChallengeReg.CHALLENGES:
		if SaveManager.is_challenge_complete(String(ch.get("id", ""))):
			n += 1
	return n

## Overall game completion 0-100 %, by share of unlocked achievements.
func _game_completion_percent() -> int:
	var total: int = Ach.ACHIEVEMENTS.size()
	if total == 0:
		return 0
	var unlocked := 0
	for a: Dictionary in Ach.ACHIEVEMENTS:
		if SaveManager.is_achievement_unlocked(String(a.get("id", ""))):
			unlocked += 1
	return int(round(float(unlocked) / float(total) * 100.0))

# ============================================================
# ROW BUILDERS
# ============================================================

## A prominent GROUP header (GLOBAL / THIS RUN) with a small grey subtitle underneath.
## Bigger + a coloured underline so the two stat groups read as distinct sections.
func _add_group_header(parent: VBoxContainer, title: String, subtitle: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _s(2))
	var lbl := Label.new()
	lbl.text = title
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(SECTION_FONT_SIZE + 8))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl.add_theme_constant_override("outline_size", _s(5))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(lbl)
	var sub := Label.new()
	sub.text = subtitle
	if _lilita:
		sub.add_theme_font_override("font", _lilita)
	sub.add_theme_font_size_override("font_size", _s(22))
	sub.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	sub.add_theme_constant_override("outline_size", _s(2))
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(1.0, 0.85, 0.35, 0.5)
	line.custom_minimum_size = Vector2(0, maxi(1, _s(3)))
	box.add_child(line)
	parent.add_child(box)

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(SECTION_FONT_SIZE))
	lbl.add_theme_color_override("font_color", HEADER_COLOR)
	lbl.add_theme_constant_override("outline_size", _s(4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.custom_minimum_size = Vector2(0, 40 * _sf)
	parent.add_child(lbl)

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String, idx: int) -> void:
	var row := _make_row_panel(idx)
	parent.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = ROW_PADDING_H * _sf
	hbox.offset_right = -ROW_PADDING_H * _sf
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(hbox)

	# Label
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	lbl.add_theme_color_override("font_color", STAT_LABEL_COLOR)
	lbl.add_theme_constant_override("outline_size", _s(3))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hbox.add_child(lbl)

	# Value
	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _lilita:
		val.add_theme_font_override("font", _lilita)
	val.add_theme_font_size_override("font_size", _s(VALUE_FONT_SIZE))
	val.add_theme_color_override("font_color", STAT_VALUE_COLOR)
	val.add_theme_constant_override("outline_size", _s(3))
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.custom_minimum_size = Vector2(160 * _sf, 0)
	hbox.add_child(val)

func _add_monster_stat_row(parent: VBoxContainer, type: MonsterTypes.Type, type_name: String, kills: int, idx: int) -> void:
	var row := _make_row_panel(idx)
	parent.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = ROW_PADDING_H * _sf
	hbox.offset_right = -ROW_PADDING_H * _sf
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", _s(12))
	row.add_child(hbox)

	# Monster icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE * _sf, ICON_SIZE * _sf)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := SpriteLoader.get_monster_texture(type)
	if tex:
		icon.texture = tex
	hbox.add_child(icon)

	# Monster name
	var lbl := Label.new()
	lbl.text = type_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	lbl.add_theme_color_override("font_color", MonsterTypes.get_color(type))
	lbl.add_theme_constant_override("outline_size", _s(3))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hbox.add_child(lbl)

	# Kill count
	var val := Label.new()
	val.text = _format_int(kills)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _lilita:
		val.add_theme_font_override("font", _lilita)
	val.add_theme_font_size_override("font_size", _s(VALUE_FONT_SIZE))
	val.add_theme_color_override("font_color", STAT_VALUE_COLOR)
	val.add_theme_constant_override("outline_size", _s(3))
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.custom_minimum_size = Vector2(120 * _sf, 0)
	hbox.add_child(val)

func _make_row_panel(idx: int) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT * _sf)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_BG_A if idx % 2 == 0 else ROW_BG_B
	sb.set_corner_radius_all(_s(ROW_CORNER))
	row.add_theme_stylebox_override("panel", sb)
	return row

# ============================================================
# ACHIEVEMENTS PLACEHOLDER
# ============================================================

## Build (or rebuild) the achievements list: one row per achievement. Unlocked =
## full-color icon + lightly tinted panel; locked = grayscale icon + dark panel.
func _rebuild_achievements_content() -> void:
	for child in _achievements_container.get_children():
		child.queue_free()

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", _s(30))
	_achievements_container.add_child(pad)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", _s(10))
	pad.add_child(list)

	# First all achievements that COUNT toward 100 % (the meta "100 % Complete" is last of
	# these), then a divider + small heading, then the cosmetic/playtime ones that don't count.
	for a: Dictionary in Ach.ACHIEVEMENTS:
		var id: String = a.get("id", "")
		if id in Ach.NON_COMPLETION_IDS:
			continue
		list.add_child(_make_achievement_row(id, SaveManager.is_achievement_unlocked(id)))
	list.add_child(_make_ach_divider())
	for a2: Dictionary in Ach.ACHIEVEMENTS:
		var id2: String = a2.get("id", "")
		if id2 in Ach.NON_COMPLETION_IDS:
			list.add_child(_make_achievement_row(id2, SaveManager.is_achievement_unlocked(id2)))

## Divider between the 100 %-counting achievements and the cosmetic ones below, with a small
## "Not counted toward 100 %" heading.
func _make_ach_divider() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _s(8))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, _s(12))
	box.add_child(sp)
	var line := ColorRect.new()
	line.color = Color(0.42, 0.44, 0.52, 0.55)
	line.custom_minimum_size = Vector2(0, maxi(1, _s(2)))
	box.add_child(line)
	var lbl := Label.new()
	lbl.text = Loc.t("ach_not_counted")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(22))
	lbl.add_theme_color_override("font_color", Color(0.62, 0.64, 0.72))
	lbl.add_theme_constant_override("outline_size", _s(2))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(lbl)
	return box

func _make_achievement_row(id: String, unlocked: bool) -> Control:
	var color: Color = Ach.get_color(id)
	# Hidden achievements stay a mystery until unlocked: secret icon + "???" + no bar.
	var secret: bool = not unlocked and Ach.is_hidden(id)
	# Show a cumulative progress bar for multi-session achievements while still locked.
	var prog: Dictionary = Ach.get_progress(id)
	var show_bar: bool = not unlocked and not prog.is_empty() and not secret
	# Taller rows: ~4 achievements visible at a time (was ~6).
	var row_h := 184 if show_bar else 148
	var icon_sz := 108

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, _s(row_h))
	var sb := StyleBoxFlat.new()
	if unlocked:
		sb.bg_color = Color(0.12, 0.12, 0.15, 0.9).lerp(color, 0.18)  # light color wash
		sb.border_color = color
	else:
		sb.bg_color = Color(0.10, 0.10, 0.12, 0.85)
		sb.border_color = Color(0.22, 0.22, 0.26)
	sb.set_border_width_all(_s(2))
	sb.set_corner_radius_all(_s(12))
	sb.content_margin_left = 14 * _sf
	sb.content_margin_right = 16 * _sf
	sb.content_margin_top = 10 * _sf
	sb.content_margin_bottom = 10 * _sf
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(16))
	panel.add_child(row)

	# Icon (grayscale + dim when locked)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(_s(icon_sz), _s(icon_sz))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ipath := Ach.SECRET_ICON if secret else Ach.get_icon_path(id)
	if ResourceLoader.exists(ipath):
		icon.texture = load(ipath)
	if not unlocked and not secret:
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = GRAYSCALE_SHADER
		mat.shader = sh
		icon.material = mat
	row.add_child(icon)

	# Name + description
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", _s(2))
	row.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = "???" if secret else Ach.display_name(id)
	if _lilita:
		name_lbl.add_theme_font_override("font", _lilita)
	name_lbl.add_theme_font_size_override("font_size", _s(36))
	name_lbl.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.55, 0.55, 0.60))
	name_lbl.add_theme_constant_override("outline_size", _s(4))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = Loc.t("hidden_achievement") if secret else Ach.get_desc(id)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _lilita:
		desc_lbl.add_theme_font_override("font", _lilita)
	desc_lbl.add_theme_font_size_override("font_size", _s(26))
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.84) if unlocked else Color(0.45, 0.45, 0.5))
	desc_lbl.add_theme_constant_override("outline_size", _s(2))
	desc_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	col.add_child(desc_lbl)

	if show_bar:
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, _s(6))
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sp)
		col.add_child(_make_progress_bar(float(prog.get("ratio", 0.0)), String(prog.get("text", "")), color))

	return panel

## A Steam-style progress bar: a rounded track with a colored fill + "X / Y" text.
func _make_progress_bar(ratio: float, text: String, color: Color) -> Control:
	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", _s(12))

	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, _s(18))
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.05, 0.05, 0.07, 0.95)
	tsb.border_color = Color(0.26, 0.26, 0.30)
	tsb.set_border_width_all(maxi(1, _s(1)))
	tsb.set_corner_radius_all(_s(7))
	track.add_theme_stylebox_override("panel", tsb)

	var fill := Panel.new()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_left = _s(2)
	fill.offset_top = _s(2)
	fill.offset_bottom = -_s(2)
	fill.offset_right = 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = color
	fsb.set_corner_radius_all(_s(5))
	fill.add_theme_stylebox_override("panel", fsb)
	track.add_child(fill)

	var txt := Label.new()
	txt.text = text
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.custom_minimum_size = Vector2(_s(150), 0)
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _lilita:
		txt.add_theme_font_override("font", _lilita)
	txt.add_theme_font_size_override("font_size", _s(18))
	txt.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))
	txt.add_theme_constant_override("outline_size", _s(2))
	txt.add_theme_color_override("font_outline_color", Color.BLACK)

	bar.add_child(track)
	bar.add_child(txt)
	return bar

# ============================================================
# FORMATTING HELPERS
# ============================================================

func _format_int(value) -> String:
	var n := int(value)
	if n < 1000:
		return str(n)
	elif n < 1000000:
		# 1k, 12.5k, 999.9k
		var k := n / 1000.0
		if k >= 100.0:
			return "%dk" % int(k)
		elif k >= 10.0:
			return "%.1fk" % k if fmod(k, 1.0) >= 0.05 else "%dk" % int(k)
		else:
			return "%.1fk" % k if fmod(k, 1.0) >= 0.05 else "%dk" % int(k)
	else:
		# 1m, 12.5m
		var m := n / 1000000.0
		return "%.1fm" % m if fmod(m, 1.0) >= 0.05 else "%dm" % int(m)

func _format_time(seconds: float) -> String:
	## Format as M:SS.MS (e.g., 2:34.56)
	if seconds <= 0.0:
		return "0:00.00"
	@warning_ignore("integer_division")
	var mins := int(seconds) / 60
	@warning_ignore("integer_division")
	var secs := int(seconds) % 60
	var ms := int(fmod(seconds, 1.0) * 100)
	return "%d:%02d.%02d" % [mins, secs, ms]

func _format_duration(seconds: float) -> String:
	## Format as Xh Ym or Ym Zs for longer/shorter durations
	if seconds <= 0.0:
		return "0s"
	var total_secs := int(seconds)
	@warning_ignore("integer_division")
	var hours := total_secs / 3600
	@warning_ignore("integer_division")
	var mins := (total_secs % 3600) / 60
	@warning_ignore("integer_division")
	var secs := total_secs % 60
	if hours > 0:
		return "%dh %dm" % [hours, mins]
	elif mins > 0:
		return "%dm %ds" % [mins, secs]
	else:
		return "%ds" % secs

# ============================================================
# STYLING
# ============================================================

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
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 16.0, 10.0)

# ============================================================
# CALLBACKS
# ============================================================

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _on_close() -> void:
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _panel, func() -> void:
		visible = false
		closed.emit())

# ============================================================
# PUBLIC API
# ============================================================

func show_popup() -> void:
	_rebuild_stats_content()
	_rebuild_achievements_content()
	_set_active_tab(true)
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)

func hide_popup() -> void:
	visible = false
