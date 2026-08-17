class_name MainMenu
extends Control
## Main Menu — entry point of the game.
## Logo, PLAY button, secondary grid (Daily/Stats/Skins/Settings),
## music toggle, language selector, version label.
## Background: gradient + decorative paint splats + floating particles.
## Layout designed for 1920x1080 landscape mobile. Scales to other resolutions.

# Skins popup loaded via preload (robust regardless of class-cache state).
const SkinsPopupScript := preload("res://scripts/ui/skins_popup.gd")
const DailyPopupScript := preload("res://scripts/ui/daily_popup.gd")
const ChallengeSelectScript := preload("res://scripts/ui/challenge_select_popup.gd")
const LevelSelectScript := preload("res://scripts/ui/level_select_popup.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

# ============================================================
# COLORS
# ============================================================
const BG_COLOR := Color(0.12, 0.12, 0.12)
const BG_TOP := Color(0.08, 0.08, 0.12)     ## Dark blue-ish top
const BG_BOTTOM := Color(0.14, 0.10, 0.10)  ## Warm dark bottom

const PLAY_NORMAL := Color(0.18, 0.56, 0.18)
const PLAY_HOVER := Color(0.24, 0.66, 0.24)
const PLAY_PRESSED := Color(0.14, 0.46, 0.14)
const PLAY_BORDER := Color(0.92, 0.92, 0.92)

## Dark blue for secondary buttons
const SEC_NORMAL := Color(0.08, 0.12, 0.28, 0.92)
const SEC_HOVER := Color(0.12, 0.18, 0.38, 0.92)
const SEC_PRESSED := Color(0.05, 0.08, 0.20, 0.92)
const SEC_BORDER := Color(0.18, 0.28, 0.52)

const NOTIF_RED := Color(0.9, 0.15, 0.15)

## Paint splat decoration colors (game-themed)
const SPLAT_COLORS: Array[Color] = [
	Color(1.0, 0.8, 0.0, 0.06),   # Yellow (player)
	Color(0.9, 0.15, 0.15, 0.05), # Red
	Color(0.2, 0.6, 1.0, 0.05),   # Blue
	Color(0.1, 0.8, 0.3, 0.05),   # Green
	Color(0.8, 0.3, 0.9, 0.04),   # Purple
	Color(1.0, 0.5, 0.0, 0.04),   # Orange
]

# ============================================================
# LAYOUT — design values for 1920x1080 (scaled at runtime via _sf)
# ============================================================
const PLAY_WIDTH := 910
const PLAY_HEIGHT := 126
const PLAY_FONT_SIZE := 60
const PLAY_CORNER := 24
const PLAY_BORDER_W := 4

const SEC_WIDTH := 448
const SEC_HEIGHT := 106
const SEC_FONT_SIZE := 44
const SEC_CORNER := 18
const SEC_BORDER_W := 3
const GRID_H_GAP := 24
const GRID_V_GAP := 20

const LOGO_MAX_WIDTH := 615.0
const LOGO_TOP_MARGIN := 30.0
const PLAY_TO_GRID_GAP := 24.0

## Play popup — card-based mode selector
const MODE_CARD_W := 420
const MODE_CARD_H := 520
const MODE_CARD_GAP := 20
const MODE_CARD_CORNER := 20
const MODE_ICON_SIZE := 170
const MODE_TITLE_FONT := 52
const MODE_LABEL_FONT := 44
const MODE_CLOSE_W := 320
const MODE_CLOSE_H := 80
const MODE_CLOSE_FONT := 40
const MODE_CLOSE_CORNER := 16
const MODE_PANEL_PAD := 50
const LEVELS_COLOR := Color(0.15, 0.42, 0.95)
const ENDLESS_COLOR := Color(0.20, 0.55, 0.15)
const CHALLENGE_COLOR := Color(0.68, 0.45, 0.12)
const CLOSE_NORMAL := Color(0.82, 0.14, 0.14)
const CLOSE_HOVER := Color(0.92, 0.22, 0.22)
const CLOSE_PRESSED := Color(0.65, 0.10, 0.10)

# ============================================================
# SCALE FACTOR — viewport-relative sizing
# ============================================================
var _sf: float = 1.0  ## min(vp.x/1920, vp.y/1080)

## Scale a design-time pixel value to the current viewport.
func _s(v: float) -> int:
	return maxi(1, int(v * _sf))

# ============================================================
# NODE REFERENCES
# ============================================================
var _fade_overlay: ColorRect
var _video_player: VideoStreamPlayer
var _play_btn: Button
var _daily_btn: Button
var _stats_btn: Button
var _skins_btn: Button
var _settings_btn: Button
var _version_label: Label
var _daily_badge: Panel            ## blinking "FREE" badge when a free box spin is available
var _daily_badge_tw: Tween
var _daily_free_last: int = -1     ## cached free-box state (0/1) so we only refresh on change
var _daily_badge_timer: float = 0.0
var _stats_popup: StatsPopup
var _settings_popup: SettingsPopup
const InfoPopupScript := preload("res://scripts/ui/info_popup.gd")
var _info_popup: CanvasLayer   ## InfoPopup (preload — class cache needs an editor scan)
var _skins_popup: Node  ## SkinsPopup (instanced from SkinsPopupScript)
var _daily_popup: Node  ## DailyPopup (instanced from DailyPopupScript)
var _challenge_popup: Node  ## ChallengeSelectPopup (instanced from ChallengeSelectScript)
var _levels_popup: Node     ## LevelSelectPopup (instanced from LevelSelectScript)
var _play_popup_overlay: ColorRect
var _endless_btn: Button
var _challenge_btn: Button
var _levels_btn: Button
var _play_popup_panel: PanelContainer
var _play_popup_splats: Control   ## decorative paint splats around the mode panel
var _close_btn: Button
var _logo: TextureRect
var _particle_container: Control
var _play_row: HBoxContainer   ## Row wrapping play button (for entrance anim)
var _grid_row: HBoxContainer   ## Row wrapping secondary grid (for entrance anim)

var _lilita: Font
var _caveat: Font

var _is_transitioning: bool = false
var _popup_tween: Tween

# ---- SPLAT TEXTURES (loaded once) ----
var _splat_textures: Array[Texture2D] = []

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_sf = SaveManager.ui_sf(vp)
	_load_fonts()
	_load_splat_textures()
	_build_background()
	_build_decorative_splats()
	_build_video_player()
	_build_floating_particles()
	_build_bg_monsters()
	_build_version_label()   # BEFORE the buttons so any overlap lets the button win the click
	_build_info_button()     # bottom-left "?" → info popup (which holds the privacy links)
	_build_buttons()
	_build_stats_popup()
	_build_settings_popup()
	_build_info_popup()
	_build_skins_popup()
	_build_daily_popup()
	_build_challenge_popup()
	_build_levels_popup()
	_build_play_popup()
	_build_fade_overlay()

	# Entrance animations (staggered)
	_animate_entrance()

	# Achievement: unlock 5 skins (checked here since it's a non-gameplay milestone)
	if SaveManager.get_owned_skins().size() >= 5:
		AchievementManager.unlock("game_unlock5skins")
	# Collection achievement: own every skin + trail ("Full Wardrobe").
	AchievementManager.check_collection_achievements()
	# Challenge achievements (also retroactive — challenges completed before these
	# achievements existed still count).
	AchievementManager.check_challenge_achievements()

	# Fade in from black
	_fade_overlay.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT)

	# Player just beat the level that unlocks the finale (29 → 30): open the level select
	# and play the unlock reveal once we've faded in.
	if GameManager.pending_unlock_level > 0:
		var unlock_lvl := GameManager.pending_unlock_level
		GameManager.pending_unlock_level = 0
		tw.tween_callback(func() -> void: _show_level_unlock(unlock_lvl))
	# Backed out of a challenge / numbered level via MENU → reopen the selector they launched
	# from, instead of dumping them on the bare main menu.
	elif GameManager.pending_menu_popup != "":
		var which := GameManager.pending_menu_popup
		GameManager.pending_menu_popup = ""
		tw.tween_callback(func() -> void:
			if which == "challenges" and _challenge_popup:
				_challenge_popup.show_popup()
			elif which == "levels" and _levels_popup:
				_levels_popup.show_popup())

	# Background music — fresh random menu track each time we land on the menu
	# (app launch or returning from a run). Persists across submenu popups.
	AudioManager.play_menu_music()

