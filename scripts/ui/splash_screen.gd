class_name SplashScreen
extends Control

## Publisher logo splash shown once at every app launch (the project's boot scene),
## then it advances to the main menu. It is NOT shown when starting a game from "Play".

const MENU_SCENE := "res://scenes/main.tscn"
const LOGO_TEX := "res://assets/sprites/ui/kompetlogo.svg"
const LOGO_SOUND := "res://assets/audio/intro/kompetlogosound.wav"

const TOTAL_TIME := 2.5   ## total time the logo is shown before the menu loads
const FADE_IN := 0.45
const FADE_OUT := 0.45
const BG_COLOR := Color("0d1b2a")   ## dark navy splash background

var _logo: TextureRect

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Fade backdrop — same navy as the logo's own background, only so the fade in/out
	# (and the moment before the texture loads) never flashes the default clear color.
	# The logo itself is authored at the full display size and covers the screen.
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Full-display logo (SVG authored at the whole 1920x1080 display).
	_logo = TextureRect.new()
	if ResourceLoader.exists(LOGO_TEX):
		_logo.texture = load(LOGO_TEX)
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	add_child(_logo)

	# Branding sound (own player so it isn't affected by the in-game SFX pitch system).
	if ResourceLoader.exists(LOGO_SOUND):
		var sp := AudioStreamPlayer.new()
		sp.stream = load(LOGO_SOUND)
		sp.bus = "Master"
		add_child(sp)
		sp.play()
		# Gentle fade-out starting at 2s — the clip is longer than the splash, so this
		# smooths the cut when the menu loads (this node is freed) at TOTAL_TIME.
		var afade := create_tween()
		afade.tween_interval(2.0)
		afade.tween_property(sp, "volume_db", -40.0, maxf(0.1, TOTAL_TIME - 2.0))

	# Fade in -> hold -> fade out to black, then load the menu (which fades in from black).
	var hold := maxf(0.0, TOTAL_TIME - FADE_IN - FADE_OUT)
	var tw := create_tween()
	tw.tween_property(_logo, "modulate:a", 1.0, FADE_IN).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_logo, "modulate:a", 0.0, FADE_OUT).set_ease(Tween.EASE_IN)
	tw.tween_callback(_go_to_menu)

func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
