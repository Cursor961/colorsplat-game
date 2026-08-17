class_name DailyPopup
extends CanvasLayer
## Daily Reward / lucky box. One free open per 24h (wall-clock, counts offline);
## otherwise "open for ad" (testing: instant). Opening rolls a random skin OR trail
## (equal chance, all but default/none), grants it + resets the timer IMMEDIATELY
## (so quitting mid-animation can't lose the reward), then plays a CS2-style spin.
## Result screen offers Close (back to the box + countdown) or Go to Skins.

signal open_skins_requested(category: String)

const SkinMeta := preload("res://scripts/data/skin_data.gd")
const TrailMeta := preload("res://scripts/data/trail_data.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const Anim := preload("res://scripts/utils/popup_anim.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")
const CRATE_TEX := "res://assets/sprites/lootcrate/crate.svg"

# ---- COLORS ----
const OVERLAY_COLOR := Color(0, 0, 0, 0.78)
const PANEL_COLOR := Color(0.10, 0.09, 0.08, 0.98)
const PANEL_BORDER := Color(0.55, 0.40, 0.15)
const OPEN_NORMAL := Color(0.20, 0.62, 0.20)
const OPEN_HOVER := Color(0.26, 0.72, 0.26)
const OPEN_PRESSED := Color(0.15, 0.50, 0.15)
const AD_NORMAL := Color(0.55, 0.40, 0.12)
const AD_HOVER := Color(0.66, 0.48, 0.16)
const AD_PRESSED := Color(0.45, 0.32, 0.10)
const SEC_NORMAL := Color(0.16, 0.18, 0.30)
const GLOW := Color(1.0, 0.7, 0.15)
const MARKER := Color(1.0, 0.85, 0.2)

# ---- LAYOUT (design 1920x1080) ----
const PANEL_W := 1040
const PANEL_H := 660
const TITLE_FONT := 60
const DESC_FONT := 30
const BTN_W := 460
const BTN_H := 112
const BTN_FONT := 46
const BOX_IMG := 300
const TIMER_FONT := 38
const SPIN_W := 940
const SPIN_H := 220
const ITEM_W := 210
const ITEM_BOX := 188
const RESULT_NAME := 54
const RESULT_DESC := 30
const SEC_BTN_W := 360
const SEC_BTN_H := 92

# ---- SPIN ----
const STRIP_LEN := 50
const WIN_INDEX := 45
const SPIN_TIME := 4.6          ## total spin duration (s) — fast QUINT ease-out
# Clicks are time-scheduled (not tied to item crossings): the gap between clicks grows
# with progress, so it is monotonically increasing by construction — one smooth slow-down
# with no audible speed-up. Clicks stop the moment the winner is centered.
const TICK_GAP_START := 0.06    ## seconds between clicks at the fast start (denser opening)
const TICK_GAP_END := 0.50      ## seconds between clicks just before the winner lands
const TICK_GAP_RAMP := 0.60     ## spin progress (0-1) at which the gap reaches TICK_GAP_END
const TICK_VOL_START := 0.4     ## click volume while clicks are dense (fast opening)
const TICK_VOL_END := 1.0       ## click volume once clicks space out
const TICK_VOL_RAMP := 0.45     ## spin progress (0-1) at which volume reaches TICK_VOL_END
const TICK_FINAL_VOL := 0.4     ## soft final click the moment the winner locks into center

var _sf: float = 1.0
func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

var _lilita: Font
var _overlay: ColorRect
var _panel: Panel
var _close_x_btn: Button   ## hidden while the box is opening (zoom + spin)
var _reward_box: Control
var _spin_box: Control
var _result_box: Control

# reward widgets
var _box_img: TextureRect
var _box_holder: Control   ## zoomed on open
var _box_pulse: Tween      ## idle pulse (killed during zoom)
var _reward_title: Label   ## fades out on open to make room for the zoom
var _reward_desc: Label    ## fades out on open
var _all_owned: bool = false  ## true when every obtainable item is owned (free fun-spin mode)
var _open_btn: Button
var _support_btn: Button   ## optional "support the author" ad button — only shown when all owned
var _timer_label: Label

# spin widgets
var _spin_window: Control
var _strip: Control

# result widgets
var _result_tex: TextureRect
var _result_name: Label
var _result_desc: Label
var _result_panel: Panel   ## blinks on reveal
var _result_glow: ColorRect

var _won: Dictionary = {}
var _won_was_new: bool = false
var _state: String = "reward"
var _spin_tween: Tween
var _spin_elapsed: float = 0.0       ## time since spin started
var _next_tick_at: float = 0.0       ## _spin_elapsed at which the next click fires
var _spin_done_ticking: bool = false ## set once the winner is centered (stops clicks)

func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_panel(vp, Vector2(PANEL_W, PANEL_H))
	_lilita = UIT.load_font()
	_build()
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	if _state == "spin":
		_spin_elapsed += delta
		_update_spin_wave()
		# Position is driven by the tween (_start_spin); here we only emit the tick sfx.
		if _spin_done_ticking:
			return
		# When the winner reaches center, emit one soft final "lock" click and stop
		# (no clicks during the settle tail afterwards).
		var iw := ITEM_W * _sf
		if iw > 0.0:
			var centered := int(round((SPIN_W * _sf * 0.5 - _strip.position.x - iw * 0.5) / iw))
			if centered >= WIN_INDEX:
				AudioManager.play_sfx("box_tick", TICK_FINAL_VOL)
				_spin_done_ticking = true
				return
		# Regular ramped clicks until then: gap grows with progress => each successive
		# gap >= the previous (monotonic), volume ramps up smoothly.
		var u := clampf(_spin_elapsed / SPIN_TIME, 0.0, 1.0)
		if _spin_elapsed >= _next_tick_at:
			var vol := lerpf(TICK_VOL_START, TICK_VOL_END, clampf(u / TICK_VOL_RAMP, 0.0, 1.0))
			AudioManager.play_sfx("box_tick", vol)
			var gap := lerpf(TICK_GAP_START, TICK_GAP_END, clampf(u / TICK_GAP_RAMP, 0.0, 1.0))
			_next_tick_at = _spin_elapsed + gap
		return
	if _state == "reward" and _timer_label and _timer_label.visible:
		if SaveManager.can_open_box_free():
			_refresh_reward()  # cooldown just ended — switch to the free OPEN button
		else:
			_timer_label.text = "%s  %s" % [Loc.t("box_next_free"), _format_hms(SaveManager.seconds_until_free_box())]

## Wave effect while the strip spins: the cell under the center marker scales up,
## falling smoothly back to 1.0 toward its neighbours.
func _update_spin_wave() -> void:
	if _strip == null:
		return
	var iw := ITEM_W * _sf
	if iw <= 0.0:
		return
	var center_x := SPIN_W * _sf * 0.5
	for c in _strip.get_children():
		if not c is Control:
			continue
		var cell := c as Control
		var cell_center := _strip.position.x + cell.position.x + iw * 0.5
		# 1.0 under the marker → 0.0 one-and-a-bit cells away.
		var t := clampf(1.0 - absf(cell_center - center_x) / (iw * 1.25), 0.0, 1.0)
		var s := 1.0 + 0.16 * t
		cell.pivot_offset = cell.size * 0.5
		cell.scale = Vector2(s, s)
		cell.z_index = int(t * 10.0)   # the popped cell draws above its neighbours

# ============================================================
# BUILD
# ============================================================

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(e: InputEvent) -> void:
		# Tap outside closes only on the reward/result screens (not mid-spin).
		if e is InputEventMouseButton and e.pressed and _state != "spin":
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

	_build_reward()
	_build_spin()
	_build_result()
	_build_close_x()
	_set_state("reward")

## Dark-grey "X" close button pinned to the panel's top-right corner.
func _build_close_x() -> void:
	var btn := Button.new()
	btn.text = "✕"
	btn.focus_mode = Control.FOCUS_NONE
	var sz := _s(64)
	var margin := _s(16)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left = -sz - margin
	btn.offset_right = -margin
	btn.offset_top = margin
	btn.offset_bottom = sz + margin
	# No background / frame — just the clickable "X" glyph (the whole rect stays clickable).
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
	btn.add_theme_color_override("font_pressed_color", Color(0.45, 0.45, 0.50))
	btn.add_theme_constant_override("outline_size", _s(2))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	btn.pressed.connect(_close)
	_close_x_btn = btn
	_panel.add_child(btn)

func _full(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

# ---- Reward screen (box + open) ----
func _build_reward() -> void:
	_reward_box = _full(_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = maxf(44 * _sf, 10.0)
	vb.offset_right = -maxf(44 * _sf, 10.0)
	vb.offset_top = 36 * _sf
	vb.offset_bottom = -36 * _sf
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", _s(22))
	_reward_box.add_child(vb)

	var title := Label.new()
	_reward_title = title
	title.text = Loc.t("daily_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(title, TITLE_FONT, Color.WHITE, 6)
	vb.add_child(title)

	# Crate image with a soft glow behind it
	var img_row := CenterContainer.new()
	img_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(img_row)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(_s(BOX_IMG), _s(BOX_IMG))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_row.add_child(holder)
	_box_holder = holder
	var glow := ColorRect.new()
	glow.color = Color(GLOW.r, GLOW.g, GLOW.b, 0.18)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	_box_img = TextureRect.new()
	_box_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_box_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_box_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(CRATE_TEX):
		_box_img.texture = load(CRATE_TEX)
	holder.add_child(_box_img)
	# gentle idle pulse (recreated when re-entering the reward state)
	holder.pivot_offset = Vector2(_s(BOX_IMG) * 0.5, _s(BOX_IMG) * 0.5)
	_start_box_pulse()

	var desc := Label.new()
	_reward_desc = desc
	desc.text = Loc.t("daily_desc")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font(desc, DESC_FONT, Color(0.85, 0.85, 0.88), 4)
	vb.add_child(desc)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_timer_label, TIMER_FONT, Color(0.95, 0.8, 0.4), 4)
	vb.add_child(_timer_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", _s(20))
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(btn_row)
	_open_btn = Button.new()
	_open_btn.custom_minimum_size = Vector2(BTN_W * _sf, BTN_H * _sf)
	_open_btn.pressed.connect(_on_open_pressed)
	btn_row.add_child(_open_btn)
	# Optional "support the author" ad button — only visible once everything is owned.
	_support_btn = Button.new()
	_support_btn.custom_minimum_size = Vector2(BTN_W * _sf, BTN_H * _sf)
	_support_btn.pressed.connect(_on_support_pressed)
	_support_btn.visible = false
	btn_row.add_child(_support_btn)

func _build_spin() -> void:
	_spin_box = _full(_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", _s(20))
	_spin_box.add_child(vb)

	var lbl := Label.new()
	lbl.text = Loc.t("daily_title")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(lbl, TITLE_FONT, Color.WHITE, 6)
	vb.add_child(lbl)

	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)

	_spin_window = Control.new()
	_spin_window.custom_minimum_size = Vector2(SPIN_W * _sf, SPIN_H * _sf)
	_spin_window.clip_contents = true
	_spin_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# window background
	var wbg := ColorRect.new()
	wbg.color = Color(0.05, 0.05, 0.06, 0.9)
	wbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	wbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin_window.add_child(wbg)
	row.add_child(_spin_window)

	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin_window.add_child(_strip)

	# Center marker line — always ON TOP of the items (the wave-scaled cell uses
	# z_index up to 10, so the marker sits above that).
	var marker := ColorRect.new()
	marker.color = MARKER
	marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker.anchor_left = 0.5
	marker.anchor_right = 0.5
	marker.offset_left = -_s(3)
	marker.offset_right = _s(3)
	marker.z_index = 20
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin_window.add_child(marker)

func _build_result() -> void:
	_result_box = _full(_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = maxf(44 * _sf, 10.0)
	vb.offset_right = -maxf(44 * _sf, 10.0)
	vb.offset_top = 36 * _sf
	vb.offset_bottom = -36 * _sf
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", _s(20))
	_result_box.add_child(vb)

	var hdr := Label.new()
	hdr.text = Loc.t("box_you_won")
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(hdr, DESC_FONT, Color(0.95, 0.8, 0.4), 4)
	vb.add_child(hdr)

	var prow := CenterContainer.new()
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(prow)
	var pholder := Panel.new()
	_result_panel = pholder
	pholder.custom_minimum_size = Vector2(_s(280), _s(280))
	# Glow behind the won item — blinks on reveal.
	_result_glow = ColorRect.new()
	_result_glow.color = Color(GLOW.r, GLOW.g, GLOW.b, 0.0)
	_result_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_glow.offset_left = -_s(22); _result_glow.offset_right = _s(22)
	_result_glow.offset_top = -_s(22); _result_glow.offset_bottom = _s(22)
	_result_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pholder.add_child(_result_glow)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.07, 0.07, 0.09, 0.9)
	pst.border_color = GLOW
	pst.set_border_width_all(_s(3))
	pst.set_corner_radius_all(_s(16))
	pholder.add_theme_stylebox_override("panel", pst)
	prow.add_child(pholder)
	_result_tex = TextureRect.new()
	_result_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_tex.offset_left = _s(24); _result_tex.offset_right = -_s(24)
	_result_tex.offset_top = _s(24); _result_tex.offset_bottom = -_s(24)
	_result_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pholder.add_child(_result_tex)

	_result_name = Label.new()
	_result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_result_name, RESULT_NAME, Color.WHITE, 5)
	vb.add_child(_result_name)

	_result_desc = Label.new()
	_result_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font(_result_desc, RESULT_DESC, Color(0.82, 0.82, 0.86), 3)
	vb.add_child(_result_desc)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", _s(20))
	btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(btns)

	var close_btn := Button.new()
	close_btn.text = Loc.t("close")
	close_btn.custom_minimum_size = Vector2(SEC_BTN_W * _sf, SEC_BTN_H * _sf)
	_style_btn(close_btn, SEC_NORMAL, SEC_NORMAL.lightened(0.1), SEC_NORMAL.darkened(0.1))
	_font(close_btn, BTN_FONT - 6, Color.WHITE, 5)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_set_state("reward"))
	btns.add_child(close_btn)

	var skins_btn := Button.new()
	skins_btn.text = Loc.t("go_to_skins")
	skins_btn.custom_minimum_size = Vector2(SEC_BTN_W * _sf, SEC_BTN_H * _sf)
	_style_btn(skins_btn, OPEN_NORMAL, OPEN_HOVER, OPEN_PRESSED)
	_font(skins_btn, BTN_FONT - 6, Color.WHITE, 5)
	skins_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		var cat: String = "trails" if _won.get("kind", "skin") == "trail" else "skins"
		visible = false
		open_skins_requested.emit(cat))
	btns.add_child(skins_btn)

# ============================================================
# STATE
# ============================================================

func _set_state(s: String) -> void:
	_state = s
	# The box image stays on screen through the "zoom" phase before the spin.
	if _reward_box: _reward_box.visible = (s == "reward" or s == "zoom")
	if _spin_box: _spin_box.visible = (s == "spin")
	if _result_box: _result_box.visible = (s == "result")
	# Hide the close X while the box is opening so the player can't bail mid-animation.
	if _close_x_btn: _close_x_btn.visible = (s != "zoom" and s != "spin")
	if s == "reward":
		_refresh_reward()

func _start_box_pulse() -> void:
	if not _box_holder:
		return
	_box_holder.scale = Vector2.ONE
	if _box_pulse and _box_pulse.is_valid():
		_box_pulse.kill()
	_box_pulse = _box_holder.create_tween().set_loops()
	_box_pulse.tween_property(_box_holder, "scale", Vector2(1.04, 1.04), 1.1).set_trans(Tween.TRANS_SINE)
	_box_pulse.tween_property(_box_holder, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_SINE)

func _refresh_reward() -> void:
	# Re-arm the box after a previous open (Close from result -> reopen).
	for c: CanvasItem in [_reward_title, _reward_desc, _timer_label, _open_btn, _support_btn]:
		if c:
			c.modulate.a = 1.0
	if _open_btn:
		_open_btn.disabled = false
	_start_box_pulse()
	# Everything obtainable owned → spinning still works (free, for fun, gives a duplicate),
	# with an optional "support the author" ad button beside the spin button.
	if _build_pool().is_empty():
		_all_owned = true
		_timer_label.visible = false
		_reward_title.text = Loc.t("box_all_title")
		_reward_desc.text = Loc.t("box_all_desc")
		_open_btn.text = Loc.t("box_spin_fun")
		_open_btn.custom_minimum_size = Vector2(450 * _sf, BTN_H * _sf)
		_style_btn(_open_btn, OPEN_NORMAL, OPEN_HOVER, OPEN_PRESSED)
		_font(_open_btn, BTN_FONT - 10, Color.WHITE, 6)
		_support_btn.visible = true
		_support_btn.disabled = false
		_support_btn.text = Loc.t("box_support_ad")
		_support_btn.custom_minimum_size = Vector2(450 * _sf, BTN_H * _sf)
		_style_btn(_support_btn, AD_NORMAL, AD_HOVER, AD_PRESSED)
		_font(_support_btn, BTN_FONT - 10, Color.WHITE, 6)
		return
	_all_owned = false
	_support_btn.visible = false
	_reward_title.text = Loc.t("daily_title")
	_reward_desc.text = Loc.t("daily_desc")
	_open_btn.custom_minimum_size = Vector2(BTN_W * _sf, BTN_H * _sf)
	var free := SaveManager.can_open_box_free()
	if free:
		_timer_label.visible = false
		_open_btn.text = Loc.t("box_open")
		_style_btn(_open_btn, OPEN_NORMAL, OPEN_HOVER, OPEN_PRESSED)
		_font(_open_btn, BTN_FONT, Color.WHITE, 6)
	else:
		_timer_label.visible = true
		_timer_label.text = "%s  %s" % [Loc.t("box_next_free"), _format_hms(SaveManager.seconds_until_free_box())]
		_open_btn.text = Loc.t("box_open_ad")
		_style_btn(_open_btn, AD_NORMAL, AD_HOVER, AD_PRESSED)
		_font(_open_btn, BTN_FONT - 6, Color.WHITE, 6)

func _format_hms(total: int) -> String:
	@warning_ignore("integer_division")
	var h := total / 3600
	@warning_ignore("integer_division")
	var m := (total % 3600) / 60
	var s := total % 60
	return "%02d:%02d:%02d" % [h, m, s]

# ============================================================
# OPEN + SPIN
# ============================================================

## Skins that are NOT obtainable from the box (unlocked only via achievements).
const BOX_EXCLUDED_SKINS := ["default", "Player_deprived", "Player_100", "Player_skeleton"]

## Obtainable items the player does NOT yet own — so a duplicate can never drop
## (owned items have a 0% chance). Empty = the player owns everything obtainable.
func _build_pool() -> Array:
	var pool: Array = []
	for sid in SpriteLoader.get_available_skins():
		var s := String(sid)
		if s not in BOX_EXCLUDED_SKINS and not SaveManager.is_skin_owned(s):
			pool.append({"kind": "skin", "id": s})
	for t: Dictionary in TrailMeta.TRAILS:
		var tid: String = t.get("id", "")
		if tid != "" and tid != "none" and not SaveManager.is_trail_owned(tid):
			pool.append({"kind": "trail", "id": tid})
	return pool

## True while the player still has at least one box-obtainable item left to unlock.
## Used by the menu to hide the "FREE" badge once a spin could only yield duplicates.
static func has_box_rewards_left() -> bool:
	for sid in SpriteLoader.get_available_skins():
		var s := String(sid)
		if s not in BOX_EXCLUDED_SKINS and not SaveManager.is_skin_owned(s):
			return true
	for t: Dictionary in TrailMeta.TRAILS:
		var tid: String = t.get("id", "")
		if tid != "" and tid != "none" and not SaveManager.is_trail_owned(tid):
			return true
	return false

## Every obtainable item, regardless of ownership — used for the free "for fun" spin
## once the player owns everything (so the strip is full and a duplicate always lands).
func _full_pool() -> Array:
	var pool: Array = []
	for sid in SpriteLoader.get_available_skins():
		var s := String(sid)
		if s not in BOX_EXCLUDED_SKINS:
			pool.append({"kind": "skin", "id": s})
	for t: Dictionary in TrailMeta.TRAILS:
		var tid: String = t.get("id", "")
		if tid != "" and tid != "none":
			pool.append({"kind": "trail", "id": tid})
	return pool

func _entry_texture(e: Dictionary) -> Texture2D:
	if e.get("kind", "skin") == "trail":
		# Lootbox shows the dedicated preview ("nahled") art.
		var p: String = TrailMeta.preview_path(e["id"])
		return load(p) if p != "" and ResourceLoader.exists(p) else null
	return SpriteLoader.get_player_texture(e["id"])

func _entry_name(e: Dictionary) -> String:
	return TrailMeta.display_name(e["id"]) if e.get("kind") == "trail" else SkinMeta.get_display_name(e["id"])

func _entry_desc(e: Dictionary) -> String:
	return TrailMeta.get_desc(e["id"]) if e.get("kind") == "trail" else SkinMeta.get_description(e["id"])

func _on_open_pressed() -> void:
	if _state != "reward":
		return
	if _all_owned:
		# Free "for fun" spin: everything is owned, so it always yields a duplicate.
		# No cooldown, no ad, and we never touch the daily-box timer.
		var full := _full_pool()
		if full.is_empty():
			return
		AudioManager.play_sfx("box_click")
		_open_btn.disabled = true
		_won = full.pick_random()
		_won_was_new = false
		_start_zoom(full)
		return
	var pool := _build_pool()
	if pool.is_empty():
		# Pool emptied between refresh and press — re-sync the UI instead of opening.
		_refresh_reward()
		return
	# A FREE box opens straight away. Otherwise this is the "OPEN (AD)" button — it
	# requires watching a rewarded ad first (instant grant on no-plugin builds).
	if SaveManager.can_open_box_free():
		_open_box(pool)
	else:
		_open_btn.disabled = true
		AdManager.show_rewarded(AdManager.REWARDED_SPIN, func(success: bool) -> void:
			if not is_instance_valid(self):
				return
			if success:
				_open_box(pool)
			else:
				_open_btn.disabled = false)

## Actually open the box: roll + GRANT + reset the timer NOW (before the spin
## animation) so quitting mid-spin can't lose the reward.
func _open_box(pool: Array) -> void:
	AudioManager.play_sfx("box_click")
	_open_btn.disabled = true
	_won = pool.pick_random()
	if _won.get("kind") == "trail":
		_won_was_new = SaveManager.own_trail(_won["id"])
	else:
		_won_was_new = SaveManager.own_skin(_won["id"])
	SaveManager.mark_box_opened()
	# Owning a new item may complete the "unlock everything" achievement.
	AchievementManager.check_collection_achievements()
	_start_zoom(pool)

## "Support the author" ad button (only shown once everything is owned).
func _on_support_pressed() -> void:
	if _state != "reward":
		return
	AudioManager.play_sfx("button_click_menu")
	_support_btn.disabled = true
	AdManager.show_rewarded(AdManager.REWARDED_SUPPORT, func(success: bool) -> void:
		if not is_instance_valid(self):
			return
		_support_btn.disabled = false
		if success:
			_reward_desc.text = Loc.t("box_thanks"))

## 1.5s anticipation: zoom in on the box, then start the CS2 spin.
func _start_zoom(pool: Array) -> void:
	_state = "zoom"
	if _box_pulse and _box_pulse.is_valid():
		_box_pulse.kill()
	# Fade out the text around the crate so the zoom has room to grow.
	var fade := create_tween().set_parallel(true)
	for c: CanvasItem in [_reward_title, _reward_desc, _timer_label, _open_btn, _support_btn]:
		if c:
			fade.tween_property(c, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	var t := create_tween()
	t.tween_property(_box_holder, "scale", Vector2(1.7, 1.7), 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func() -> void:
		_box_holder.scale = Vector2.ONE
		_start_spin(pool))

func _start_spin(pool: Array) -> void:
	_set_state("spin")
	# Build the strip: random items, with the winner at WIN_INDEX.
	for c in _strip.get_children():
		c.queue_free()
	var iw := ITEM_W * _sf
	for i in STRIP_LEN:
		var e: Dictionary = _won if i == WIN_INDEX else pool.pick_random()
		var cell := _make_strip_cell(e)
		cell.position = Vector2(i * iw, 0)
		_strip.add_child(cell)

	var win_w := SPIN_W * _sf
	var final_x := win_w * 0.5 - (WIN_INDEX * iw + iw * 0.5)
	_strip.position = Vector2(0, 0)
	_spin_elapsed = 0.0
	_next_tick_at = 0.0
	_spin_done_ticking = false

	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = create_tween()
	_spin_tween.tween_property(_strip, "position:x", final_x, SPIN_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_spin_tween.tween_callback(_show_result)

func _make_strip_cell(e: Dictionary) -> Control:
	var iw := ITEM_W * _sf
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(iw, SPIN_H * _sf)
	cell.size = Vector2(iw, SPIN_H * _sf)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	st.border_color = Color(0.25, 0.25, 0.3)
	st.set_border_width_all(_s(2))
	st.set_corner_radius_all(_s(10))
	cell.add_theme_stylebox_override("panel", st)
	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad := (ITEM_W - ITEM_BOX) * 0.5 * _sf
	tex.offset_left = pad; tex.offset_right = -pad
	tex.offset_top = _s(16); tex.offset_bottom = -_s(16)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture = _entry_texture(e)
	cell.add_child(tex)
	return cell

func _show_result() -> void:
	_result_tex.texture = _entry_texture(_won)
	_result_name.text = _entry_name(_won)
	if _won_was_new:
		_result_desc.text = _entry_desc(_won)
	elif _all_owned:
		_result_desc.text = Loc.t("box_duplicate_all")
	else:
		_result_desc.text = Loc.t("box_duplicate")
	_set_state("result")
	AudioManager.play_sfx("box_reveal")
	_play_reveal_anim()

## Pop the won item in + blink a glow behind it a few times.
func _play_reveal_anim() -> void:
	if not _result_panel:
		return
	_result_panel.pivot_offset = _result_panel.custom_minimum_size * 0.5
	_result_panel.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(_result_panel, "scale", Vector2(1.12, 1.12), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_result_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	if _result_glow:
		_result_glow.color = Color(GLOW.r, GLOW.g, GLOW.b, 0.0)
		var blink := create_tween().set_loops(4)
		blink.tween_property(_result_glow, "color:a", 0.55, 0.26).set_trans(Tween.TRANS_SINE)
		blink.tween_property(_result_glow, "color:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE)

# ============================================================
# OPEN / CLOSE
# ============================================================

func show_popup() -> void:
	_set_state("reward")
	visible = true
	Anim.open(_overlay, _panel, OVERLAY_COLOR.a)

func _close() -> void:
	# Can't close while the box is being opened (zoom + spin animation).
	if _state == "zoom" or _state == "spin":
		return
	AudioManager.play_sfx("button_click_menu")
	Anim.close(_overlay, _panel, func() -> void:
		visible = false)

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
		c.add_theme_color_override("font_pressed_color", col)
	c.add_theme_constant_override("outline_size", _s(outline))
	c.add_theme_color_override("font_outline_color", Color.BLACK)

func _style_btn(b: Button, normal: Color, hover: Color, pressed: Color) -> void:
	b.add_theme_stylebox_override("normal", _sb(normal))
	b.add_theme_stylebox_override("hover", _sb(hover))
	b.add_theme_stylebox_override("pressed", _sb(pressed))
	b.add_theme_stylebox_override("focus", _sb(normal))

func _sb(bg: Color) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg, bg.lightened(0.25), 16.0, 3.0, 18.0, 10.0)