func _load_fonts() -> void:
	_lilita = UIT.load_font()
	var caveat_path := "res://assets/fonts/Caveat-Regular.ttf"
	if ResourceLoader.exists(caveat_path):
		_caveat = load(caveat_path)

func _load_splat_textures() -> void:
	for i in range(1, 6):
		var path := "res://assets/sprites/effects/paint_splats/splat_mask_%02d.svg" % i
		if ResourceLoader.exists(path):
			_splat_textures.append(load(path))

# ============================================================
# BACKGROUND — gradient
# ============================================================

func _build_background() -> void:
	# Base dark color
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Gradient overlay (top-to-bottom subtle shift)
	var gradient_shader := "
shader_type canvas_item;
uniform vec4 color_top : source_color;
uniform vec4 color_bottom : source_color;
void fragment() {
	COLOR = mix(color_top, color_bottom, UV.y);
}
"
	var shader := Shader.new()
	shader.code = gradient_shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_top", BG_TOP)
	mat.set_shader_parameter("color_bottom", BG_BOTTOM)

	var gradient := ColorRect.new()
	gradient.name = "GradientOverlay"
	gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gradient.material = mat
	add_child(gradient)

	# Subtle radial vignette (darker edges)
	var vignette_shader := "
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 1.4;
	float vignette = smoothstep(0.3, 1.1, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * 0.35);
}
"
	var v_shader := Shader.new()
	v_shader.code = vignette_shader
	var v_mat := ShaderMaterial.new()
	v_mat.shader = v_shader

	var vignette := ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.material = v_mat
	add_child(vignette)

func _build_video_player() -> void:
	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoBackground"
	_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.autoplay = true
	_video_player.loop = true
	_video_player.visible = false
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video_player)
	_video_player.finished.connect(_on_video_finished)

func _on_video_finished() -> void:
	if _video_player.stream:
		_video_player.play()

func set_background_video(stream: VideoStream) -> void:
	if _video_player:
		_video_player.stream = stream
		_video_player.visible = true
		_video_player.play()

# ============================================================
# DECORATIVE PAINT SPLATS — scattered on background
# ============================================================

func _build_decorative_splats() -> void:
	if _splat_textures.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size

	var container := Control.new()
	container.name = "DecoSplats"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# Scatter 10-14 splats across the background
	var count := randi_range(10, 14)
	for _i in count:
		var tex: Texture2D = _splat_textures[randi() % _splat_textures.size()]
		var splat := TextureRect.new()
		splat.texture = tex
		splat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		splat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		splat.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Random size (100-300px scaled)
		var sz := randf_range(100.0, 300.0) * _sf
		splat.size = Vector2(sz, sz)

		# Random position across the whole screen
		splat.position = Vector2(
			randf_range(-sz * 0.3, vp.x - sz * 0.7),
			randf_range(-sz * 0.3, vp.y - sz * 0.7)
		)

		# Random rotation
		splat.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
		splat.rotation = randf() * TAU

		# Random color from palette
		var col: Color = SPLAT_COLORS[randi() % SPLAT_COLORS.size()]
		splat.modulate = col

		container.add_child(splat)

# ============================================================
# FLOATING PARTICLES — small colored dots that drift slowly
# ============================================================

func _build_floating_particles() -> void:
	_particle_container = Control.new()
	_particle_container.name = "FloatingParticles"
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)

	var vp := get_viewport().get_visible_rect().size

	# 20 small floating dots
	for _i in 20:
		var dot := ColorRect.new()
		var dot_size := randf_range(3.0, 8.0) * _sf
		dot.size = Vector2(dot_size, dot_size)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Random color with low opacity
		var col: Color = SPLAT_COLORS[randi() % SPLAT_COLORS.size()]
		col.a = randf_range(0.08, 0.2)
		dot.color = col

		# Random start position
		var start_x := randf_range(0, vp.x)
		var start_y := randf_range(0, vp.y)
		dot.position = Vector2(start_x, start_y)

		_particle_container.add_child(dot)

		# Infinite float animation: random drift direction, loops
		_animate_floating_dot(dot, vp)

