class_name DeathScreen
extends CanvasLayer
## Game Over overlay for endless mode.
## Shows survival time, best time, RETRY and MENU buttons.
## Uses same visual style as main menu buttons.

signal retry_pressed
signal menu_pressed
signal next_level_pressed

const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

# ============================================================
# COLORS (match main_menu.gd style)
# ============================================================
const OVERLAY_COLOR := Color(0, 0, 0, 0.7)

const PLAY_NORMAL := Color(0.18, 0.56, 0.18)
const PLAY_HOVER := Color(0.24, 0.66, 0.24)
const PLAY_PRESSED := Color(0.14, 0.46, 0.14)
const PLAY_BORDER := Color(0.92, 0.92, 0.92)

const SEC_NORMAL := Color(0.08, 0.12, 0.28, 0.92)
const SEC_HOVER := Color(0.12, 0.18, 0.38, 0.92)
const SEC_PRESSED := Color(0.05, 0.08, 0.20, 0.92)
const SEC_BORDER := Color(0.18, 0.28, 0.52)

# Retry button (yellow) — distinct from the green NEXT LEVEL button.
const RETRY_NORMAL := Color(0.85, 0.66, 0.10)
const RETRY_HOVER := Color(0.95, 0.76, 0.18)
const RETRY_PRESSED := Color(0.70, 0.54, 0.06)
const RETRY_BORDER := Color(0.98, 0.92, 0.65)

# ============================================================
# LAYOUT — design values for 1920x1080 (scaled at runtime via _sf)
# ============================================================
const BTN_WIDTH := 440
const BTN_HEIGHT := 100
const BTN_FONT_SIZE := 56
const BTN_CORNER := 20
const BTN_BORDER_W := 4
const BTN_GAP := 40

# Sizes tuned ~1.18x vs the original Lilita values: Baloo 2's cap height is ~0.60em
# (Lilita was ~0.70em), so the same font_size rendered noticeably smaller.
const TITLE_FONT_SIZE := 84
const TIME_FONT_SIZE := 66
const LABEL_FONT_SIZE := 38
const BEST_FONT_SIZE := 31
const NEW_BEST_FONT_SIZE := 40

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
var _next_btn: Button          ## green "NEXT LEVEL" — only on a numbered-level win
var _next_row: HBoxContainer
var _next_spacer: Control
var _retry_btn: Button
var _menu_btn: Button
var _title_label: Label
var _star_row: HBoxContainer   ## challenge stars (bronze/silver/gold), built on demand
var _star_info_label: Label    ## yellow star-thresholds line (challenges), built on demand
var _ch_score_label: Label     ## challenge: this run's score (green on a new record)
var _ch_record_label: Label    ## challenge: record line — grey, or green "NEW BEST" 
var _time_label: Label
var _time_desc_label: Label
var _best_label: Label         ## Shows best time or "NEW PERSONAL BEST!"
var _kills_desc_label: Label
var _kills_label: Label
var _content: VBoxContainer

var _lilita: Font
var _is_transitioning: bool = false

func _ready() -> void:
	layer = 50  # Above HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf(vp)
	_load_font()
	_build_overlay()
	_build_content()
	visible = false

