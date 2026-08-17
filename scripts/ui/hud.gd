class_name HUD
extends CanvasLayer
## In-game HUD - converted from Classes/Hud.as
## Health bar, powerup display, level/tier/wave display, timer.
## Tap the timer to pause. Scales to viewport size.

signal pause_requested  ## Emitted when player taps the time label
signal skip_requested   ## "Skip level for an ad" button (shown after 5 deaths in a level)

const UIT := preload("res://scripts/utils/ui_theme.gd")
const Loc := preload("res://scripts/utils/localization.gd")

@onready var health_bar: ProgressBar = $HealthBar
@onready var paint_bar: ProgressBar = $PaintBar
@onready var level_label: Label = $LevelLabel
@onready var tier_label: Label = $TierLabel
@onready var time_label: Label = $TimeLabel
var _time_slot := "time"   ## what the top-right slot shows: "time" | "ammo" | "targets"

## Repurpose the top-right slot. In "ammo"/"targets" mode the time label shows that
## counter (white, time font) and normal time updates are ignored.
func set_time_slot(mode: String) -> void:
	_time_slot = mode
	if time_label:
		time_label.add_theme_color_override("font_color", Color.WHITE)

## Destroyed-target counter routed to the time slot (Totem challenge).
func update_targets(done: int) -> void:
	if _time_slot == "targets" and time_label:
		time_label.text = "%s: %d" % [Loc.t("totems_hud"), done]
@onready var score_label: Label = $ScoreLabel

# ---- POWERUP HUD (stacked vertically) ----
var _powerup_vbox: VBoxContainer
var _powerup_rows: Dictionary = {}
var _powerup_timer_labels: Dictionary = {}
var _powerup_bars: Dictionary = {}    ## type -> ProgressBar (remaining-time fill)
var _powerup_max: Dictionary = {}     ## type -> max duration seen (for fill fraction)

# ---- TOP-BAR PANELS (cosmetic backgrounds behind timer / mode label) ----
var _time_panel: Panel
var _mode_panel: Panel

# ---- TIMEBOOST "2x" INDICATOR (tilted sprite next to the timer, scale-pulsing) ----
var _boost_sprite: TextureRect
var _boost_pulse_time: float = 0.0
const BOOST_TILT_DEG := -12.0

# ---- STYLE CONSTANTS (shared "cool" mobile look) ----
const PANEL_BG := Color(0.07, 0.08, 0.12, 0.78)
const PANEL_BORDER := Color(0.30, 0.34, 0.46, 0.9)
const ACCENT := Color(1.0, 0.78, 0.15)        ## Gold accent (timer, highlights)

# ---- HP GAUGE (semicircle dome) ----
const HealthGaugeScript := preload("res://scripts/ui/health_gauge.gd")
var _hp_gauge  ## HealthGauge — dome HP meter (replaces the old flat bar)
var _ammo_label: Label  ## remaining-ammo counter (limited-ammo challenges, lazy-built)
var _kill_label: Label  ## kill counter (kill-scored challenges, lazy-built)

# ---- FONTS ----
var _lilita_font: Font

var _level_scale: float = 1.0
var _tier_scale: float = 1.0
var _target_scale: float = 1.0

var _time_button: Button  ## Invisible button overlaying the time label for tap-to-pause
var _pause_btn: Button     ## dedicated, clearly-visible corner pause button
var _skip_btn: Button      ## "skip for ad" pill LEFT of the timer (5+ deaths in a level)
var _skip_visible_pending: bool = false   ## restore visibility across rescale_live()
var _safe: Vector4 = Vector4.ZERO  ## safe-area insets (l, t, r, b) in canvas units
var _hpbar_opacity: float = 1.0    ## base opacity of the HP gauge (setting)
var _dynamic_opacity: bool = true  ## fade the gauge when the player is near it (setting)
const HP_NEAR_OPACITY := 0.4       ## opacity when the player is near the gauge

# ---- SCALE FACTOR ----
var _sf: float = 1.0

func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_game(vp)
	_safe = GameManager.get_safe_insets()
	_load_font()
	_scale_tscn_nodes()
	_setup_hp_bar_style()
	_setup_label_styles()
	_setup_top_panels()
	_setup_boost_indicator()
	_setup_time_tap()
	_setup_powerup_display()
	apply_hp_opacity_settings()