func _animate_floating_dot(dot: ColorRect, vp: Vector2) -> void:
	var duration := randf_range(8.0, 18.0)
	var drift_x := randf_range(-120.0, 120.0) * _sf
	var drift_y := randf_range(-80.0, 80.0) * _sf
	var target := dot.position + Vector2(drift_x, drift_y)
	target.x = fmod(target.x + vp.x, vp.x)
	target.y = fmod(target.y + vp.y, vp.y)

	var tw := dot.create_tween()
	tw.tween_property(dot, "position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_reset_floating_dot.bind(dot, vp))

func _reset_floating_dot(dot: ColorRect, vp: Vector2) -> void:
	var drift_x := randf_range(-120.0, 120.0) * _sf
	var drift_y := randf_range(-80.0, 80.0) * _sf
	var target := dot.position + Vector2(drift_x, drift_y)
	target.x = fmod(target.x + vp.x, vp.x)
	target.y = fmod(target.y + vp.y, vp.y)

	var duration := randf_range(8.0, 18.0)
	var tw := dot.create_tween()
	tw.tween_property(dot, "position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_reset_floating_dot.bind(dot, vp))

# ============================================================
# BACKGROUND MONSTERS (ambient — drift up across the screen, then despawn)
# ============================================================
const BG_MON_MAX := 5
const BG_MON_TYPES: Array = [
	MonsterTypes.Type.BASIC, MonsterTypes.Type.TANK, MonsterTypes.Type.SPEEDER,
	MonsterTypes.Type.BRUTE, MonsterTypes.Type.HEALER, MonsterTypes.Type.SPLITTER,
	MonsterTypes.Type.GHOST, MonsterTypes.Type.SPAWNER, MonsterTypes.Type.TANKBOMBER,
]
var _bg_monster_layer: Control
var _bg_monsters: Array = []     ## each: { node: Sprite2D, vel: Vector2, spin: float }
var _bg_mon_timer: float = 1.0

func _build_bg_monsters() -> void:
	_bg_monster_layer = Control.new()
	_bg_monster_layer.name = "BgMonsters"
	_bg_monster_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_monster_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_monster_layer)
	_bg_mon_timer = randf_range(0.4, 1.4)

func _process(delta: float) -> void:
	# Daily "FREE" badge: re-check the free-box state once a second (handles the
	# cooldown expiring or a box being opened) and refresh only when it flips.
	_daily_badge_timer -= delta
	if _daily_badge_timer <= 0.0:
		_daily_badge_timer = 1.0
		var f := 1 if SaveManager.can_open_box_free() else 0
		if f != _daily_free_last:
			_refresh_daily_badge()

	if _bg_monster_layer == null:
		return
	var vp := get_viewport().get_visible_rect().size
	# Occasionally spawn a new ambient monster (capped at BG_MON_MAX on screen).
	_bg_mon_timer -= delta
	if _bg_mon_timer <= 0.0:
		_bg_mon_timer = randf_range(1.8, 4.5)
		if _bg_monsters.size() < BG_MON_MAX:
			_spawn_bg_monster(vp)
	# Move them up; despawn once fully off the top.
	for i in range(_bg_monsters.size() - 1, -1, -1):
		var m: Dictionary = _bg_monsters[i]
		var node: Sprite2D = m["node"]
		if not is_instance_valid(node):
			_bg_monsters.remove_at(i)
			continue
		node.position += (m["vel"] as Vector2) * delta
		node.rotation += float(m["spin"]) * delta
		if node.position.y < -140.0 * _sf:
			node.queue_free()
			_bg_monsters.remove_at(i)

func _spawn_bg_monster(vp: Vector2) -> void:
	var type: int = BG_MON_TYPES[randi() % BG_MON_TYPES.size()]
	var tex: Texture2D = SpriteLoader.get_ghost_visible_texture() if type == MonsterTypes.Type.GHOST else SpriteLoader.get_monster_texture(type, 0)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	var target := randf_range(76.0, 120.0) * _sf
	var ts := tex.get_size()
	var sfac := target / maxf(ts.x, ts.y)
	spr.scale = Vector2(sfac, sfac)
	spr.modulate = Color(1, 1, 1, randf_range(0.5, 0.72))
	spr.position = Vector2(randf_range(target, vp.x - target), vp.y + target)
	_bg_monster_layer.add_child(spr)
	var speed := randf_range(55.0, 125.0) * _sf
	var drift := randf_range(-28.0, 28.0) * _sf
	_bg_monsters.append({
		"node": spr,
		"vel": Vector2(drift, -speed),
		"spin": randf_range(-0.4, 0.4),
	})

# ============================================================
# BUTTONS + LOGO — everything in one centered VBox
# ============================================================

func _build_buttons() -> void:
	# Single VBox: Logo + Play + Grid — all centered as one block
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Guaranteed side gutter (>=10px) so content never hugs the screen edges.
	vbox.offset_left = maxf(24 * _sf, 12.0)
	vbox.offset_right = -maxf(24 * _sf, 12.0)
	# Lift the centered block slightly so the empty space above ≈ below (the logo's
	# transparent top padding otherwise makes it read as bottom-heavy). Shrinking the
	# bottom by 2× moves the vertical center up by ~MENU_CONTENT_LIFT px.
	vbox.offset_bottom = -120.0 * _sf
	add_child(vbox)

	# ---- LOGO (inside the centered VBox) ----
	_build_logo_row(vbox)

	# ---- Spacer: logo → play ----
	var logo_spacer := Control.new()
	logo_spacer.custom_minimum_size = Vector2(0, PLAY_TO_GRID_GAP * _sf)
	logo_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(logo_spacer)

	# ---- PLAY BUTTON ----
	_build_play_button(vbox)

	# ---- Spacer: play → grid ----
	var grid_spacer := Control.new()
	grid_spacer.custom_minimum_size = Vector2(0, PLAY_TO_GRID_GAP * _sf)
	grid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(grid_spacer)

	# ---- SECONDARY GRID ----
	_build_secondary_grid(vbox)

## Logo inside the main VBox — centered horizontally, bobs within a wrapper.
func _build_logo_row(parent: VBoxContainer) -> void:
	var logo_tex: Texture2D = null
	var logo_path := "res://assets/sprites/ui/logo.png"
	if ResourceLoader.exists(logo_path):
		logo_tex = load(logo_path)

	var logo_w := LOGO_MAX_WIDTH * _sf
	var logo_h := logo_w * 0.55  # fallback aspect
	if logo_tex:
		var tex_size := logo_tex.get_size()
		if tex_size.x > 0:
			logo_h = logo_w * (tex_size.y / tex_size.x)

	# HBox row to center the logo horizontally inside the VBox
	var logo_row := HBoxContainer.new()
	logo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(logo_row)

	# Wrapper Control — gives the logo headroom for its bobbing animation
	var bob_room := 14.0 * _sf
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(logo_w, logo_h + bob_room)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_row.add_child(wrapper)

	# The logo TextureRect inside the wrapper
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = logo_tex
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.position = Vector2(0, bob_room * 0.5)
	_logo.size = Vector2(logo_w, logo_h)
	wrapper.add_child(_logo)

	# Gentle bobbing animation (up/down 6px over 3s, infinite loop)
	var base_y := _logo.position.y
	var bob_tw := _logo.create_tween().set_loops()
	bob_tw.tween_property(_logo, "position:y", base_y - 6.0 * _sf, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tw.tween_property(_logo, "position:y", base_y + 6.0 * _sf, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ============================================================
# PLAY BUTTON
# ============================================================

func _build_play_button(parent: Control) -> void:
	_play_row = HBoxContainer.new()
	_play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_play_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_play_row)

	_play_btn = Button.new()
	_play_btn.name = "PlayButton"
	_play_btn.text = Loc.t("play")
	_play_btn.custom_minimum_size = Vector2(PLAY_WIDTH * _sf, PLAY_HEIGHT * _sf)
	_style_play_button(_play_btn)
	_play_btn.pressed.connect(_on_play_pressed)
	_play_row.add_child(_play_btn)

func _style_play_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(PLAY_NORMAL, PLAY_BORDER, PLAY_CORNER, PLAY_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_stylebox(PLAY_HOVER, PLAY_BORDER, PLAY_CORNER, PLAY_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(PLAY_PRESSED, PLAY_BORDER, PLAY_CORNER, PLAY_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_stylebox(PLAY_NORMAL, PLAY_BORDER, PLAY_CORNER, PLAY_BORDER_W))

	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(PLAY_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_constant_override("outline_size", _s(8))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

# ============================================================
# SECONDARY GRID
# ============================================================

func _build_secondary_grid(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.name = "SecondaryGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", _s(GRID_H_GAP))
	grid.add_theme_constant_override("v_separation", _s(GRID_V_GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	const MM := "res://assets/sprites/ui/mainmenu/"
	_daily_btn = _create_secondary_button(Loc.t("daily"), _tex(MM + "rewards.png"))
	_stats_btn = _create_secondary_button(Loc.t("stats"), _tex(MM + "stats.png"))
	_skins_btn = _create_secondary_button(Loc.t("skins"), _tex(MM + "skins.png"))
	_settings_btn = _create_secondary_button(Loc.t("settings"), _tex(MM + "settings.png"))

	grid.add_child(_daily_btn)
	grid.add_child(_stats_btn)
	grid.add_child(_skins_btn)
	grid.add_child(_settings_btn)

	# Center the grid in parent
	_grid_row = HBoxContainer.new()
	_grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_row.add_child(grid)
	parent.add_child(_grid_row)

	# Blinking "FREE" badge on Daily (shown only when a free spin is available)
	_build_daily_badge(_daily_btn)

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _create_secondary_button(label: String, icon_tex: Texture2D = null) -> Button:
	var btn := Button.new()
	btn.name = label + "Button"
	btn.text = ""
	btn.custom_minimum_size = Vector2(SEC_WIDTH * _sf, SEC_HEIGHT * _sf)
	# NOTE: no clip_contents — the Daily "FREE" badge overhangs the top-right corner.
	_style_secondary_button(btn)

	# Split the button into thirds: text centered in the left 2/3, icon centered in the right 1/3.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_top = _s(6)
	row.offset_bottom = -_s(6)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	# Left 2/3 — label centered.
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = 2.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(SEC_FONT_SIZE))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", _s(7))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(lbl)

	# Right 1/3 — icon centered, fitting the area (aspect preserved).
	var img_area := Control.new()
	img_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_area.size_flags_stretch_ratio = 1.0
	img_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(img_area)
	if icon_tex:
		var img := TextureRect.new()
		img.texture = icon_tex
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.offset_left = _s(4)
		img.offset_right = -_s(8)
		img.offset_top = _s(6)
		img.offset_bottom = -_s(6)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_area.add_child(img)
	return btn

func _style_secondary_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(SEC_NORMAL, SEC_BORDER, SEC_CORNER, SEC_BORDER_W))
	btn.add_theme_stylebox_override("hover", _make_stylebox(SEC_HOVER, SEC_BORDER, SEC_CORNER, SEC_BORDER_W))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(SEC_PRESSED, SEC_BORDER, SEC_CORNER, SEC_BORDER_W))
	btn.add_theme_stylebox_override("focus", _make_stylebox(SEC_NORMAL, SEC_BORDER, SEC_CORNER, SEC_BORDER_W))

	# Same font as PLAY button (Lilita One)
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(SEC_FONT_SIZE))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_constant_override("outline_size", _s(7))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)

func _build_daily_badge(parent_btn: Button) -> void:
	var bw := 69.0 * _sf
	var bh := 27.0 * _sf
	_daily_badge = Panel.new()
	_daily_badge.name = "DailyFreeBadge"
	_daily_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_badge.custom_minimum_size = Vector2(bw, bh)
	_daily_badge.size = Vector2(bw, bh)
	# Top-right corner of the Daily button, overhanging slightly.
	_daily_badge.position = Vector2(SEC_WIDTH * _sf - bw + 22 * _sf, -bh * 0.42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = NOTIF_RED
	sb.set_corner_radius_all(_s(14))
	sb.border_color = Color(1, 1, 1, 0.92)
	sb.set_border_width_all(_s(2))
	sb.shadow_size = _s(4)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	_daily_badge.add_theme_stylebox_override("panel", sb)
	parent_btn.add_child(_daily_badge)

	var lbl := Label.new()
	lbl.text = Loc.t("free_spin")
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(14))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", _s(2))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_daily_badge.add_child(lbl)

	_refresh_daily_badge()

## Show + blink the badge only while a free box spin is available.
func _refresh_daily_badge() -> void:
	if _daily_badge == null:
		return
	var free := SaveManager.can_open_box_free()
	_daily_free_last = 1 if free else 0
	# Hide the "FREE" badge once every box-obtainable item is owned — a free spin would
	# then only yield duplicates, so advertising it as free is misleading.
	var show_badge := free and DailyPopupScript.has_box_rewards_left()
	_daily_badge.visible = show_badge
	if _daily_badge_tw and _daily_badge_tw.is_valid():
		_daily_badge_tw.kill()
	if show_badge:
		_daily_badge.pivot_offset = _daily_badge.size * 0.5
		_daily_badge_tw = _daily_badge.create_tween().set_loops()
		_daily_badge_tw.tween_property(_daily_badge, "scale", Vector2(1.13, 1.13), 0.5).set_trans(Tween.TRANS_SINE)
		_daily_badge_tw.tween_property(_daily_badge, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

# ============================================================
# VERSION LABEL
# ============================================================

## Small square "?" button in the BOTTOM-LEFT corner. Opens the same info/credits popup as the
## version text — that popup also holds the privacy-policy and ad-privacy (GDPR) links, so this
## is the reachable entry point Google Play requires without cluttering the menu.
func _build_info_button() -> void:
	var size := 72.0 * _sf
	var btn := Button.new()
	btn.name = "InfoButton"
	btn.text = "?"
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.grow_horizontal = Control.GROW_DIRECTION_END
	btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	btn.position = Vector2(26.0 * _sf, -(size + 26.0 * _sf))
	btn.size = Vector2(size, size)
	btn.custom_minimum_size = Vector2(size, size)
	if _lilita:
		btn.add_theme_font_override("font", _lilita)
	btn.add_theme_font_size_override("font_size", _s(38))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", _s(3))
	_style_secondary_button(btn)   # same dark-blue look as the other secondary buttons
	# The shared stylebox carries content margins (sized for wide text buttons); zero them here
	# or they'd inflate the height and the square would come out as a rectangle.
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var box: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
			box.content_margin_left = 0.0
			box.content_margin_right = 0.0
			box.content_margin_top = 0.0
			box.content_margin_bottom = 0.0
			btn.add_theme_stylebox_override(st, box)
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		if _info_popup:
			_info_popup.show_popup())
	add_child(btn)

func _build_version_label() -> void:
	_version_label = Label.new()
	_version_label.name = "VersionLabel"
	_version_label.text = "v 1.0"
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_version_label.position = Vector2(-140 * _sf, -48 * _sf)
	_version_label.size = Vector2(120 * _sf, 36 * _sf)
	if _lilita:
		_version_label.add_theme_font_override("font", _lilita)
	_version_label.add_theme_font_size_override("font_size", _s(22))
	_version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_version_label.add_theme_constant_override("outline_size", _s(2))
	_version_label.add_theme_color_override("font_outline_color", Color.BLACK)
	# Tappable: opens the info/credits popup (generous hit-area for touch).
	_version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_version_label.position = Vector2(-158 * _sf, -54 * _sf)
	_version_label.size = Vector2(150 * _sf, 46 * _sf)
	_version_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_version_label.gui_input.connect(_on_version_clicked)
	add_child(_version_label)

# ============================================================
# FADE OVERLAY
# ============================================================

func _build_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

# ============================================================
# HELPERS
# ============================================================

func _make_stylebox(bg_color: Color, border_color: Color, corner: int, border_w: int) -> StyleBoxFlat:
	return UIT.make_sb(_sf, bg_color, border_color, corner, border_w, 20.0, 12.0)

# ============================================================
# STATS POPUP
# ============================================================

func _build_stats_popup() -> void:
	_stats_popup = StatsPopup.new()
	_stats_popup.name = "StatsPopup"
	add_child(_stats_popup)
	_stats_btn.pressed.connect(_on_stats_pressed)

func _on_stats_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	if _stats_popup:
		_stats_popup.show_popup()

# ============================================================
# SKINS POPUP
# ============================================================

func _build_skins_popup() -> void:
	_skins_popup = SkinsPopupScript.new()
	_skins_popup.name = "SkinsPopup"
	add_child(_skins_popup)
	_skins_btn.pressed.connect(_on_skins_pressed)

func _on_skins_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	if _skins_popup:
		_skins_popup.show_popup()

# ============================================================
# DAILY REWARD POPUP
# ============================================================

func _build_daily_popup() -> void:
	_daily_popup = DailyPopupScript.new()
	_daily_popup.name = "DailyPopup"
	add_child(_daily_popup)
	_daily_btn.pressed.connect(_on_daily_pressed)
	_daily_popup.open_skins_requested.connect(_on_daily_go_to_skins)

func _build_challenge_popup() -> void:
	_challenge_popup = ChallengeSelectScript.new()
	_challenge_popup.name = "ChallengeSelectPopup"
	add_child(_challenge_popup)
	_challenge_popup.challenge_selected.connect(_on_challenge_selected)

func _build_levels_popup() -> void:
	_levels_popup = LevelSelectScript.new()
	_levels_popup.name = "LevelSelectPopup"
	add_child(_levels_popup)
	# MENU / outside-tap → back to the play popup; PLAY → launch (TODO: Level mode).
	_levels_popup.menu_requested.connect(_show_play_popup)
	_levels_popup.level_selected.connect(_on_level_selected)

func _on_daily_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	if _daily_popup:
		_daily_popup.show_popup()

func _on_daily_go_to_skins(category: String) -> void:
	if _skins_popup:
		_skins_popup.show_category(category)

# ============================================================
# SETTINGS POPUP
# ============================================================

func _build_settings_popup() -> void:
	_settings_popup = SettingsPopup.new()
	_settings_popup.name = "SettingsPopup"
	add_child(_settings_popup)
	_settings_btn.pressed.connect(_on_settings_pressed)

## Info / credits popup — opened by tapping the version text (bottom-right corner).
func _build_info_popup() -> void:
	_info_popup = InfoPopupScript.new()
	_info_popup.name = "InfoPopup"
	add_child(_info_popup)

func _on_version_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play_sfx("button_click_menu")
		if _info_popup:
			_info_popup.show_popup()

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	if _settings_popup:
		_settings_popup.show_popup()

# ============================================================
# ENTRANCE ANIMATIONS
# ============================================================

func _animate_entrance() -> void:
	# Logo: scale from 0 → 1 with overshoot
	if _logo:
		_logo.pivot_offset = _logo.size / 2.0
		_logo.scale = Vector2.ZERO
		var logo_tw := _logo.create_tween()
		logo_tw.tween_property(_logo, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.2)

	# Play button row: fade in (no position change — VBox manages layout)
	if _play_row:
		_play_row.modulate.a = 0.0
		var play_tw := _play_row.create_tween()
		play_tw.tween_property(_play_row, "modulate:a", 1.0, 0.4).set_delay(0.4)

	# Grid row: fade in slightly after play
	if _grid_row:
		_grid_row.modulate.a = 0.0
		var grid_tw := _grid_row.create_tween()
		grid_tw.tween_property(_grid_row, "modulate:a", 1.0, 0.4).set_delay(0.6)

	# Play button glow pulse (starts after entrance completes)
	_start_play_glow()

## Pulsing glow around the PLAY button — draws attention.
func _start_play_glow() -> void:
	if _play_btn == null:
		return
	# Use the play button's StyleBoxFlat shadow for a glow effect
	# We'll pulse the border color brightness
	var tw := create_tween().set_loops()
	tw.tween_method(_pulse_play_border, 0.0, 1.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(1.0)
	tw.tween_method(_pulse_play_border, 1.0, 0.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _pulse_play_border(t: float) -> void:
	if _play_btn == null:
		return
	# Lerp border color from normal white to bright green glow
	var base := PLAY_BORDER
	var glow := Color(0.5, 1.0, 0.5)
	var col := base.lerp(glow, t * 0.5)

	# Update all styleboxes
	for state_name: String in ["normal", "focus"]:
		var sb: StyleBoxFlat = _play_btn.get_theme_stylebox(state_name) as StyleBoxFlat
		if sb:
			sb.border_color = col

# ============================================================
# ACTIONS
# ============================================================

func _on_play_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	_show_play_popup()

# ============================================================
# PLAY POPUP (mode selector: Endless / Challenge / Levels)
# ============================================================

func _build_play_popup() -> void:
	_play_popup_overlay = ColorRect.new()
	_play_popup_overlay.name = "PlayPopupOverlay"
	_play_popup_overlay.color = Color(0, 0, 0, 0.7)
	_play_popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_popup_overlay.visible = false
	add_child(_play_popup_overlay)

	_play_popup_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			AudioManager.play_sfx("button_click_menu")
			_hide_play_popup()
	)

	# Decorative paint splats scattered around the panel (behind it, over the dark dim).
	_play_popup_splats = Control.new()
	_play_popup_splats.name = "ModeSplats"
	_play_popup_splats.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_popup_splats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_popup_overlay.add_child(_play_popup_splats)
	_build_popup_splats(_play_popup_splats)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_popup_overlay.add_child(center)

	_play_popup_panel = PanelContainer.new()
	_play_popup_panel.name = "ModeSelectPanel"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.10, 0.10, 0.97)
	ps.set_corner_radius_all(_s(24))
	ps.set_border_width_all(_s(3))
	ps.border_color = Color(0.28, 0.28, 0.32)
	ps.shadow_size = _s(30)
	ps.shadow_color = Color(0, 0, 0, 0.55)
	ps.shadow_offset = Vector2(0, _s(10))
	ps.content_margin_left = _s(MODE_PANEL_PAD)
	ps.content_margin_right = _s(MODE_PANEL_PAD)
	ps.content_margin_top = _s(MODE_PANEL_PAD - 6)
	ps.content_margin_bottom = _s(MODE_PANEL_PAD)
	_play_popup_panel.add_theme_stylebox_override("panel", ps)
	center.add_child(_play_popup_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", _s(28))
	_play_popup_panel.add_child(main_vbox)

	# Title block: "SELECT MODE" + tri-color accent bar (ties the heading to the 3 modes)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", _s(12))
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(title_box)

	var title := Label.new()
	title.text = Loc.t("select_mode")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lilita:
		title.add_theme_font_override("font", _lilita)
	title.add_theme_font_size_override("font_size", _s(MODE_TITLE_FONT))
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", _s(6))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title_box.add_child(title)

	var accent_row := HBoxContainer.new()
	accent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	accent_row.add_theme_constant_override("separation", _s(8))
	accent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(accent_row)
	for ac: Color in [LEVELS_COLOR, ENDLESS_COLOR, CHALLENGE_COLOR]:
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(_s(70), _s(8))
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var seg_sb := StyleBoxFlat.new()
		seg_sb.bg_color = ac.lightened(0.12)
		seg_sb.set_corner_radius_all(_s(4))
		seg.add_theme_stylebox_override("panel", seg_sb)
		accent_row.add_child(seg)

	# Mode cards row
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", _s(MODE_CARD_GAP))
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(cards_row)

	var icon_dir := "res://assets/sprites/ui/modeselect/"
	_levels_btn = _create_mode_card(Loc.t("levels"), LEVELS_COLOR, icon_dir + "icon_levels.svg", "levels")
	_endless_btn = _create_mode_card(Loc.t("endless"), ENDLESS_COLOR, icon_dir + "icon_endless.svg", "endless")
	_challenge_btn = _create_mode_card(Loc.t("challenge"), CHALLENGE_COLOR, icon_dir + "icon_challenge.svg", "challenge")

	cards_row.add_child(_levels_btn)
	cards_row.add_child(_endless_btn)
	cards_row.add_child(_challenge_btn)

	_levels_btn.pressed.connect(_on_levels_pressed)
	_endless_btn.pressed.connect(_on_endless_pressed)
	_challenge_btn.pressed.connect(_on_challenge_pressed)

	# Bottom-center CLOSE button
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(close_row)

	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.text = Loc.t("close")
	_close_btn.custom_minimum_size = Vector2(MODE_CLOSE_W * _sf, MODE_CLOSE_H * _sf)
	var cborder := CLOSE_NORMAL.lightened(0.3)
	_close_btn.add_theme_stylebox_override("normal", _make_stylebox(CLOSE_NORMAL, cborder, MODE_CLOSE_CORNER, 3))
	_close_btn.add_theme_stylebox_override("hover", _make_stylebox(CLOSE_HOVER, cborder, MODE_CLOSE_CORNER, 3))
	_close_btn.add_theme_stylebox_override("pressed", _make_stylebox(CLOSE_PRESSED, cborder, MODE_CLOSE_CORNER, 3))
	_close_btn.add_theme_stylebox_override("focus", _make_stylebox(CLOSE_NORMAL, cborder, MODE_CLOSE_CORNER, 3))
	if _lilita:
		_close_btn.add_theme_font_override("font", _lilita)
	_close_btn.add_theme_font_size_override("font_size", _s(MODE_CLOSE_FONT))
	_close_btn.add_theme_color_override("font_color", Color.WHITE)
	_close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_close_btn.add_theme_constant_override("outline_size", _s(5))
	_close_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	_close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click_menu")
		_hide_play_popup()
	)
	close_row.add_child(_close_btn)

## Mode card: a themed illustration body (game monster/player sprites), a small corner
## icon (pin/clock/skull) and a darker bottom name-band. `mode` = levels/endless/challenge.
func _create_mode_card(label_text: String, bg_color: Color, corner_icon_path: String, mode: String) -> Button:
	var btn := Button.new()
	btn.name = label_text + "Card"
	btn.text = ""
	btn.custom_minimum_size = Vector2(_s(MODE_CARD_W), _s(MODE_CARD_H))
	btn.clip_contents = true

	var hover_c := bg_color.lightened(0.12)
	var press_c := bg_color.darkened(0.15)
	var rim := bg_color.lightened(0.4)   # bright rim for a glossier card edge

	# NO drop shadows: on the dark grey panel the black shadow pooled under the rounded
	# corners into ugly black "bends" — the area around the corners must stay clean grey.
	var sb_normal := _make_stylebox(bg_color, rim, MODE_CARD_CORNER, 3)
	var sb_hover := _make_stylebox(hover_c, bg_color.lightened(0.6), MODE_CARD_CORNER, 3)
	var sb_pressed := _make_stylebox(press_c, rim, MODE_CARD_CORNER, 3)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus", sb_normal)

	# ---- Glossy top sheen (under the art): a soft white wash on the upper part of the
	# card, so it reads like lit glass instead of a flat colour fill ----
	var gloss := Panel.new()
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_bottom = float(_s(MODE_CARD_H)) * 0.40
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1, 1, 1, 0.08)
	gsb.corner_radius_top_left = _s(MODE_CARD_CORNER)
	gsb.corner_radius_top_right = _s(MODE_CARD_CORNER)
	gloss.add_theme_stylebox_override("panel", gsb)
	btn.add_child(gloss)

	# ---- Illustration body: a single per-mode SVG, scaled to fit ----
	var art_files := {"levels": "levely2.svg", "endless": "endless2.svg", "challenge": "challenge2.svg"}
	var art_path := "res://assets/sprites/ui/modeselect/" + String(art_files.get(mode, ""))
	var band_h := float(_s(MODE_LABEL_FONT)) + float(_s(20))   # name strip = text + ~10px each side
	var band_gap := float(_s(20))                              # gap below the strip to the card edge
	# Per-mode idle timing offsets so the three cards never breathe in sync.
	var idle_dur: float = {"levels": 1.6, "endless": 1.85, "challenge": 2.1}.get(mode, 1.8)
	if ResourceLoader.exists(art_path):
		var illo := TextureRect.new()
		illo.texture = load(art_path)
		illo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illo.set_anchors_preset(Control.PRESET_FULL_RECT)
		illo.offset_left = float(_s(22))
		illo.offset_right = -float(_s(22))
		illo.offset_top = float(_s(22))
		illo.offset_bottom = -(band_gap + band_h + float(_s(14)))
		btn.add_child(illo)
		# Idle "alive" breathing: gentle rock + swell, looped forever (pivot set on layout).
		illo.resized.connect(func() -> void: illo.pivot_offset = illo.size / 2.0)
		var bob := illo.create_tween().set_loops()
		bob.tween_property(illo, "rotation", 0.022, idle_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.parallel().tween_property(illo, "scale", Vector2(1.03, 1.03), idle_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(illo, "rotation", -0.022, idle_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.parallel().tween_property(illo, "scale", Vector2.ONE, idle_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ---- Corner icon (pin / clock / skull), top-right — soft pulse ----
	if ResourceLoader.exists(corner_icon_path):
		var isz := float(_s(64))
		var ci := TextureRect.new()
		ci.texture = load(corner_icon_path)
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ci.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		ci.offset_left = -isz - _s(16)
		ci.offset_right = -float(_s(16))
		ci.offset_top = float(_s(16))
		ci.offset_bottom = isz + _s(16)
		ci.pivot_offset = Vector2(isz, isz) * 0.5
		btn.add_child(ci)
		var pulse := ci.create_tween().set_loops()
		pulse.tween_property(ci, "scale", Vector2(1.12, 1.12), idle_dur * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(ci, "scale", Vector2.ONE, idle_dur * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ---- Tactile press: the whole card squeezes down and springs back ----
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06).set_ease(Tween.EASE_OUT))
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

	# ---- Name strip: a darker band hugging just the label (+~10px top/bottom) ----
	var band := Panel.new()
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -(band_gap + band_h)
	band.offset_bottom = -band_gap
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_sb := StyleBoxFlat.new()
	band_sb.bg_color = bg_color.darkened(0.5)
	band.add_theme_stylebox_override("panel", band_sb)
	btn.add_child(band)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _lilita:
		lbl.add_theme_font_override("font", _lilita)
	lbl.add_theme_font_size_override("font_size", _s(MODE_LABEL_FONT))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", _s(5))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(lbl)

	return btn

## Scatter colorful paint splats around the mode panel (decorative, click-through).
func _build_popup_splats(holder: Control) -> void:
	if _splat_textures.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	var defs: Array = [
		[0.12, 0.20, LEVELS_COLOR,            240.0],
		[0.88, 0.16, CHALLENGE_COLOR,         260.0],
		[0.06, 0.60, ENDLESS_COLOR,           215.0],
		[0.94, 0.64, Color(0.85, 0.20, 0.62), 225.0],
		[0.17, 0.87, Color(0.18, 0.78, 0.88), 195.0],
		[0.83, 0.86, Color(0.97, 0.80, 0.15), 205.0],
	]
	for i in defs.size():
		var d: Array = defs[i]
		var tex: Texture2D = _splat_textures[i % _splat_textures.size()]
		var sz := float(_s(float(d[3])))
		var s := TextureRect.new()
		s.texture = tex
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.size = Vector2(sz, sz)
		s.pivot_offset = Vector2(sz, sz) * 0.5
		s.position = Vector2(float(d[0]) * vp.x - sz * 0.5, float(d[1]) * vp.y - sz * 0.5)
		s.rotation = randf_range(-0.6, 0.6)
		var col: Color = d[2]
		s.modulate = Color(col.r, col.g, col.b, 0.92)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(s)

func _show_play_popup() -> void:
	if not _play_popup_overlay:
		return
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_play_popup_overlay.visible = true
	_play_popup_overlay.color = Color(0, 0, 0, 0)
	if _play_popup_panel:
		_play_popup_panel.modulate.a = 0.0
		_play_popup_panel.scale = Vector2.ONE
	if _play_popup_splats:
		_play_popup_splats.modulate.a = 0.0
	call_deferred(&"_animate_popup_open")

func _animate_popup_open() -> void:
	if not _play_popup_overlay or not _play_popup_overlay.visible:
		return
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_play_popup_overlay, "color:a", 0.7, 0.25).set_ease(Tween.EASE_OUT)
	if _play_popup_panel:
		_play_popup_panel.pivot_offset = _play_popup_panel.size / 2.0
		_play_popup_panel.scale = Vector2(0.5, 0.5)
		_popup_tween.tween_property(_play_popup_panel, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_popup_tween.tween_property(_play_popup_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	# Cards pop in one after another (left → right) as the panel lands.
	var cards: Array = [_levels_btn, _endless_btn, _challenge_btn]
	for i in cards.size():
		var card: Button = cards[i]
		if card == null:
			continue
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.72, 0.72)
		card.modulate.a = 0.0
		var d := 0.10 + 0.08 * float(i)
		_popup_tween.tween_property(card, "scale", Vector2.ONE, 0.38) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(d)
		_popup_tween.tween_property(card, "modulate:a", 1.0, 0.20) \
			.set_ease(Tween.EASE_OUT).set_delay(d)
	if _play_popup_splats:
		_popup_tween.tween_property(_play_popup_splats, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func _hide_play_popup() -> void:
	if not _play_popup_overlay or not _play_popup_overlay.visible:
		return
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_play_popup_overlay, "color:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	if _play_popup_panel:
		_play_popup_panel.pivot_offset = _play_popup_panel.size / 2.0
		_popup_tween.tween_property(_play_popup_panel, "scale", Vector2(0.7, 0.7), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		_popup_tween.tween_property(_play_popup_panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	if _play_popup_splats:
		_popup_tween.tween_property(_play_popup_splats, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_IN)
	_popup_tween.chain().tween_callback(func() -> void:
		_play_popup_overlay.visible = false
	)

func _on_endless_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	AudioManager.play_sfx("button_click_menu")
	_hide_play_popup()
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_load_endless)

func _on_challenge_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	_hide_play_popup()
	if _challenge_popup:
		_challenge_popup.show_popup()

## A challenge was picked from the list → fade out and launch it.
func _on_challenge_selected(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		return
	GameManager.pending_custom_level = load(scene_path)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_load_challenge)

func _load_challenge() -> void:
	# game_world._ready picks up GameManager.pending_custom_level and starts that scene.
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

func _on_levels_pressed() -> void:
	AudioManager.play_sfx("button_click_menu")
	_hide_play_popup()
	if _levels_popup:
		_levels_popup.show_popup()

## Entry point after beating the level that unlocks a new one (currently only 29 → 30):
## open the level select straight onto that card and play its unlock reveal (padlock breaks
## + level30unlock sound). Falls back to a plain open if the level isn't actually unlocked.
func _show_level_unlock(level_num: int) -> void:
	_hide_play_popup()
	if _levels_popup:
		_levels_popup.show_with_unlock(level_num)

## A level was picked + PLAY pressed. Launches res://scenes/levels/level_<n>.tscn if it
## exists (level scenes are authored separately); otherwise it's a harmless no-op until
## that level is built.
func _on_level_selected(level_num: int) -> void:
	var path := "res://scenes/levels/level_%d.tscn" % level_num
	if not ResourceLoader.exists(path):
		return  # level not built yet — nothing to launch
	GameManager.pending_custom_level = load(path)
	if _levels_popup:
		_levels_popup.visible = false
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_load_challenge)

func _load_endless() -> void:
	GameManager.start_endless()
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")