func _load_font() -> void:
	_lilita = UIT.load_font()

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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 0)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_content)

	# ---- GAME OVER title ----
	_title_label = Label.new()
	_title_label.text = Loc.t("game_over")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_title_label.add_theme_font_override("font", _lilita)
	_title_label.add_theme_font_size_override("font_size", _s(TITLE_FONT_SIZE))
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_title_label.add_theme_constant_override("outline_size", _s(6))
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_title_label)

	# ---- Spacer ----
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 30 * _sf)
	_content.add_child(sp1)

	# ---- "Survival time" label ----
	_time_desc_label = Label.new()
	_time_desc_label.text = Loc.t("survival_time")
	_time_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_time_desc_label.add_theme_font_override("font", _lilita)
	_time_desc_label.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	_time_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_time_desc_label.add_theme_constant_override("outline_size", _s(3))
	_time_desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_time_desc_label)

	# ---- Spacer ----
	var sp1b := Control.new()
	sp1b.custom_minimum_size = Vector2(0, 6 * _sf)
	_content.add_child(sp1b)

	# ---- Time display ----
	_time_label = Label.new()
	_time_label.text = "0:00.00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_time_label.add_theme_font_override("font", _lilita)
	_time_label.add_theme_font_size_override("font_size", _s(TIME_FONT_SIZE))
	_time_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_time_label.add_theme_constant_override("outline_size", _s(5))
	_time_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_time_label)

	# ---- Best time / new personal best label (below current time) ----
	_best_label = Label.new()
	_best_label.text = ""
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_best_label.add_theme_font_override("font", _lilita)
	_best_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE))
	_best_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_best_label.add_theme_constant_override("outline_size", _s(3))
	_best_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_best_label)

	# ---- Spacer ----
	var sp_kills := Control.new()
	sp_kills.custom_minimum_size = Vector2(0, 20 * _sf)
	_content.add_child(sp_kills)

	# ---- "Monsters killed" label ----
	_kills_desc_label = Label.new()
	_kills_desc_label.text = Loc.t("monsters_killed")
	_kills_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_kills_desc_label.add_theme_font_override("font", _lilita)
	_kills_desc_label.add_theme_font_size_override("font_size", _s(LABEL_FONT_SIZE))
	_kills_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_kills_desc_label.add_theme_constant_override("outline_size", _s(3))
	_kills_desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_kills_desc_label)

	# ---- Spacer ----
	var sp_kills2 := Control.new()
	sp_kills2.custom_minimum_size = Vector2(0, 6 * _sf)
	_content.add_child(sp_kills2)

	# ---- Kill count ----
	_kills_label = Label.new()
	_kills_label.text = "0"
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		_kills_label.add_theme_font_override("font", _lilita)
	_kills_label.add_theme_font_size_override("font_size", _s(TIME_FONT_SIZE))
	_kills_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	_kills_label.add_theme_constant_override("outline_size", _s(5))
	_kills_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content.add_child(_kills_label)

	# ---- Spacer before buttons ----
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 42 * _sf)
	_content.add_child(sp2)

	# ---- NEXT LEVEL row (green, prominent — only shown on a numbered-level win) ----
	_next_row = HBoxContainer.new()
	_next_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_next_row)

	_next_btn = Button.new()
	_next_btn.name = "NextLevelButton"
	_next_btn.text = Loc.t("next_level")
	_next_btn.custom_minimum_size = Vector2((BTN_WIDTH + 80) * _sf, BTN_HEIGHT * _sf)
	_style_primary(_next_btn)
	_next_btn.pressed.connect(_on_next)
	_next_row.add_child(_next_btn)

	_next_spacer = Control.new()
	_next_spacer.custom_minimum_size = Vector2(0, BTN_GAP * _sf)
	_content.add_child(_next_spacer)

	_next_row.visible = false
	_next_spacer.visible = false

	# ---- Buttons row ----
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", _s(BTN_GAP))
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(btn_row)

	# RETRY button (green)
	_retry_btn = Button.new()
	_retry_btn.name = "RetryButton"
	_retry_btn.text = Loc.t("retry")
	_retry_btn.custom_minimum_size = Vector2(BTN_WIDTH * _sf, BTN_HEIGHT * _sf)
	_style_retry(_retry_btn)
	_retry_btn.pressed.connect(_on_retry)
	btn_row.add_child(_retry_btn)

	# MENU button (dark blue)
	_menu_btn = Button.new()
	_menu_btn.name = "MenuButton"
	_menu_btn.text = Loc.t("menu")
	_menu_btn.custom_minimum_size = Vector2(BTN_WIDTH * _sf, BTN_HEIGHT * _sf)
	_style_secondary(_menu_btn)
	_menu_btn.pressed.connect(_on_menu)
	btn_row.add_child(_menu_btn)