## Re-apply the game-GUI scale LIVE (settings Apply in-game): free the code-built nodes
## and re-run the build pipeline at the new scale. The scene labels/bars are restyled
## in place (the _setup_* functions assign absolute design-px values, so re-running is
## idempotent). game_world re-applies the dynamic state (HP, mode, powerup rows…) after.
func rescale_live() -> void:
	var score_was_visible: bool = score_label.visible if score_label else true
	var paint_was_visible: bool = paint_bar.visible if paint_bar else true
	var ammo_was_visible: bool = _ammo_label != null and _ammo_label.visible
	var kills_was_visible: bool = _kill_label != null and _kill_label.visible
	var skip_was_visible: bool = _skip_btn != null and _skip_btn.visible
	for n in [_time_panel, _mode_panel, _boost_sprite, _powerup_vbox, _hp_gauge,
			_pause_btn, _time_button, _ammo_label, _kill_label, _skip_btn]:
		if n and is_instance_valid(n):
			n.queue_free()
	_skip_btn = null
	_skip_visible_pending = skip_was_visible
	_time_panel = null
	_mode_panel = null
	_boost_sprite = null
	_powerup_vbox = null
	_powerup_rows.clear()
	_powerup_timer_labels.clear()
	_powerup_bars.clear()
	_powerup_max.clear()
	_hp_gauge = null
	_pause_btn = null
	_time_button = null
	_ammo_label = null
	_kill_label = null
	# Rebuild at the new scale.
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf_game(vp)
	_safe = GameManager.get_safe_insets()
	_scale_tscn_nodes()
	_setup_hp_bar_style()
	_setup_label_styles()
	_setup_top_panels()
	_setup_boost_indicator()
	_setup_time_tap()
	_setup_powerup_display()
	apply_hp_opacity_settings()
	# Restore simple visibility states (mode-specific values re-applied by game_world).
	if score_label:
		score_label.visible = score_was_visible
	if paint_bar:
		paint_bar.visible = paint_was_visible
	set_ammo_visible(ammo_was_visible)
	set_kill_counter_visible(kills_was_visible)

func _process(delta: float) -> void:
	_level_scale += 0.1 * (_target_scale - _level_scale)
	if level_label:
		level_label.scale = Vector2(_level_scale, _level_scale)
	_tier_scale += 0.1 * (_target_scale - _tier_scale)
	if tier_label:
		tier_label.scale = Vector2(_tier_scale, _tier_scale)

	# Scale-pulse the "2x" timeboost indicator while it is showing.
	if _boost_sprite and _boost_sprite.visible:
		_boost_pulse_time += delta
		_boost_sprite.pivot_offset = _boost_sprite.size / 2.0
		var s := 1.0 + 0.15 * sin(_boost_pulse_time * 7.0)
		_boost_sprite.scale = Vector2(s, s)

	_update_hp_opacity(delta)

# ============================================================
# UPDATE METHODS (called by game_world)
# ============================================================

func update_health(current: float, max_hp: float) -> void:
	if _hp_gauge:
		_hp_gauge.set_hp(current, max_hp)

func update_paint(current: float, max_paint: float) -> void:
	if paint_bar:
		paint_bar.max_value = max_paint
		paint_bar.value = current

func update_level(level_num: int) -> void:
	if level_label:
		if level_num < 0:
			level_label.visible = false
		else:
			level_label.visible = true
			level_label.text = "LVL %d" % level_num
			_level_scale = 1.5
			_target_scale = 1.0
	if _mode_panel:
		_mode_panel.visible = level_num >= 0

func update_tier(tier: int) -> void:
	if tier_label:
		if tier > 0:
			tier_label.text = "TIER %d" % (tier + 1)
			tier_label.visible = true
			_tier_scale = 1.8
		else:
			tier_label.visible = false

func update_time(elapsed: float) -> void:
	if _time_slot != "time":
		return   # the slot is repurposed (ammo/targets); don't overwrite it with the clock
	if time_label:
		var minutes := int(elapsed) / 60
		var seconds := int(elapsed) % 60
		var ms := int(fmod(elapsed, 1.0) * 100)
		time_label.text = "%d:%02d.%02d" % [minutes, seconds, ms]

