extends Node
## GameManager - Global game state singleton (Autoload)
## Converted from Menu.as game state + Game_Code_MC.as initialization.
## Manages game modes, pause, orientation, and global state.

signal game_state_changed(new_state: GameState)
signal orientation_changed(is_landscape: bool)

enum GameState {
	MAIN_MENU,
	LEVEL_SELECT,
	PLAYING_LEVEL,
	PLAYING_ENDLESS,
	PAUSED,
	RESULTS,
	COSMETICS,
	SETTINGS,
}

# ---- GLOBAL STATE ----
var state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU
var is_landscape: bool = true
var current_level: int = 1
var current_tier: int = 0
var elapsed_time: float = 0.0
var is_game_over: bool = false
var time_stopped: bool = false  ## Stoppill: freezes monsters + score timer only

## Set by the menu before loading game_world to launch a specific challenge/level scene
## (game_world._ready reads + clears it). null = normal endless/auto-start.
var pending_custom_level: PackedScene = null

## Set to a level number when the player beats the level that unlocks it (e.g. beating 29
## sets 30). On the next main-menu load the level select opens and plays that level's
## unlock animation + sound, then clears this. 0 = nothing pending.
var pending_unlock_level: int = 0

## Which selector the main menu should reopen on load: "challenges" | "levels" | "" (none).
## Set when the player backs out of a challenge / numbered level via MENU, so they land back in
## the list they launched from instead of the bare main menu. Cleared once it's been used.
var pending_menu_popup: String = ""

# ---- PLAYER SETTINGS (accessible globally) ----
var player_color: Color = Color(1.0, 0.8, 0.0)  # Yellow (0xFFCD00 from original)
var background_color: Color = Color(0.12, 0.12, 0.12)  # Dark grey (30,30,30)

# ---- GAME CONSTANTS ----
const TARGET_FPS := 60
const PHYSICS_FPS := 60
const MAX_PHYSICS_STEPS := 2  ## From original accumulator pattern: max 2 steps per frame

func _ready() -> void:
	# Lock to landscape (both ways) — the game is designed for phones held sideways.
	# Only on mobile (desktop display servers don't support orientation locking).
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	# Apply the FPS cap (the setting existed but was never applied — caused render-rate
	# vs physics-rate judder while the camera scrolls). 0 = uncapped.
	Engine.max_fps = int(SaveManager.get_setting("fps_limit", 60))
	# Detect orientation
	_check_orientation()
	get_tree().root.size_changed.connect(_on_window_resized)

	# Pause on app minimize (mobile critical)
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if state == GameState.PLAYING_LEVEL or state == GameState.PLAYING_ENDLESS:
				pause_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button
			if state == GameState.PAUSED:
				resume_game()
			elif state in [GameState.PLAYING_LEVEL, GameState.PLAYING_ENDLESS]:
				pause_game()
			elif state == GameState.MAIN_MENU:
				get_tree().quit()
			else:
				set_state(GameState.MAIN_MENU)

func _on_window_resized() -> void:
	_check_orientation()

func _check_orientation() -> void:
	var size := get_viewport().get_visible_rect().size
	var new_landscape := size.x > size.y
	if new_landscape != is_landscape:
		is_landscape = new_landscape
		orientation_changed.emit(is_landscape)

# ============================================================
# MOBILE HELPERS (safe-area insets + haptics)
# ============================================================

## Safe-area insets (notch / rounded corners / gesture bar) in canvas (1920x1080-base)
## units: x=left, y=top, z=right, w=bottom. Zero on platforms/devices without insets.
func get_safe_insets() -> Vector4:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return Vector4.ZERO
	var canvas: Vector2 = tree.root.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var sx := canvas.x / win.x
	var sy := canvas.y / win.y
	var l: float = maxf(0.0, float(safe.position.x)) * sx
	var t: float = maxf(0.0, float(safe.position.y)) * sy
	var r: float = maxf(0.0, win.x - float(safe.position.x + safe.size.x)) * sx
	var b: float = maxf(0.0, win.y - float(safe.position.y + safe.size.y)) * sy
	return Vector4(l, t, r, b)

## Short haptic buzz (ms), respecting the vibration setting. No-op on desktop.
func vibrate(ms: int) -> void:
	if bool(SaveManager.get_setting("vibration", true)):
		Input.vibrate_handheld(ms)

# ============================================================
# STATE MANAGEMENT
# ============================================================

func set_state(new_state: GameState) -> void:
	previous_state = state
	state = new_state
	game_state_changed.emit(new_state)

	match new_state:
		GameState.PAUSED:
			get_tree().paused = true
		GameState.MAIN_MENU:
			get_tree().paused = false
			elapsed_time = 0.0
			time_stopped = false
		_:
			get_tree().paused = false

func pause_game() -> void:
	if state in [GameState.PLAYING_LEVEL, GameState.PLAYING_ENDLESS]:
		set_state(GameState.PAUSED)

func resume_game() -> void:
	if state == GameState.PAUSED:
		set_state(previous_state)

func toggle_pause() -> void:
	if state == GameState.PAUSED:
		resume_game()
	elif state in [GameState.PLAYING_LEVEL, GameState.PLAYING_ENDLESS]:
		pause_game()

func start_level(level_num: int) -> void:
	current_level = level_num
	elapsed_time = 0.0
	is_game_over = false
	set_state(GameState.PLAYING_LEVEL)

func start_endless() -> void:
	elapsed_time = 0.0
	is_game_over = false
	set_state(GameState.PLAYING_ENDLESS)

func end_game() -> void:
	is_game_over = true
	set_state(GameState.RESULTS)

func _physics_process(delta: float) -> void:
	if state in [GameState.PLAYING_LEVEL, GameState.PLAYING_ENDLESS]:
		if not time_stopped:
			elapsed_time += delta