# ============================================================
# STYLING
# ============================================================

func _style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(PLAY_NORMAL, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(PLAY_HOVER, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(PLAY_PRESSED, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(PLAY_NORMAL, PLAY_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _style_retry(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(RETRY_NORMAL, RETRY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(RETRY_HOVER, RETRY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(RETRY_PRESSED, RETRY_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(RETRY_NORMAL, RETRY_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _style_secondary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(SEC_NORMAL, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_sb(SEC_HOVER, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_sb(SEC_PRESSED, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_sb(SEC_NORMAL, SEC_BORDER, BTN_CORNER, BTN_BORDER_W))
	_apply_btn_font(btn)

func _apply_btn_font(btn: Button) -> void:
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(BTN_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_constant_override("outline_size", _s(5))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

func _make_sb(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 24.0, 14.0)

# ============================================================
# PUBLIC API
# ============================================================

func show_death_screen(elapsed_time: float, kills: int = 0, best_time: float = 0.0, is_new_best: bool = false) -> void:
	_set_next_visible(false)
	# Reset title to "Game Over" (it may have been switched to victory by show_victory).
	_title_label.text = Loc.t("game_over")
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	# Re-show the time/kills rows (a challenge result may have hidden them).
	_time_desc_label.visible = true
	_time_label.visible = true
	_kills_desc_label.visible = true
	_kills_label.visible = true
	_best_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if _star_row:
		_star_row.visible = false
	if _star_info_label:
		_star_info_label.visible = false
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	var ms := int(fmod(elapsed_time, 1.0) * 100)
	_time_label.text = "%d:%02d.%02d" % [minutes, seconds, ms]
	_kills_label.text = str(kills)

	# Best time display
	if is_new_best:
		_best_label.text = Loc.t("new_best")
		_best_label.add_theme_font_size_override("font_size", _s(NEW_BEST_FONT_SIZE))
		_best_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		var b_min := int(best_time) / 60
		var b_sec := int(best_time) % 60
		var b_ms := int(fmod(best_time, 1.0) * 100)
		_best_label.text = Loc.t("best") + ": %d:%02d.%02d" % [b_min, b_sec, b_ms]
		_best_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE))
		_best_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	visible = true
	_is_transitioning = false

	# Animate in
	_overlay.color.a = 0.0
	_content.scale = Vector2(0.8, 0.8)
	_content.pivot_offset = _content.size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.7, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(_content, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Victory variant — shown when a custom level/challenge is completed.
func show_victory(p_level_name: String, elapsed_time: float, kills: int = 0) -> void:
	_set_next_visible(false)
	_title_label.text = Loc.t("level_complete")
	_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	var ms := int(fmod(elapsed_time, 1.0) * 100)
	_time_label.text = "%d:%02d.%02d" % [minutes, seconds, ms]
	_kills_label.text = str(kills)
	_best_label.text = p_level_name
	_best_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE))
	_best_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	visible = true
	_is_transitioning = false
	_overlay.color.a = 0.0
	_content.scale = Vector2(0.8, 0.8)
	_content.pivot_offset = _content.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.7, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(_content, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Challenge result variant — no time/kills; SPLNĚNA / NESPLNĚNA + earned stars
## (bronze/silver/gold, empty placeholders) + the challenge description.
## Buttons (retry / menu) are unchanged. stars: 0-3, or -1 to hide the star row.
func show_challenge_result(success: bool, p_name: String, p_desc: String, stars: int = -1, show_next: bool = false, final_time: float = -1.0, is_record: bool = false, p_score_field: String = "", p_score_value: float = 0.0, p_best_value: float = 0.0, p_score_is_record: bool = false) -> void:
	_set_next_visible(show_next)
	_title_label.text = Loc.t("challenge_done") if success else Loc.t("challenge_failed")
	_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if success else Color(1.0, 0.3, 0.25))
	# Hide the time + kills rows (challenges don't use them).
	_time_desc_label.visible = false
	_time_label.visible = false
	_kills_desc_label.visible = false
	_kills_label.visible = false
	# Numbered levels: completion time counts up 0:00.00 → final over 1 s.
	# GREEN when it's a new record, white otherwise.
	if final_time >= 0.0:
		_time_label.visible = true
		_time_label.add_theme_color_override("font_color",
			Color(0.35, 1.0, 0.45) if is_record else Color.WHITE)
		_time_label.text = "0:00.00"
		var ttw := create_tween()
		ttw.tween_method(_set_countup_time, 0.0, final_time, 1.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_star_row(stars)
	# Reuse the bottom label for the challenge name + description. The star-threshold
	# part (from the first "★") moves to its own YELLOW line below.
	var desc_main := p_desc
	var star_info := ""
	var star_idx := p_desc.find("★")
	if star_idx >= 0:
		desc_main = p_desc.substr(0, star_idx).strip_edges()
		star_info = p_desc.substr(star_idx).strip_edges()
	_best_label.visible = true
	_best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_best_label.custom_minimum_size = Vector2(620 * _sf, 0)
	_best_label.text = p_name if desc_main == "" else (p_name + "\n" + desc_main)
	_best_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE))
	_best_label.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	_update_star_info_label(star_info)
	_update_challenge_score(p_score_field, p_score_value, p_best_value, p_score_is_record)
	visible = true
	_is_transitioning = false
	_overlay.color.a = 0.0
	_content.scale = Vector2(0.8, 0.8)
	_content.pivot_offset = _content.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.7, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(_content, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Count-up animation tick: format the animated time into the big time label.
func _set_countup_time(t: float) -> void:
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var ms := clampi(roundi((t - int(t)) * 100.0), 0, 99)
	_time_label.text = "%d:%02d.%02d" % [minutes, seconds, ms]

## Yellow line with the star thresholds ("★ 100 · ★★ 200 · ★★★ 350 …"), shown under
## the challenge description. Hidden when empty.
func _update_star_info_label(text: String) -> void:
	if _star_info_label == null:
		_star_info_label = Label.new()
		_star_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_star_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_star_info_label.custom_minimum_size = Vector2(620 * _sf, 0)
		if _lilita:
			_star_info_label.add_theme_font_override("font", _lilita)
		_star_info_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE))
		_star_info_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_star_info_label.add_theme_constant_override("outline_size", _s(3))
		_star_info_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_star_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_star_info_label)
		_content.move_child(_star_info_label, _best_label.get_index() + 1)
	_star_info_label.text = text
	_star_info_label.visible = text != ""

## Format a challenge score value for its field: "time" = m:ss.cc, else "LABEL: n".
func _fmt_ch_score(field: String, v: float) -> String:
	if field == "time":
		var m := int(v) / 60
		var sec := int(v) % 60
		var cs := int(fmod(v, 1.0) * 100)
		return "%d:%02d.%02d" % [m, sec, cs]
	elif field == "kills":
		return "%s: %d" % [Loc.t("kills_hud"), int(v)]
	elif field == "targets":
		return "%s: %d" % [Loc.t("totems_hud"), int(v)]
	return "%d" % int(v)

## Value-only format for the record line (no "TOTEMY/ZABITÍ" label — the score line above
## already carries it): time = m:ss.cc, else a plain integer.
func _fmt_ch_value(field: String, v: float) -> String:
	if field == "time":
		var m := int(v) / 60
		var sec := int(v) % 60
		var cs := int(fmod(v, 1.0) * 100)
		return "%d:%02d.%02d" % [m, sec, cs]
	return "%d" % int(v)

## Challenge result: this run's score + the record. Score is GREEN on a new record (and
## the record line becomes "NEW PERSONAL BEST!"), otherwise the record shows grey — same
## as the endless game-over screen. Built on demand, placed under the star-thresholds line.
func _update_challenge_score(field: String, value: float, best: float, is_record: bool) -> void:
	if _ch_score_label == null:
		_ch_score_label = Label.new()
		_ch_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _lilita:
			_ch_score_label.add_theme_font_override("font", _lilita)
		_ch_score_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE + 6))
		_ch_score_label.add_theme_constant_override("outline_size", _s(4))
		_ch_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_ch_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_ch_score_label)
		_ch_record_label = Label.new()
		_ch_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _lilita:
			_ch_record_label.add_theme_font_override("font", _lilita)
		_ch_record_label.add_theme_font_size_override("font_size", _s(BEST_FONT_SIZE))
		_ch_record_label.add_theme_constant_override("outline_size", _s(3))
		_ch_record_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_ch_record_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_ch_record_label)
	# Keep both lines directly under the yellow star-thresholds line.
	if _star_info_label:
		_content.move_child(_ch_score_label, _star_info_label.get_index() + 1)
		_content.move_child(_ch_record_label, _ch_score_label.get_index() + 1)
	if field == "":
		_ch_score_label.visible = false
		_ch_record_label.visible = false
		return
	_ch_score_label.visible = true
	_ch_record_label.visible = true
	_ch_score_label.text = _fmt_ch_score(field, value)
	_ch_score_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45) if is_record else Color.WHITE)
	if is_record:
		_ch_record_label.text = Loc.t("new_best")
		_ch_record_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		_ch_record_label.text = "%s: %s" % [Loc.t("record"), _fmt_ch_value(field, best)]
		_ch_record_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