## Tint the time label green when player is in a timeboost zone.
func set_time_boosted(boosted: bool) -> void:
	if time_label:
		if boosted:
			time_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			time_label.add_theme_color_override("font_color", Color.WHITE)
	# Show/hide the tilted "2x" pulse indicator next to the timer.
	if _boost_sprite:
		if boosted and not _boost_sprite.visible:
			_boost_pulse_time = 0.0
		_boost_sprite.visible = boosted

func update_score(score: int) -> void:
	if score_label:
		score_label.text = str(score)

func update_wave(wave_num: int) -> void:
	pass

func set_endless_mode() -> void:
	if score_label:
		score_label.visible = false
	if paint_bar:
		paint_bar.visible = false

## Show/hide the bottom HP gauge (hidden in challenges where the player has a fixed 1 HP).
func set_hp_gauge_visible(v: bool) -> void:
	if _hp_gauge:
		_hp_gauge.visible = v

## Remaining-ammo counter (limited-ammo challenges) — top-left, built on demand.
func set_ammo_visible(v: bool) -> void:
	if _ammo_label == null:
		if not v:
			return
		_ammo_label = Label.new()
		_ammo_label.name = "AmmoLabel"
		_ammo_label.position = Vector2(28 * _sf, 24 * _sf)
		if _lilita_font:
			_ammo_label.add_theme_font_override("font", _lilita_font)
		_ammo_label.add_theme_font_size_override("font_size", _s(44))
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_ammo_label.add_theme_constant_override("outline_size", _s(5))
		_ammo_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ammo_label)
	_ammo_label.visible = v

func update_ammo(n: int) -> void:
	if _time_slot == "ammo" and time_label:
		time_label.text = "%s: %d" % [Loc.t("ammo"), n]   # white, in the time slot
		return
	if _ammo_label:
		_ammo_label.text = "%s: %d" % [Loc.t("ammo"), n]
		# Red warning color when running dry.
		_ammo_label.add_theme_color_override("font_color",
			Color(1.0, 0.30, 0.25) if n <= 5 else Color(1.0, 0.85, 0.3))

## Kill counter (kill-scored challenges) — top-left, built on demand.
func set_kill_counter_visible(v: bool) -> void:
	if _kill_label == null:
		if not v:
			return
		_kill_label = Label.new()
		_kill_label.name = "KillLabel"
		_kill_label.position = Vector2(28 * _sf, 24 * _sf)
		if _lilita_font:
			_kill_label.add_theme_font_override("font", _lilita_font)
		_kill_label.add_theme_font_size_override("font_size", _s(44))
		_kill_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
		_kill_label.add_theme_constant_override("outline_size", _s(5))
		_kill_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_kill_label)
	_kill_label.visible = v

func update_kill_counter(n: int) -> void:
	if _kill_label:
		_kill_label.text = "%s: %d" % [Loc.t("kills_hud"), n]

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false

# ============================================================
# POWERUP DISPLAY (stacked vertically)
# ============================================================

func show_powerup(type: int, tex: Texture2D, type_name: String) -> void:
	if _powerup_rows.has(type):
		return
	_create_powerup_row(type, tex, type_name)
	_powerup_vbox.visible = true

func hide_powerup_type(type: int) -> void:
	if _powerup_rows.has(type):
		_powerup_rows[type].queue_free()
		_powerup_rows.erase(type)
		_powerup_timer_labels.erase(type)
		_powerup_bars.erase(type)
		_powerup_max.erase(type)
	if _powerup_rows.is_empty():
		_powerup_vbox.visible = false

func hide_powerup() -> void:
	for type: int in _powerup_rows.keys():
		_powerup_rows[type].queue_free()
	_powerup_rows.clear()
	_powerup_timer_labels.clear()
	_powerup_bars.clear()
	_powerup_max.clear()
	if _powerup_vbox:
		_powerup_vbox.visible = false

func update_powerup_timer(type: int, remaining: float) -> void:
	# Track the largest value seen as the effective duration (for the fill bar).
	var prev_max: float = _powerup_max.get(type, 0.0)
	if remaining > prev_max:
		_powerup_max[type] = remaining
	var label: Label = _powerup_timer_labels.get(type, null)
	if label:
		label.text = "%.1fs" % maxf(remaining, 0.0)
	var bar: ProgressBar = _powerup_bars.get(type, null)
	if bar:
		var maxv: float = maxf(_powerup_max.get(type, 1.0), 0.001)
		bar.value = clampf(remaining / maxv, 0.0, 1.0) * 100.0
		# Bar shifts to red as it runs low for an at-a-glance warning.
		var frac := remaining / maxv
		var fill_style: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			fill_style.bg_color = ACCENT.lerp(Color(1.0, 0.25, 0.2), 1.0 - clampf(frac, 0.0, 1.0))

# ============================================================
# SETUP
# ============================================================

func _load_font() -> void:
	_lilita_font = UIT.load_font()

## Scale the .tscn-defined node offsets to current viewport size.
func _scale_tscn_nodes() -> void:
	if health_bar:
		health_bar.offset_left = -450 * _sf   ## 25% wider (was -360)
		health_bar.offset_top = -44 * _sf     ## 25% taller (was -38)
		health_bar.offset_right = 450 * _sf   ## 25% wider (was 360)
		health_bar.offset_bottom = -14 * _sf
		health_bar.show_percentage = false     ## Text is in the label inside

	# Paint bar: top-left, offset by the left/top safe insets.
	if paint_bar:
		paint_bar.offset_left = 28 * _sf + _safe.x
		paint_bar.offset_top = 76 * _sf + _safe.y
		paint_bar.offset_right = 340 * _sf + _safe.x
		paint_bar.offset_bottom = 108 * _sf + _safe.y

	if level_label:
		level_label.offset_left = -160 * _sf
		level_label.offset_top = 14 * _sf + _safe.y
		level_label.offset_right = 160 * _sf
		level_label.offset_bottom = 60 * _sf + _safe.y

	if tier_label:
		tier_label.offset_left = -160 * _sf
		tier_label.offset_top = 60 * _sf + _safe.y
		tier_label.offset_right = 160 * _sf
		tier_label.offset_bottom = 100 * _sf + _safe.y

	# Time / score: top-right, pulled in by the top + right safe insets.
	if time_label:
		time_label.offset_left = -320 * _sf - _safe.z
		time_label.offset_top = 14 * _sf + _safe.y
		time_label.offset_right = -28 * _sf - _safe.z
		time_label.offset_bottom = 60 * _sf + _safe.y

	if score_label:
		score_label.offset_left = -320 * _sf - _safe.z
		score_label.offset_top = 60 * _sf + _safe.y
		score_label.offset_right = -28 * _sf - _safe.z
		score_label.offset_bottom = 100 * _sf + _safe.y

func _setup_hp_bar_style() -> void:
	# Retire the old flat HP bar — replaced by the semicircle dome gauge.
	if health_bar:
		health_bar.visible = false

	_hp_gauge = HealthGaugeScript.new()
	_hp_gauge.name = "HealthGauge"
	var gw := 200.0 * _sf * HUD_MAG   # was 280 → 200, then ×HUD_MAG
	var gh := 108.0 * _sf * HUD_MAG   # was 150 → 108, then ×HUD_MAG
	_hp_gauge.anchor_left = 0.5
	_hp_gauge.anchor_right = 0.5
	_hp_gauge.anchor_top = 1.0
	_hp_gauge.anchor_bottom = 1.0
	_hp_gauge.offset_left = -gw * 0.5
	_hp_gauge.offset_right = gw * 0.5
	_hp_gauge.offset_top = -gh
	_hp_gauge.offset_bottom = 0.0  # always flush with the bottom edge of the screen
	_hp_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_gauge)
	_hp_gauge.set_font(_lilita_font)
	_hp_gauge.set_hp(1.0, 1.0)

## (Re)read the HP-gauge opacity settings; called on _ready and when settings are applied.
func apply_hp_opacity_settings() -> void:
	_hpbar_opacity = clampf(float(SaveManager.get_setting("hpbar_opacity", 1.0)), 0.0, 1.0)
	_dynamic_opacity = bool(SaveManager.get_setting("dynamic_opacity", true))
	if _hp_gauge:
		_hp_gauge.modulate.a = _hpbar_opacity