## Build/refresh the 3-slot star row (bronze, silver, gold — empty star when not earned).
## stars: 0-3 shows the row; -1 hides it.
func _update_star_row(stars: int) -> void:
	if _star_row == null:
		_star_row = HBoxContainer.new()
		_star_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_star_row.add_theme_constant_override("separation", _s(18))
		_star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_star_row)
		_content.move_child(_star_row, _best_label.get_index())  # above the name/desc label
	for c in _star_row.get_children():
		c.queue_free()
	_star_row.visible = stars >= 0
	if stars < 0:
		return
	var files := ["bronzestar", "silverstar", "goldstar"]
	for i in 3:
		var tex := TextureRect.new()
		var earned: bool = stars > i
		var fname: String = files[i] if earned else "emptystar"
		var path := "res://assets/sprites/ui/challenges/%s.svg" % fname
		if ResourceLoader.exists(path):
			tex.texture = load(path)
		tex.custom_minimum_size = Vector2(_s(92), _s(92))
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_star_row.add_child(tex)
		# Earned stars pop in one after another (scale 0 → 1 with a bounce + a click).
		if earned:
			tex.pivot_offset = Vector2(_s(92), _s(92)) * 0.5
			tex.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_interval(0.25 + 0.18 * i)
			# (No per-star sound — the win cue plays when the player falls into the exit
			# portal, see game_world._on_level_won.)
			tw.tween_property(tex, "scale", Vector2.ONE, 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Toggle the green NEXT LEVEL button + its spacer (only a numbered-level win shows it).
func _set_next_visible(show: bool) -> void:
	if _next_row:
		_next_row.visible = show
	if _next_spacer:
		_next_spacer.visible = show

func hide_death_screen() -> void:
	visible = false

# ============================================================
# ACTIONS
# ============================================================

func _on_retry() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	AudioManager.play_sfx("button_click_menu")
	retry_pressed.emit()

func _on_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	AudioManager.play_sfx("button_click_menu")
	menu_pressed.emit()

func _on_next() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	AudioManager.play_sfx("button_click_menu")
	next_level_pressed.emit()