## When dynamic opacity is on and the player (on screen) is near the bottom HP gauge,
## fade it toward 40% so the player can see what's under it; otherwise use base opacity.
func _update_hp_opacity(delta: float) -> void:
	if _hp_gauge == null:
		return
	var target := _hpbar_opacity
	if _dynamic_opacity:
		var players := get_tree().get_nodes_in_group("players")
		if players.size() > 0 and players[0] is Node2D:
			var p := players[0] as Node2D
			var scr: Vector2 = p.get_global_transform_with_canvas().origin
			var rect: Rect2 = _hp_gauge.get_global_rect().grow(70.0 * _sf)
			if rect.has_point(scr):
				target = minf(_hpbar_opacity, HP_NEAR_OPACITY)
	_hp_gauge.modulate.a = lerpf(_hp_gauge.modulate.a, target, clampf(delta * 10.0, 0.0, 1.0))

func _setup_label_styles() -> void:
	# Time label — large, readable on mobile, gold accent
	if time_label and _lilita_font:
		time_label.add_theme_font_override("font", _lilita_font)
		time_label.add_theme_font_size_override("font_size", _s(40.0 * TIMER_MAG))
		time_label.add_theme_constant_override("outline_size", _s(5.0 * TIMER_MAG))
		time_label.add_theme_color_override("font_color", Color.WHITE)
		time_label.add_theme_color_override("font_outline_color", Color.BLACK)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Score label
	if score_label and _lilita_font:
		score_label.add_theme_font_override("font", _lilita_font)
		score_label.add_theme_font_size_override("font_size", _s(28))
		score_label.add_theme_constant_override("outline_size", _s(4))
		score_label.add_theme_color_override("font_outline_color", Color.BLACK)
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Level label
	if level_label and _lilita_font:
		level_label.add_theme_font_override("font", _lilita_font)
		level_label.add_theme_font_size_override("font_size", _s(34))
		level_label.add_theme_constant_override("outline_size", _s(5))
		level_label.add_theme_color_override("font_outline_color", Color.BLACK)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Tier label
	if tier_label and _lilita_font:
		tier_label.add_theme_font_override("font", _lilita_font)
		tier_label.add_theme_font_size_override("font_size", _s(26))
		tier_label.add_theme_constant_override("outline_size", _s(4))
		tier_label.add_theme_color_override("font_outline_color", Color.BLACK)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## Rounded translucent stylebox used by every HUD panel for a cohesive look.
func _make_panel_style(corner: int = 14, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(_s(border_w))
	sb.set_corner_radius_all(_s(corner))
	# Subtle inner padding so content doesn't touch the rounded edges.
	sb.content_margin_left = _s(10)
	sb.content_margin_right = _s(10)
	sb.content_margin_top = _s(4)
	sb.content_margin_bottom = _s(4)
	return sb

## Build cosmetic background pills behind the timer and the mode/level label.
## The whole timer pill (time text + divider + pause bars) is enlarged by this factor. It
## stays anchored to the top-right corner and grows LEFT + DOWN.
const TIMER_MAG := 1.3
## Enlarges the other in-game readouts: HP gauge, powerup cards and the "2x" boost badge.
## (The inventory has its own SLOT_SIZE in inventory_ui.gd, bumped by the same factor.)
const HUD_MAG := 1.2

func _setup_top_panels() -> void:
	var pad := 12.0 * _sf * TIMER_MAG
	# ---- Timer pill (top-right) — tap anywhere on it to pause. Shows a "‖" pause
	# segment on the right, divided from the time by a thin line. Sized ×TIMER_MAG. ----
	if time_label:
		var pseg := 84.0 * _sf * TIMER_MAG            # width of the pause-icon segment
		var pill_right := -28.0 * _sf - _safe.z       # right edge stays tucked in the corner
		# Time text occupies the left part of the pill; pause glyph the right `pseg`. Top-right
		# corner is fixed (pill_right / safe insets); width + height scale by TIMER_MAG.
		time_label.offset_top = 14.0 * _sf + _safe.y
		time_label.offset_bottom = time_label.offset_top + 46.0 * _sf * TIMER_MAG
		time_label.offset_right = pill_right - pseg
		time_label.offset_left = time_label.offset_right - 268.0 * _sf * TIMER_MAG

		_time_panel = Panel.new()
		_time_panel.name = "TimePanel"
		_time_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_time_panel.add_theme_stylebox_override("panel", _make_panel_style(int(16 * TIMER_MAG), 2))
		_time_panel.anchor_left = 1.0
		_time_panel.anchor_top = 0.0
		_time_panel.anchor_right = 1.0
		_time_panel.anchor_bottom = 0.0
		_time_panel.offset_left = time_label.offset_left - pad
		_time_panel.offset_top = time_label.offset_top - pad * 0.5
		_time_panel.offset_right = pill_right + pad
		_time_panel.offset_bottom = time_label.offset_bottom + pad * 0.5
		add_child(_time_panel)
		# Render behind the time label (move just before it in the tree).
		move_child(_time_panel, time_label.get_index())

		# Divider between time and pause segment (child of the panel, right-anchored).
		var divider := ColorRect.new()
		divider.color = Color(1, 1, 1, 0.18)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.anchor_left = 1.0
		divider.anchor_right = 1.0
		divider.anchor_top = 0.0
		divider.anchor_bottom = 1.0
		divider.offset_left = -(pseg + pad) - maxf(2.0, 2.0 * _sf * TIMER_MAG)
		divider.offset_right = -(pseg + pad)
		divider.offset_top = 10.0 * _sf * TIMER_MAG
		divider.offset_bottom = -10.0 * _sf * TIMER_MAG
		_time_panel.add_child(divider)

		# Two pause bars centered in the right segment.
		var bar_w := 8.0 * _sf * TIMER_MAG
		var bar_h := 34.0 * _sf * TIMER_MAG
		var gap := 8.0 * _sf * TIMER_MAG
		var seg_center := -(pseg + pad) * 0.5   # from the panel's right edge
		for i in 2:
			var bar := ColorRect.new()
			bar.color = Color(0.92, 0.94, 1.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.anchor_left = 1.0
			bar.anchor_right = 1.0
			bar.anchor_top = 0.5
			bar.anchor_bottom = 0.5
			var bx := seg_center - (bar_w + gap) * 0.5 + i * (bar_w + gap)
			bar.offset_left = bx
			bar.offset_right = bx + bar_w
			bar.offset_top = -bar_h * 0.5
			bar.offset_bottom = bar_h * 0.5
			_time_panel.add_child(bar)

	# ---- "Skip for ad" pill (under the timer; shown after 5 deaths in a level) ----
	if time_label:
		_skip_btn = Button.new()
		_skip_btn.name = "SkipButton"
		_skip_btn.text = Loc.t("skip_ad")
		_skip_btn.focus_mode = Control.FOCUS_NONE
		_skip_btn.anchor_left = 1.0; _skip_btn.anchor_right = 1.0
		# LEFT of the timer pill (tracks the enlarged pill's left edge), same height as it —
		# not below the timer.
		var pill_left := _time_panel.offset_left if _time_panel else -392.0 * _sf - _safe.z
		_skip_btn.offset_right = pill_left - 16.0 * _sf
		_skip_btn.offset_left = _skip_btn.offset_right - 340.0 * _sf
		_skip_btn.offset_top = 8.0 * _sf + _safe.y
		_skip_btn.offset_bottom = 66.0 * _sf + _safe.y
		var ssb := UIT.make_sb(_sf, Color(0.13, 0.22, 0.42, 0.92), Color(0.35, 0.55, 0.95), 14.0, 3.0)
		_skip_btn.add_theme_stylebox_override("normal", ssb)
		_skip_btn.add_theme_stylebox_override("hover", ssb)
		_skip_btn.add_theme_stylebox_override("pressed", ssb)
		if _lilita_font:
			_skip_btn.add_theme_font_override("font", _lilita_font)
		_skip_btn.add_theme_font_size_override("font_size", int(26.0 * _sf))
		_skip_btn.add_theme_color_override("font_color", Color.WHITE)
		_skip_btn.add_theme_constant_override("outline_size", int(3.0 * _sf))
		_skip_btn.add_theme_color_override("font_outline_color", Color.BLACK)
		_skip_btn.visible = _skip_visible_pending
		_skip_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("button_click")
			skip_requested.emit())
		add_child(_skip_btn)

	# ---- Mode / level pill (top-center) ----
	if level_label:
		_mode_panel = Panel.new()
		_mode_panel.name = "ModePanel"
		_mode_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mode_panel.add_theme_stylebox_override("panel", _make_panel_style(16, 2))
		_mode_panel.anchor_left = level_label.anchor_left
		_mode_panel.anchor_top = level_label.anchor_top
		_mode_panel.anchor_right = level_label.anchor_right
		_mode_panel.anchor_bottom = level_label.anchor_bottom
		_mode_panel.offset_left = level_label.offset_left - pad * 0.5
		_mode_panel.offset_top = level_label.offset_top - pad * 0.5
		_mode_panel.offset_right = level_label.offset_right + pad * 0.5
		_mode_panel.offset_bottom = level_label.offset_bottom + pad * 0.5
		add_child(_mode_panel)
		move_child(_mode_panel, level_label.get_index())

## Tilted "2x" sprite shown just left of the timer while in a timeboost zone.
func _setup_boost_indicator() -> void:
	var path := "res://assets/sprites/zones/timeboost_textdraw.svg"
	if not ResourceLoader.exists(path):
		return
	_boost_sprite = TextureRect.new()
	_boost_sprite.name = "BoostIndicator"
	_boost_sprite.texture = load(path)
	_boost_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boost_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boost_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_sprite.visible = false
	_boost_sprite.rotation_degrees = BOOST_TILT_DEG
	# Anchored to the top-right, positioned just left of the timer pill.
	_boost_sprite.anchor_left = 1.0
	_boost_sprite.anchor_top = 0.0
	_boost_sprite.anchor_right = 1.0
	_boost_sprite.anchor_bottom = 0.0
	# Sit just LEFT of the timer pill, tracking its REAL left edge — with TIMER_MAG the pill
	# reaches further left than the old hardcoded -348 and the "2x" ended up on top of the time.
	var w := 110.0 * _sf * HUD_MAG
	var pill_left: float = _time_panel.offset_left if _time_panel else -392.0 * _sf - _safe.z
	_boost_sprite.offset_right = pill_left - 12.0 * _sf
	_boost_sprite.offset_left = _boost_sprite.offset_right - w
	_boost_sprite.offset_top = 0.0
	_boost_sprite.offset_bottom = 80.0 * _sf
	add_child(_boost_sprite)

## Invisible button covering the whole timer pill — tapping it pauses the game.
func _setup_time_tap() -> void:
	if _time_panel == null:
		return
	_time_button = Button.new()
	_time_button.name = "TimeTapButton"
	_time_button.flat = true  # No visible styling — completely transparent
	_time_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Cover the entire timer pill (time text + pause segment).
	_time_button.anchor_left = 1.0
	_time_button.anchor_top = 0.0
	_time_button.anchor_right = 1.0
	_time_button.anchor_bottom = 0.0
	_time_button.offset_left = _time_panel.offset_left
	_time_button.offset_top = _time_panel.offset_top
	_time_button.offset_right = _time_panel.offset_right
	_time_button.offset_bottom = _time_panel.offset_bottom
	_time_button.pressed.connect(_on_time_tapped)
	add_child(_time_button)

func _on_time_tapped() -> void:
	AudioManager.play_sfx("button_click")
	pause_requested.emit()

# ============================================================
# FINAL BOSS HP BAR (big, top-centre; level 30)
# ============================================================
var _boss_bar_bg: Panel = null
var _boss_bar_fill: Panel = null

func show_boss_bar(v: bool) -> void:
	if v and _boss_bar_bg == null:
		_boss_bar_bg = Panel.new()
		_boss_bar_bg.name = "BossBar"
		_boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_bar_bg.anchor_left = 0.5; _boss_bar_bg.anchor_right = 0.5
		var w := 760.0 * _sf
		_boss_bar_bg.offset_left = -w * 0.5
		_boss_bar_bg.offset_right = w * 0.5
		_boss_bar_bg.offset_top = 92.0 * _sf + _safe.y
		_boss_bar_bg.offset_bottom = 126.0 * _sf + _safe.y
		_boss_bar_bg.add_theme_stylebox_override("panel",
			UIT.make_sb(_sf, Color(0.05, 0.05, 0.08, 0.9), Color(0.55, 0.15, 0.15), 10.0, 3.0))
		add_child(_boss_bar_bg)
		_boss_bar_fill = Panel.new()
		_boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boss_bar_fill.offset_left = 4.0 * _sf; _boss_bar_fill.offset_top = 4.0 * _sf
		_boss_bar_fill.offset_right = -4.0 * _sf; _boss_bar_fill.offset_bottom = -4.0 * _sf
		_boss_bar_fill.anchor_right = 1.0
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0.85, 0.15, 0.15)
		fsb.set_corner_radius_all(int(6.0 * _sf))
		_boss_bar_fill.add_theme_stylebox_override("panel", fsb)
		_boss_bar_bg.add_child(_boss_bar_fill)
		var lbl := Label.new()
		lbl.text = "MUTANT"
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _lilita_font:
			lbl.add_theme_font_override("font", _lilita_font)
		lbl.add_theme_font_size_override("font_size", int(22.0 * _sf))
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", int(4.0 * _sf))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		_boss_bar_bg.add_child(lbl)
	if _boss_bar_bg:
		_boss_bar_bg.visible = v
	if not v and _boss_bar_bg:
		_boss_bar_bg.queue_free()
		_boss_bar_bg = null
		_boss_bar_fill = null

func set_boss_hp(ratio: float) -> void:
	if _boss_bar_fill and is_instance_valid(_boss_bar_fill):
		_boss_bar_fill.anchor_right = clampf(ratio, 0.0, 1.0)

## Show/hide the "skip level for an ad" pill under the timer.
func set_skip_visible(v: bool) -> void:
	_skip_visible_pending = v
	if _skip_btn and is_instance_valid(_skip_btn):
		_skip_btn.visible = v

func _setup_powerup_display() -> void:
	_powerup_vbox = VBoxContainer.new()
	_powerup_vbox.visible = false
	_powerup_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_powerup_vbox.position = Vector2(16 * _sf + _safe.x, 16 * _sf + _safe.y)  ## Top-left corner
	_powerup_vbox.add_theme_constant_override("separation", _s(10 * HUD_MAG))
	_powerup_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_powerup_vbox)

## Build one "cool" powerup card: rounded panel with a large icon, name and a
## colored remaining-time bar. Bigger and clearer than the old text row.
func _create_powerup_row(type: int, tex: Texture2D, type_name: String) -> void:
	var icon_size := 64.0 * _sf * HUD_MAG
	var card_w := 320.0 * _sf * HUD_MAG

	# ---- Card panel ----
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(card_w, icon_size + 16.0 * _sf * HUD_MAG)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(14, 2))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8.0 * _sf * HUD_MAG
	hbox.offset_top = 8.0 * _sf * HUD_MAG
	hbox.offset_right = -12.0 * _sf * HUD_MAG
	hbox.offset_bottom = -8.0 * _sf * HUD_MAG
	hbox.add_theme_constant_override("separation", _s(12 * HUD_MAG))
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# ---- Big icon ----
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		icon.texture = tex
	hbox.add_child(icon)

	# ---- Right column: name (+ timer) over a progress bar ----
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", _s(4 * HUD_MAG))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = type_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _lilita_font:
		name_lbl.add_theme_font_override("font", _lilita_font)
	name_lbl.add_theme_font_size_override("font_size", _s(26 * HUD_MAG))
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_constant_override("outline_size", _s(4 * HUD_MAG))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	top_row.add_child(name_lbl)

	var timer_lbl := Label.new()
	timer_lbl.text = "0.0s"
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _lilita_font:
		timer_lbl.add_theme_font_override("font", _lilita_font)
	timer_lbl.add_theme_font_size_override("font_size", _s(24 * HUD_MAG))
	timer_lbl.add_theme_color_override("font_color", ACCENT)
	timer_lbl.add_theme_constant_override("outline_size", _s(4 * HUD_MAG))
	timer_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	top_row.add_child(timer_lbl)

	# ---- Remaining-time bar ----
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10.0 * _sf * HUD_MAG)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bar_bg.set_corner_radius_all(_s(5 * HUD_MAG))
	bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(_s(5 * HUD_MAG))
	bar.add_theme_stylebox_override("fill", bar_fill)
	col.add_child(bar)

	_powerup_vbox.add_child(panel)
	_powerup_rows[type] = panel
	_powerup_timer_labels[type] = timer_lbl
	_powerup_bars[type] = bar
