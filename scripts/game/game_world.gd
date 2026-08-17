class_name GameWorld
extends Node2D
## GameWorld - Main gameplay scene controller.
## Manages player, monsters, bullets, floor paint, particles, HUD, joysticks.
## Connects all subsystems via signals. Root node for game_world.tscn.

# ---- SCENE REFERENCES (assigned in .tscn or via code) ----
@onready var player: Player = $Player
@onready var floor_paint: FloorPaint = $FloorPaint
@onready var particles: ParticleEffect = $ParticleEffect
@onready var spawner: MonsterSpawner = $MonsterSpawner
@onready var hud: HUD = $HUD
@onready var move_joystick: TouchJoystick = $UI/MoveJoystick
@onready var aim_joystick: TouchJoystick = $UI/AimJoystick
@onready var monster_container: Node2D = $MonsterContainer
@onready var bullet_container: Node2D = $BulletContainer

# ---- POWERUP SYSTEM ----
var _powerup_manager: PowerupManager
var _powerup_container: Node2D  ## Where pickup items are placed on map
var _cleaner_stamp_timer: float = 0.0  ## Rate-limit permanent paint erasure
const CLEANER_STAMP_INTERVAL := 0.05  ## Stamp every 50ms = permanent erasure

# ---- ITEM SYSTEM ----
var _item_manager: ItemManager
var _item_container: Node2D           ## Where item pickups are placed on map
var _inventory_ui: InventoryUI
var _grenade_scene: PackedScene
var _decoy_scene: PackedScene

# ---- CUSTOM LEVEL / CHALLENGE HOST ----
var _level_mode: bool = false           ## true while a hand-built level/challenge is running
var _numbered_level: bool = false       ## true only for numbered LEVELs (death → always respawn, never death screen)
# ---- No-death marathon streak (levels_inrowwithnodeath achievement) ----
const NODEATH_LAST_LEVEL := 30          ## the final boss level completes the marathon
var _streak_active: bool = false        ## a clean run from level 1 is in progress
var _streak_won: int = 0                ## highest level won consecutively without a death
var _level_deaths: int = 0              ## deaths in THIS level (5+ shows the skip-for-ad button)
var _respawn_tw: Tween = null           ## in-flight death-respawn tween (killed by a level skip)
var _level_layout: Node = null          ## instantiated level scene (walls/teleports/spawns…)
var _level_manager: Node = null         ## the level's LevelManager
var _current_level_scene: PackedScene = null  ## for Retry
@export var custom_level_scene: PackedScene   ## set + auto_start_mode="custom" to test a level
var _grenade_fired_this_frame: bool = false
var _decoy_fired_this_frame: bool = false
var _laser_fired_this_frame: bool = false
var _active_katana: KatanaSpin = null
var _katana_kill_count: int = 0  ## Kills during the current katana swing (for achievement)
var _active_shurikens: Array[ShurikenOrbit] = []  ## Two shurikens, 180° apart

# ---- LOOTCRATE SYSTEM ----
var _lootcrate_container: Node2D
var _lootcrate_spawn_timer: float = 0.0
var _endless_props_active: bool = false   ## endless-only prop spawner (lootcrates+metins); ON only in start_endless()
const PROP_SPAWN_CHANCE := 0.05        ## 5%/s — ONE roll shared by lootcrates + metins
const PROP_METIN_SHARE := 0.25         ## of successful rolls: 25% metin / 75% lootcrate
const LOOTCRATE_MAX := 2               ## Max crates on map at once
const METIN_MAX := 2                   ## Max metins on map at once (endless)
const LOOTCRATE_SPAWN_MARGIN := 80.0

# ---- SLOWPILL ----
var _slowpill_active: bool = false
var _slowpill_elapsed: float = 0.0
const SLOWPILL_DURATION := 8.0
const SLOWPILL_FADE_START := 6.0
const SLOWPILL_TIME_SCALE := 0.3

# ---- HIT-STOP (tiny freeze on big kills / katana) ----
var _hit_stop_active: bool = false
## Monster types that trigger a hit-stop when they die (the chunky/important ones).
const HIT_STOP_TYPES: Array = [MonsterTypes.Type.TANK, MonsterTypes.Type.BRUTE,
	MonsterTypes.Type.TANKBOMBER, MonsterTypes.Type.SPAWNER]

# ---- SPECIAL (HYBRID) MONSTERS ----
const SPECIAL_CHANCE := 0.05   ## 5% of every spawned monster becomes a hybrid
const SPECIAL_DONORS: Array = [MonsterTypes.Type.TANK, MonsterTypes.Type.SPEEDER,
	MonsterTypes.Type.BRUTE, MonsterTypes.Type.HEALER, MonsterTypes.Type.SPAWNER,
	MonsterTypes.Type.SPLITTER, MonsterTypes.Type.GHOST, MonsterTypes.Type.TANKBOMBER]
var _special_shader: Shader = null   ## lazily-built donor-colour tint shader (shared)

# ---- STOPPILL (time stop — flag-based, NOT Engine.time_scale) ----
var _stoppill_active: bool = false
var _stoppill_elapsed: float = 0.0
const STOPPILL_DURATION := 10.0
const STOPPILL_FADEIN_END := 1.0        ## 0→1s: monsters slow to frozen
const STOPPILL_FADEOUT_START := 8.0     ## 8→10s: monsters unfreeze
var _stoppill_overlay: ColorRect        ## Blue tint overlay for frozen effect

# ---- ACHIEVEMENT TRACKERS (reset each life in _reset_game) ----
var _body_kill_count: int = 0          ## monsters killed by ramming them with the player body
var _took_damage_this_life: bool = false  ## any HP loss this life (breaks the flawless achievement)
var _timeboost_life_time: float = 0.0  ## seconds spent inside timeboost zones this life
var _brute_check_timer: float = 0.0    ## throttle for the "3 charging brutes" scan
var _tankbomber_death_times: Array = []  ## msec timestamps of recent tankbomber deaths (chain achievement)

# ---- DEATH SCREEN ----
var _death_screen: DeathScreen
var _death_time: float = 0.0  ## Frozen elapsed time at moment of death
var _kill_count: int = 0      ## Total monsters killed this run
var _last_contact_monster_type: int = -1  ## Type of last monster to hit player (for "killed by" achievements)
var _color_distinction: float = 0.2  ## 0..1: how much darker floor splats are vs monsters (setting)
var _bg_lighten: ColorRect = null    ## white wash over the floor — alpha = bg_brightness setting (live)
var _enemy_projectile_speed_mult: float = 1.0  ## challenge modifier (Healer projectile speed)
var _dropped_below_10hp: bool = false  ## per-life: reached <=10 HP ("Back from the Brink")
var _player_on_paint: bool = false     ## last paint-check result (drives the smear shader)
var _last_game_gui_scale: float = 1.0  ## detects live game-GUI changes (settings Apply)

# ---- CHALLENGE GIMMICKS (blackout / shrinking arena / limited ammo) ----
var _default_fire_rate: float = 5.0      ## captured in _ready, restored in _reset_game
var _default_bullet_damage: float = 100.0
var _blackout_layer: CanvasLayer = null  ## darkness with a hole around the player
var _blackout_mat: ShaderMaterial = null
var _arena_inset: float = 0.0            ## shrinking-arena inset (px per side)
var _shrink_timer: float = 0.0
var _shrink_walls: Array = []            ## 4 black ColorRects covering the dead zone
var _ammo_out_timer: float = 0.0         ## grace timer before a limited-ammo run ends

# ---- RAGE (anti-camping, endless + challenges) ----
## Every RAGE_WINDOW seconds: if the player killed fewer than RAGE_MIN_KILLS monsters in
## that window AND at least RAGE_MIN_MONSTERS are alive, every currently-spawned monster
## gets +50% speed. Stacks each failing window (boosted monsters keep their boost).
const RAGE_WINDOW := 10.0
const RAGE_MIN_KILLS := 3
const RAGE_MIN_MONSTERS := 20
const RAGE_SPEED_MULT := 1.5
const RAGE_SPEED_CAP := 900.0   ## hard ceiling — stops speed from stacking to infinity
var _rage_timer: float = 0.0
var _rage_kills_in_window: int = 0

## Works in NORMALISED UV (0..1 across the full-rect ColorRect = the whole screen). It used to
## compare FRAGCOORD.xy (physical framebuffer pixels) against a canvas-unit centre — under the
## `canvas_items` stretch mode those are different spaces, so the hole drifted off the player
## and came out the wrong size on any window that isn't exactly the canvas resolution.
const BLACKOUT_SHADER := "
shader_type canvas_item;
uniform vec2 hole_center = vec2(-10.0, -10.0);  // 0..1 screen UV
uniform float hole_radius = 0.26;               // fraction of screen HEIGHT
uniform float edge_soft = 0.1;
uniform float aspect = 1.7777;                  // width / height — keeps the hole circular
void fragment() {
	vec2 d = UV - hole_center;
	d.x *= aspect;
	float a = smoothstep(hole_radius - edge_soft, hole_radius, length(d));
	COLOR = vec4(0.0, 0.0, 0.0, a * 0.965);
}
"
var _player_indicator  ## PlayerIndicator — accessibility ring around player (setting-toggled)

# ---- PAUSE MENU ----
var _pause_menu: PauseMenu

# ---- SCENE TEMPLATES (loaded once) ----
var _monster_scene: PackedScene
var _bullet_scene: PackedScene
var _enemy_bullet_tex: Texture2D = null  ## Healer projectile sprite (lazy-loaded)

# ---- ARENA ----
## The playfield is a FIXED logical size (1920x1080). A follow-camera shows a zoomed-in
## portion of it (see _setup_camera / game_zoom). arena_width/height mirror this.
const ARENA_W := 1920.0
const ARENA_H := 1080.0
@export var arena_width: float = 1920.0
@export var arena_height: float = 1080.0

var _camera: Camera2D = null   ## dynamic follow-camera, zoomed to the player
const ENDLESS_DECAL_PATH := "res://assets/sprites/effects/endlesarena.svg"  ## floor decal
const CHALLENGE_DECAL_PATH := "res://assets/sprites/effects/challengearena.svg"  ## challenge floor decal
var _endless_arena: Sprite2D = null  ## permanent "ENDLESS ARENA" floor watermark (endless only)
var _challenge_arena: Sprite2D = null  ## "CHALLENGE ARENA" floor watermark (challenges only)
var _level_void_bg: ColorRect = null ## near-black backdrop behind a LEVEL's floor (fills the void past the outer walls when the camera follows the player on a level bigger/smaller than the screen)
var _level_finishing: bool = false   ## true during the win shrink-into-portal animation (world frozen, timer stopped)
var _win_tween: Tween = null         ## the shrink-into-portal tween (killed on reset so it can't re-apply the portal position after Retry)

# ---- DEMO AUTOSTART ----
@export_enum("none", "endless", "level_1", "custom") var auto_start_mode: String = "endless"

# ---- ZONE SYSTEM ----
var _zone_manager: ZoneManager

# ---- PAINT DETECTION ----
var _paint_check_timer: float = 0.0
const PAINT_CHECK_INTERVAL := 0.1  # 10x/sec

# ---- AVOIDANCE ----
var _avoidance_timer: float = 0.0
const AVOIDANCE_INTERVAL := 0.1  # 10x/sec for monster-monster avoidance

# ---- KEYBOARD INPUT (PC demo) ----
var _keyboard_move: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.RIGHT  # Default facing direction
var _keyboard_moving: bool = false           # WASD keys are held
var _joystick_aiming: bool = false           # Aim joystick has non-zero input

# ---- SESSION TIME / STAT TRACKING ----
var _session_elapsed: float = 0.0    ## Accumulated real play time this session (not paused)
var _pending_bullets: int = 0        ## Bullet count waiting to be flushed to SaveManager

# ---- DEATH EFFECT (slowdown + greyscale) ----
var _death_effect_active: bool = false
var _death_effect_elapsed: float = 0.0
const DEATH_EFFECT_DURATION := 2.0
var _greyscale_layer: CanvasLayer
var _greyscale_rect: ColorRect

# ---- FADE OVERLAY ----
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _respawn_overlay: ColorRect   ## reusable fade for numbered-level death → respawn
var _level_respawning: bool = false

# ---- SCREEN SHAKE (offsets the GameWorld root; CanvasLayer UI/HUD stay fixed) ----
var _shake_strength: float = 0.0
const SHAKE_DECAY := 18.0            ## Strength units lost per second
const SHAKE_GRENADE := 2.5          ## Very light grenade pop
const SHAKE_GRENADE_FMJ := 4.0      ## Slightly stronger for FMJ (2x radius)
const SHAKE_PLAYER_HIT := 8.0       ## Strong bump when the player is hurt (clear "ouch" feedback)
const SHAKE_KILL := 0.9             ## Gentle rumble on a normal kill (juicy while mowing down)
const SHAKE_KILL_BIG := 2.2         ## Firmer punch when a chunky monster dies
const HIT_STOP_DURATION := 0.06     ## Tiny freeze on big kills / katana — "impact" feel

# ---- KILL-HEAT (rampage paint pooling) ----
## Coarse map of where kills recently happened; areas you fight in build a darker, bigger
## "rampage pool" of paint. Decays over a few seconds so fresh spots start clean again.
var _kill_heat: Dictionary = {}     ## Vector2i (coarse cell) -> accumulated recent kills
const KILL_HEAT_CELL := 150.0       ## px per heat cell
const KILL_HEAT_MAX := 6.0          ## kills to reach a full-depth pool
const KILL_HEAT_DECAY := 1.4        ## heat units lost per second

# ---- DAMAGE VIGNETTE ----
var _last_player_health: float = -1.0
var _vignette_layer: CanvasLayer
var _vignette_rect: ColorRect
var _vignette_mat: ShaderMaterial
var _vignette_tween: Tween
var _applying_zone_damage: bool = false  ## True while danger-zone DPS is being applied (suppresses hit shake/flash)
var _in_danger_zone: bool = false        ## True while the player stands in a danger zone
var _danger_vig_time: float = 0.0        ## Time accumulator for the sustained danger vignette pulse

func _ready() -> void:
	# Findable by level objects (e.g. exploding barrels call explode_at()).
	add_to_group("game_world")
	# Load scene templates
	_monster_scene = load("res://scenes/game/monster.tscn")
	_bullet_scene = load("res://scenes/game/bullet.tscn")
	_grenade_scene = load("res://scenes/game/grenade.tscn")
	_decoy_scene = load("res://scenes/game/decoy.tscn")

	# Fixed 1920x1080 playfield (the scene's walls are already authored for it).
	arena_width = ARENA_W
	arena_height = ARENA_H
	_update_wall_shapes()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Setup floor paint system
	floor_paint.setup(arena_width, arena_height, self)
	_setup_bg_lighten()

	# Setup particle system
	particles.setup(floor_paint, Rect2(0, 0, arena_width, arena_height))

	# Connect player signals
	player._game_world = self
	_default_fire_rate = player.fire_rate
	_default_bullet_damage = player.bullet_damage
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.score_changed.connect(_on_player_score_changed)

	# Setup PowerupManager
	_powerup_container = Node2D.new()
	_powerup_container.name = "PowerupContainer"
	add_child(_powerup_container)

	_powerup_manager = PowerupManager.new()
	_powerup_manager.name = "PowerupManager"
	_powerup_manager.powerup_activated.connect(_on_powerup_activated)
	_powerup_manager.powerup_deactivated.connect(_on_powerup_deactivated)
	_powerup_manager.powerup_timer_updated.connect(_on_powerup_timer_updated)
	add_child(_powerup_manager)

	# Setup ItemManager
	_item_container = Node2D.new()
	_item_container.name = "ItemContainer"
	add_child(_item_container)

	# Setup LootCrate container
	_lootcrate_container = Node2D.new()
	_lootcrate_container.name = "LootcrateContainer"
	add_child(_lootcrate_container)

	_item_manager = ItemManager.new()
	_item_manager.name = "ItemManager"
	_item_manager.inventory_changed.connect(_on_inventory_changed)
	_item_manager.item_selected.connect(_on_item_selected)
	add_child(_item_manager)

	# Inventory UI (added to HUD layer so it renders on top)
	_inventory_ui = InventoryUI.new()
	_inventory_ui.name = "InventoryUI"
	_inventory_ui.item_tapped.connect(_on_inventory_tapped)
	hud.add_child(_inventory_ui)

	# Connect joystick signals (left-handed mode swaps move/aim).
	var lefty := SaveManager.is_left_handed()
	if move_joystick:
		move_joystick.joystick_input.connect(_on_aim_joystick if lefty else _on_move_joystick)
	if aim_joystick:
		aim_joystick.joystick_input.connect(_on_move_joystick if lefty else _on_aim_joystick)
	# Tint the sticks by FUNCTION (follows the left-handed swap): the MOVE stick reads faintly
	# purple, the SHOOT stick faintly green — same transparency as before, just a hue.
	_tint_joystick(aim_joystick if lefty else move_joystick, Color(0.80, 0.68, 1.0))    # move → purple
	_tint_joystick(move_joystick if lefty else aim_joystick, Color(0.68, 1.0, 0.74))    # shoot → green

	# Setup ZoneManager
	_zone_manager = ZoneManager.new()
	_zone_manager.name = "ZoneManager"
	_zone_manager.setup(arena_width, arena_height)
	_zone_manager.zone_expired.connect(_on_zone_expired)
	add_child(_zone_manager)

	# Connect spawner signals
	spawner.monster_spawn_requested.connect(_on_monster_spawn_requested)
	spawner.level_started.connect(_on_level_started)
	spawner.level_completed.connect(_on_level_completed)
	spawner.wave_started.connect(_on_wave_started)

	# Apply player color from GameManager
	player.player_color = GameManager.player_color

	# Load player sprite
	_apply_player_sprite()

	# Accessibility settings
	_color_distinction = float(SaveManager.get_setting("color_distinction", 0.5))
	floor_paint.top_splat_darken = _color_distinction * 0.7
	_last_game_gui_scale = SaveManager.get_game_gui_scale()
	_setup_player_indicator()
	_setup_player_trail()

	# Position player at center
	player.global_position = Vector2(arena_width / 2.0, arena_height / 2.0)

	# Dynamic follow-camera (zoomed in on the player, clamped to the playfield)
	_setup_camera()

	# Permanent "ENDLESS ARENA" floor watermark (endless mode only)
	_setup_endless_arena()
	_setup_challenge_arena()

	# Initialize HUD
	hud.update_health(player.health, player.max_health)
	hud.update_score(0)

	# Register as the level host so level components can reach the spawn API.
	add_to_group("level_host")

	# A challenge/level scene chosen from the menu takes priority over auto_start_mode.
	if GameManager.pending_custom_level != null:
		var pending_scene: PackedScene = GameManager.pending_custom_level
		GameManager.pending_custom_level = null
		GameManager.start_endless()  # reuse the PLAYING state machine
		start_custom_level(pending_scene)
	else:
		# Auto-start demo mode (skip menu for testing)
		match auto_start_mode:
			"endless":
				GameManager.start_endless()
				start_endless()
			"level_1":
				GameManager.start_level(1)
				start_level(1)
			"custom":
				if custom_level_scene:
					GameManager.start_endless()  # reuse the PLAYING state machine
					start_custom_level(custom_level_scene)

	# Death screen (hidden until player dies)
	_death_screen = DeathScreen.new()
	_death_screen.name = "DeathScreen"
	_death_screen.retry_pressed.connect(_on_death_retry)
	_death_screen.menu_pressed.connect(_on_death_menu)
	_death_screen.next_level_pressed.connect(_on_next_level)
	add_child(_death_screen)

	# Pause menu (hidden until player taps timer)
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.resume_pressed.connect(_on_pause_resume)
	_pause_menu.menu_pressed.connect(_on_pause_menu)
	_pause_menu.settings_applied.connect(_on_settings_applied)
	add_child(_pause_menu)

	# Connect HUD pause signal (tap on timer)
	hud.pause_requested.connect(_on_pause_requested)
	hud.skip_requested.connect(_on_skip_level)

	# Ensure time_scale is normal on scene start (safety reset)
	Engine.time_scale = 1.0

	# Death greyscale overlay (hidden until player dies)
	_build_death_greyscale()

	# Fade in from black (smooth transition from main menu)
	_build_fade_overlay()

# ============================================================
# GAME START
# ============================================================

## Start a level mode game.
func start_level(level_num: int) -> void:
	_reset_game()
	hud.update_level(level_num)
	spawner.start_level_mode(level_num)
	AudioManager.play_game_music()

## Start an endless mode game.
func start_endless() -> void:
	_reset_game()
	_endless_props_active = true   # ONLY here — levels/challenges never spawn loose props
	if _endless_arena:
		_endless_arena.visible = true   ## permanent floor watermark, endless mode only
	hud.update_tier(-1)   ## Hide tier label; endless mode shows no tier
	hud.update_level(-1)  ## Hide level label too
	hud.set_endless_mode()  ## Hide score + paint bar for endless
	spawner.start_endless()
	AudioManager.play_game_music()
	# Start zone spawning
	_zone_manager.start()
	# Start powerup spawning
	_powerup_manager.start(arena_width, arena_height, _powerup_container)
	# Start item spawning
	_item_manager.start(arena_width, arena_height, _item_container)

# ============================================================
# CUSTOM LEVEL / CHALLENGE HOST
# ============================================================

## Load and start a hand-built level/challenge scene (one with a LevelManager root).
## All auto-spawning (endless waves, zones, powerups, items, lootcrates) is OFF — the
## level's own components drive everything.
func start_custom_level(scene: PackedScene) -> void:
	if scene == null:
		return
	_reset_game()
	_level_mode = true
	# Fresh level load (not a death-respawn) resets the per-level death counter + skip pill.
	if not _level_respawning:
		_level_deaths = 0
		if hud and hud.has_method("set_skip_visible"):
			hud.set_skip_visible(false)
	_current_level_scene = scene
	hud.update_tier(-1)
	hud.update_level(-1)
	hud.set_endless_mode()
	spawner.stop()   # no wave/endless spawning; the level controls spawns
	# Give the item manager its container so level item spawns work, but DON'T start it
	# (start() would enable random auto-spawning).
	if _item_manager:
		_item_manager._item_container = _item_container
	# (Re)load the layout. Instantiate FIRST and find the LevelManager so a numbered LEVEL
	# can size the playfield (+ paint canvas) BEFORE the layout enters the tree — ice tiles
	# stamp into the floor in their _ready(), so the canvas must already be the right size.
	if _level_layout and is_instance_valid(_level_layout):
		_level_layout.queue_free()
	_level_layout = scene.instantiate()
	_level_manager = _find_level_manager(_level_layout)
	var is_level: bool = _level_manager != null and int(_level_manager.level_number) > 0
	# The "CHALLENGE ARENA" floor watermark is for challenges only — never on numbered levels.
	if _challenge_arena:
		_challenge_arena.visible = not is_level
	if is_level:
		_setup_level_arena(_level_manager)
	# Guarantee a CLEAN floor on every (re)load — wipe any paint/splats from the previous
	# life. Done BEFORE add_child so the level's ice tiles (which stamp in _ready) survive.
	if floor_paint:
		floor_paint.clear()
	add_child(_level_layout)
	# Delayed bg repaint: covers any uninitialized render-target garbage ("ghost" ice/lootbox
	# texture on the floor) that survives the load-frame stamps. Ice re-stamps after it.
	if floor_paint and floor_paint.has_method("settle_repaint"):
		floor_paint.settle_repaint()
	if _level_manager:
		if not _level_manager.level_won.is_connected(_on_level_won):
			_level_manager.level_won.connect(_on_level_won)
		if not _level_manager.level_failed.is_connected(_on_level_failed):
			_level_manager.level_failed.connect(_on_level_failed)
		# Apply challenge modifiers (shrunk arena, no-shooting, faster shots) BEFORE begin()
		# so the level's spawners + the player land inside the (possibly shrunk) box.
		_apply_level_modifiers(_level_manager)
		_level_manager.begin(self, player)
	# A death-respawn KEEPS the music playing from the same timestamp (no restart); only a
	# fresh load starts a new track.
	if not _level_respawning:
		AudioManager.play_game_music()

## Apply a level's challenge modifiers to the host.
## Persist a challenge's best-of records (time / kills / targets) — only the metric that
## matches the challenge's star type is recorded.
func _save_challenge_record(lm: Node) -> Array:
	if lm == null or String(lm.challenge_id) == "":
		return ["", 0.0, 0.0, false]
	var field := ""
	var value := 0.0
	if bool(lm.stars_by_survival):
		field = "time"; value = float(lm.elapsed())
	elif bool(lm.stars_by_kills):
		field = "kills"; value = float(int(lm._kills))
	elif bool(lm.stars_by_targets):
		field = "targets"; value = float(int(lm._targets_done))
	if field == "":
		return ["", 0.0, 0.0, false]
	var cid := String(lm.challenge_id)
	var old_best := SaveManager.get_challenge_record(cid, field)
	var is_rec := value > old_best
	SaveManager.save_challenge_record(cid,
		value if field == "time" else -1.0,
		int(value) if field == "kills" else -1,
		int(value) if field == "targets" else -1)
	return [field, value, old_best, is_rec]

func _apply_level_modifiers(lm: Node) -> void:
	# Numbered LEVELs are always 1-HP with no HP bar (one hit = death → respawn). Forced
	# here so every level gets it without setting it per-scene.
	_numbered_level = int(lm.level_number) > 0
	if _numbered_level:
		lm.force_start_hp = 1.0
		lm.hide_hp_bar = true
		# Brief 0.3s spawn grace — invisible (the plain i-frame flag, NOT the invincibility
		# powerup) so the player isn't killed by an overlapping hazard/monster the instant
		# they (re)spawn into the level.
		if player:
			player.is_invulnerable = true
			player._invuln_timer = 0.3
			player._spawn_grace_timer = 1.0   # full hazard immunity so a nearby/moving saw or spike can't instantly re-kill on (re)spawn
		# Starting level 1 (fresh OR a death-respawn of level 1) arms a new no-death run. The menu
		# destroys this game_world (streak gone); only the NEXT-level path keeps it, a death breaks it.
		if int(lm.level_number) == 1:
			_streak_active = true
			_streak_won = 0
	_enemy_projectile_speed_mult = maxf(0.1, float(lm.enemy_projectile_speed_mult))
	if player:
		player.can_shoot = not bool(lm.disable_shooting)
		if float(lm.fire_rate_override) > 0.0:
			player.fire_rate = float(lm.fire_rate_override)
		if float(lm.bullet_damage_override) > 0.0:
			player.bullet_damage = float(lm.bullet_damage_override)
		player.ammo = int(lm.ammo_limit) if int(lm.ammo_limit) > 0 else -1
		player.level_speed_mult = maxf(0.1, float(lm.player_speed_mult))   # permanent speed boost (e.g. Sniper)
	if hud and hud.has_method("set_hp_gauge_visible"):
		hud.set_hp_gauge_visible(not bool(lm.hide_hp_bar))
	# Top-right slot repurpose ("ammo"/"targets" show there instead of the clock).
	hud.set_time_slot(String(lm.time_slot))
	# Limited-ammo counter — the separate left-side label is skipped when ammo lives in
	# the time slot (Zásobník).
	hud.set_ammo_visible(int(lm.ammo_limit) > 0 and String(lm.time_slot) != "ammo")
	if int(lm.ammo_limit) > 0:
		hud.update_ammo(int(lm.ammo_limit))
	if String(lm.time_slot) == "targets":
		hud.update_targets(0)
		if not lm.targets_changed.is_connected(hud.update_targets):
			lm.targets_changed.connect(hud.update_targets)
	# Totem challenge: each destroyed totem also speeds up every monster already on the map.
	if float(lm.get("monster_speedup_per_target")) > 0.0:
		if not lm.targets_changed.is_connected(_on_target_speedup):
			lm.targets_changed.connect(_on_target_speedup)
	# Endless-style powerup / item spawning inside a challenge (Řezník) — minus the ones
	# that would break a 1-HP run (HP Boost powerup, HP +25 item).
	if bool(lm.spawn_powerups) and _powerup_manager and _powerup_container:
		_powerup_manager.excluded_types = [Powerup.Type.HP_BOOST]
		_powerup_manager.start(arena_width, arena_height, _powerup_container)
	if bool(lm.spawn_items) and _item_manager and _item_container:
		_item_manager.excluded_types = [ItemPickup.ItemType.HP25]
		_item_manager.start(arena_width, arena_height, _item_container)
	_ammo_out_timer = 0.0
	# Kill counter (kill-scored challenges, e.g. Horda).
	hud.set_kill_counter_visible(bool(lm.show_kill_counter))
	if bool(lm.show_kill_counter):
		hud.update_kill_counter(0)
	# Darkness with a visibility circle around the player.
	if bool(lm.blackout):
		_setup_blackout()
	# Shrinking arena.
	_shrink_timer = 0.0
	# Normal endless monster spawning inside the challenge (optionally with the spawn
	# curve shifted forward, e.g. Miniaréna spawns as if 3 minutes in).
	if bool(lm.endless_spawning):
		spawner.start_endless()
		spawner.endless_time_offset = float(lm.endless_time_offset)
	Monster.healer_wander_mode = bool(lm.healer_wander)
	Monster.wander_all_mode = bool(lm.monsters_wander)
	Monster.wander_detect_radius = float(lm.wander_detect_radius)
	# Arena override = CHALLENGE shrink path (clamp camera, centre the player). Numbered
	# LEVELs size their (possibly larger) arena earlier in _setup_level_arena() with an
	# UNCLAMPED follow-camera, so skip this block for them.
	var aw: float = float(lm.arena_width_override)
	var ah: float = float(lm.arena_height_override)
	if aw > 0.0 and ah > 0.0 and int(lm.level_number) <= 0:
		arena_width = aw
		arena_height = ah
		_update_wall_shapes()
		_apply_arena_bounds()
		if player:
			player.global_position = Vector2(arena_width * 0.5, arena_height * 0.5)
			if _camera and is_instance_valid(_camera):
				_camera.global_position = player.global_position
				_camera.reset_smoothing()

	# Bounds the Healers wander within (after the arena size is finalized).
	Monster.wander_bounds = Rect2(0.0, 0.0, arena_width, arena_height)
	# Center the challenge watermark in the (possibly shrunk) arena.
	if _challenge_arena:
		_challenge_arena.global_position = Vector2(arena_width * 0.5, arena_height * 0.5)

## Re-clamp the camera + resize the background wash to the current arena size.
## NOTE: the shrinking-arena inset deliberately does NOT tighten the camera limits —
## a limit box smaller than the visible view makes Camera2D fight its clamps. The
## black shrink walls cover the dead zone visually instead.
func _apply_arena_bounds() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.limit_left = 0
		_camera.limit_top = 0
		_camera.limit_right = int(arena_width)
		_camera.limit_bottom = int(arena_height)
	if _bg_lighten:
		_bg_lighten.size = Vector2(arena_width, arena_height)

## Size the playfield for a hand-built numbered LEVEL (which may be LARGER or smaller than
## the default 1920x1080). Unlike a challenge's shrink (which clamps the camera), a level
## keeps the player dead-centre: the follow-camera runs UNCLAMPED, so you may see dark void
## past the level's outer walls — a near-black backdrop fills it. Called BEFORE the layout
## enters the tree so the paint canvas is correctly sized when ice tiles stamp in _ready().
func _setup_level_arena(lm: Node) -> void:
	var aw: float = float(lm.arena_width_override)
	var ah: float = float(lm.arena_height_override)
	if aw <= 0.0 or ah <= 0.0:
		return
	arena_width = aw
	arena_height = ah
	_arena_inset = 0.0
	_update_wall_shapes()
	if floor_paint and floor_paint.has_method("set_arena_size"):
		floor_paint.set_arena_size(arena_width, arena_height)
	# Death-paint particles (and the detail splats they bake into the floor) clamp to these
	# bounds — widen them to the whole level so decals aren't capped at 1920x1080.
	if particles:
		particles.setup(floor_paint, Rect2(0, 0, arena_width, arena_height))
	if _bg_lighten:
		_bg_lighten.size = Vector2(arena_width, arena_height)
	# Follow-camera with NO clamp → the player is always centred on screen.
	if _camera and is_instance_valid(_camera):
		var big := 100000000
		_camera.limit_left = -big
		_camera.limit_top = -big
		_camera.limit_right = big
		_camera.limit_bottom = big
		var start: Vector2 = lm.player_start_pos if lm.player_start_pos != Vector2.ZERO \
			else Vector2(arena_width * 0.5, arena_height * 0.5)
		_camera.global_position = start
		_camera.reset_smoothing()
	_ensure_level_void_bg()

## Near-black backdrop behind the level floor — fills the area the camera sees beyond the
## level's outer walls (the engine's grey clear colour would look broken there).
func _ensure_level_void_bg() -> void:
	if _level_void_bg == null or not is_instance_valid(_level_void_bg):
		_level_void_bg = ColorRect.new()
		_level_void_bg.name = "LevelVoidBg"
		_level_void_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_level_void_bg.color = Color(0.04, 0.04, 0.05)
		_level_void_bg.z_index = -50   # behind the painted floor (z=-10)
		add_child(_level_void_bg)
		move_child(_level_void_bg, 0)
	# Cover well past every edge (the camera centres on the player, so the visible void is
	# bounded by ~one screen past each side).
	var margin := 4000.0
	_level_void_bg.position = Vector2(-margin, -margin)
	_level_void_bg.size = Vector2(arena_width + margin * 2.0, arena_height + margin * 2.0)
	_level_void_bg.visible = true

func _clear_level_void_bg() -> void:
	if _level_void_bg and is_instance_valid(_level_void_bg):
		_level_void_bg.visible = false

func _find_level_manager(node: Node) -> Node:
	if node is LevelManager:
		return node
	for c in node.get_children():
		var r := _find_level_manager(c)
		if r:
			return r
	return null

# ---- Spawn API used by level components (via LevelManager.host) ----

## Totem challenge: a totem went down → speed up EVERY monster already on the map by the
## per-target fraction. New spawns pick up the bonus in level_spawn_monster (via
## target_speed_bonus), so both existing and future monsters end at the same ramped speed.
func _on_target_speedup(_done: int) -> void:
	if _level_manager == null:
		return
	var per := float(_level_manager.get("monster_speedup_per_target"))
	if per <= 0.0:
		return
	var f := 1.0 + per
	for m in monster_container.get_children():
		if m is Monster:
			(m as Monster).speed *= f

func level_spawn_monster(type: int, world_pos: Vector2, count: int = 1, spread: float = 40.0, spawn_anim: float = 0.0) -> void:
	# Optional per-level cap on how many monsters may be alive at once (e.g. Sniper = 15).
	var cap := 0
	if _level_manager and int(_level_manager.max_active_monsters) > 0:
		cap = int(_level_manager.max_active_monsters)
	for i in maxi(count, 1):
		if cap > 0 and get_tree().get_nodes_in_group("monsters").size() >= cap:
			return   # at the cap → skip the rest of this wave
		var off := Vector2.ZERO
		if count > 1:
			off = Vector2(CMath.rand(-spread, spread), CMath.rand(-spread, spread))
		var monster := _spawn_monster(type, world_pos + off, 0.0, 0)
		# Scale/fade-in spawn (e.g. Metin totems): grows from 0 with a short freeze.
		if monster and spawn_anim > 0.0 and monster.has_method("begin_spawn_anim"):
			monster.begin_spawn_anim(spawn_anim)
		if _level_manager:
			# Level-specific speed multiplier (e.g. faster grunts in "Horda" / "Totem"),
			# plus the accumulated per-totem speed bonus (Totem challenge) so freshly spawned
			# monsters immediately move at the current, ramped-up speed.
			if monster:
				var sp_mult := float(_level_manager.monster_speed_mult)
				if _level_manager.has_method("target_speed_bonus"):
					sp_mult *= float(_level_manager.target_speed_bonus())
				if sp_mult != 1.0:
					monster.speed *= sp_mult
			if _level_manager.has_method("notify_monster_spawned"):
				_level_manager.notify_monster_spawned()

func level_spawn_powerup(type: int, world_pos: Vector2) -> void:
	_spawn_powerup_at(world_pos, type)

func level_spawn_item(type: int, world_pos: Vector2) -> void:
	if _item_manager:
		_item_manager.spawn_item_type(type, world_pos)

func level_spawn_lootcrate(world_pos: Vector2, force_loot: int = -1) -> void:
	if _lootcrate_container == null:
		return
	var crate := LootCrate.new()
	crate.global_position = world_pos
	crate.forced_loot = force_loot   # -1 = random; else a LootCrate.LootType (0=item,1=powerup,2=rare)
	crate.destroyed.connect(_on_lootcrate_destroyed)
	_lootcrate_container.add_child(crate)

## Win — play the "shrink into the portal" animation first (world + timer frozen the instant
## the player touches the goal), then show the result screen.
func _on_level_won() -> void:
	if _level_finishing:
		return
	_level_finishing = true
	# A death in the same instant (boss finish blast, lingering monster) must never
	# reload the level underneath the result screen — cancel any in-flight respawn.
	if _respawn_tw and _respawn_tw.is_valid():
		_respawn_tw.kill()
		_respawn_tw = null
	_level_respawning = false
	# Freeze everything (monsters + the game timer tick) NOW; the player keeps animating
	# via an ignore-time-scale tween. The displayed time stops the moment the goal is hit.
	Engine.time_scale = 0.0
	if player:
		player.is_invulnerable = true         # no contact death mid-animation
		player.is_powerup_invincible = true   # also blocks zone/laser/piston damage until the
											  # result menu shows (cleared by respawn on retry/next)
	if _level_manager:
		hud.update_time(_level_manager.elapsed())
	var start_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var portal_pos: Vector2 = start_pos
	var exit_node := _find_level_exit()
	if exit_node:
		portal_pos = exit_node.global_position
	# Animate a THROWAWAY copy of the player into the portal — never the real player. A tween
	# on the real player can re-apply its end transform after the win-pause/Retry (player
	# stuck at the portal = instant re-win). The decoy sidesteps that entirely.
	var decoy := _make_player_decoy(start_pos)
	if player:
		player.visible = false
	# Win cue: fires the instant the fall-into-the-exit-portal animation starts (moved here
	# from the result screen's star pops). fixed_pitch — time_scale is 0 right now and a
	# slowpill could have the global SFX pitch lowered.
	AudioManager.play_sfx("box_click", 1.0, 0.0, true)
	var tw := create_tween().set_ignore_time_scale(true)
	_win_tween = tw
	if is_instance_valid(decoy):
		tw.tween_property(decoy, "global_position", portal_pos, 0.16).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(decoy, "scale", decoy.scale * 0.001, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)   # clean accelerating shrink to 0
	else:
		tw.tween_interval(0.5)
	tw.tween_callback(_finalize_level_won.bind(decoy))

## A non-interactive Sprite2D clone of the player (current skin) for the win shrink.
func _make_player_decoy(pos: Vector2) -> Node2D:
	if player == null:
		return null
	var src := player.get_node_or_null("Sprite2D") as Sprite2D
	if src == null or src.texture == null:
		return null
	var d := Sprite2D.new()
	d.texture = src.texture
	d.global_position = pos
	d.scale = src.global_scale
	d.rotation = src.global_rotation
	d.z_index = 6
	add_child(d)
	return d

func _find_level_exit() -> Node:
	if _level_layout == null or not is_instance_valid(_level_layout):
		return null
	var stack: Array = [_level_layout]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is LevelExit:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _finalize_level_won(decoy: Node = null) -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(decoy):
		decoy.queue_free()
	if player:
		player.visible = true
		player.scale = Vector2.ONE
	_win_tween = null
	GameManager.end_game()
	get_tree().paused = true
	_save_play_time()
	SaveManager.save_game()
	if _death_screen:
		var lname := "Level"
		var ldesc := ""
		var stars := -1
		var show_next := false     # green NEXT LEVEL button (numbered levels only)
		var final_time := -1.0     # numbered levels: completion time (count-up animation)
		var is_record := false     # green time when it's a new best
		var ch_rec: Array = ["", 0.0, 0.0, false]   # challenge: [field, value, old_best, is_record]
		if _level_manager:
			lname = _level_manager.level_name
			ldesc = _level_manager.description
			if _level_manager.challenge_id != "":
				stars = _level_manager.compute_stars()
				SaveManager.set_challenge_stars(_level_manager.challenge_id, stars)
				SaveManager.mark_challenge_complete(_level_manager.challenge_id)
				ch_rec = _save_challenge_record(_level_manager)
				AchievementManager.check_challenge_achievements()
			elif int(_level_manager.level_number) > 0:
				# Numbered Level-mode level: save best time + stars, unlock the next one.
				# On the WIN screen show only the star thresholds, not the mechanic blurb
				# (e.g. "Lasery + teleport + klíč z metinu") — the blurb stays on the level
				# select cards, it just doesn't clutter the completion result.
				var star_pos := ldesc.find("★")
				if star_pos >= 0:
					ldesc = ldesc.substr(star_pos)
				var lvl_n := int(_level_manager.level_number)
				stars = _level_manager.compute_stars()
				final_time = _level_manager.elapsed()
				var prev_best := SaveManager.get_level_time(lvl_n)
				is_record = prev_best <= 0.0 or final_time < prev_best
				SaveManager.save_level_result(lvl_n, final_time, stars)
				# NEXT LEVEL button only when a further level scene exists. The last level
				# (30) has no next → only Retry + Menu, and completing it unlocks the
				# "Level Conqueror" achievement (via check_level_achievements below).
				show_next = ResourceLoader.exists("res://scenes/levels/level_%d.tscn" % (lvl_n + 1))
				AchievementManager.check_level_achievements()   # complete-all + all-on-3-stars
				_advance_nodeath_streak(lvl_n)                   # flawless marathon streak
		_death_screen.show_challenge_result(true, lname, ldesc, stars, show_next, final_time, is_record, ch_rec[0], ch_rec[1], ch_rec[2], ch_rec[3])

## Advance the flawless no-death marathon after winning level `n`. Streak breaks on death
## (_on_player_died) or menu (game_world destroyed); winning the last built level completes it.
func _advance_nodeath_streak(n: int) -> void:
	if not _streak_active:
		return
	if n == _streak_won + 1:
		_streak_won = n
		if n >= NODEATH_LAST_LEVEL:
			AchievementManager.unlock("levels_inrowwithnodeath")   # grants the Skeleton skin
	elif n != _streak_won:
		_streak_active = false   # won a level out of the 1→2→3 order → run broken

func _on_level_failed() -> void:
	# Generic failure (non-death) — route through the normal death flow.
	if not player.is_dead:
		player.take_damage(999999.0)

func _reset_game() -> void:
	# Safety: clear any in-progress hit-stop (restore normal time).
	_hit_stop_active = false
	_endless_props_active = false   # endless prop spawner OFF; start_endless() turns it on
	if player:
		player.level_speed_mult = 1.0   # per-level permanent speed factor (challenges) — cleared each run
	_numbered_level = false   # re-set true by _apply_level_modifiers for numbered levels
	Engine.time_scale = 1.0
	# Kill the win shrink-into-portal tween. It's bound to this (pausable) node, so the
	# final win pause freezes it mid-finish; on Retry it would otherwise resume and re-apply
	# its end values (player at the portal → instant re-win). Kill it before begin() places
	# the player at the level start.
	if _win_tween:
		_win_tween.kill()
		_win_tween = null
	# Hide the floor watermarks (re-shown by start_endless / start_custom_level).
	if _endless_arena:
		_endless_arena.visible = false
	if _challenge_arena:
		_challenge_arena.visible = false
	# Stop powerup system
	if _powerup_manager:
		_powerup_manager.stop()
	hud.hide_powerup()

	# Stop item system
	if _item_manager:
		_item_manager.stop()
	# Clear any per-challenge spawn exclusions (Řezník sets them each run).
	if _powerup_manager:
		_powerup_manager.excluded_types = []
	if _item_manager:
		_item_manager.excluded_types = []

	# Stop zone system
	if _zone_manager:
		_zone_manager.stop()

	_slowpill_active = false
	_stoppill_active = false
	GameManager.time_stopped = false
	_hide_stoppill_overlay()
	_grenade_fired_this_frame = false
	_decoy_fired_this_frame = false
	_laser_fired_this_frame = false
	Monster.clear_lure_target()  # drop any stale decoy lure from a previous run
	if _active_katana and is_instance_valid(_active_katana):
		_active_katana.queue_free()
	_active_katana = null
	for sh in _active_shurikens:
		if sh and is_instance_valid(sh):
			sh.queue_free()
	_active_shurikens.clear()
	_lootcrate_spawn_timer = 0.0
	# Reset shake + damage-feedback state
	_shake_strength = 0.0
	position = Vector2.ZERO
	_last_player_health = -1.0
	_in_danger_zone = false
	_danger_vig_time = 0.0
	_applying_zone_damage = false
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("intensity", 0.0)
	_hide_vignette()

	# Clear existing entities
	for child in monster_container.get_children():
		child.queue_free()
	for child in bullet_container.get_children():
		child.queue_free()
	for child in _powerup_container.get_children():
		child.queue_free()
	if _item_container:
		for child in _item_container.get_children():
			child.queue_free()
	if _lootcrate_container:
		for child in _lootcrate_container.get_children():
			child.queue_free()
	# Metins from a PREVIOUS life: boss healing metins are parented directly to us (not to
	# a container), so the container sweeps above miss them. Without this they linger across
	# a level respawn as beam-less orphan metins that don't heal the new boss. Sweep by group
	# (covers any parent), now AND deferred (a dying boss may have a metin add still queued).
	_clear_metins()
	call_deferred("_clear_metins")
	# Dropped keys (from destroyed metins) live on the game_world root, not in the level
	# layout, so a reset would otherwise leave them lying around into the next life / level.
	_clear_dropped_keys()
	call_deferred("_clear_dropped_keys")
	floor_paint.clear()
	particles.clear()

	# Reset challenge modifiers + playfield to defaults (custom levels re-apply their own).
	if player:
		player.can_shoot = true
		player.fire_rate = _default_fire_rate
		player.bullet_damage = _default_bullet_damage
		player.ammo = -1
	hud.set_ammo_visible(false)
	hud.set_kill_counter_visible(false)
	_hide_blackout()
	_rage_timer = 0.0
	_rage_kills_in_window = 0
	_enemy_projectile_speed_mult = 1.0
	Monster.healer_wander_mode = false
	Monster.wander_all_mode = false
	if hud and hud.has_method("set_hp_gauge_visible"):
		hud.set_hp_gauge_visible(true)
	if not is_equal_approx(arena_width, ARENA_W) or not is_equal_approx(arena_height, ARENA_H) \
			or _arena_inset > 0.0:
		arena_width = ARENA_W
		arena_height = ARENA_H
		_arena_inset = 0.0
		_update_shrink_walls()
		_update_wall_shapes()
		_apply_arena_bounds()   # restores the camera clamp (a level may have unclamped it)
		if floor_paint and floor_paint.has_method("set_arena_size"):
			floor_paint.set_arena_size(ARENA_W, ARENA_H)
		if particles:
			particles.setup(floor_paint, Rect2(0, 0, ARENA_W, ARENA_H))
	_clear_level_void_bg()
	_level_finishing = false
	if player:
		player.scale = Vector2.ONE          # restore after a win-shrink animation
		player.visible = true               # the win decoy hid the real player
		player.is_invulnerable = false      # clear the win-animation invuln

	# Per-life achievement trackers — reset BEFORE player.respawn(): respawn emits
	# health_changed (full HP), and a stale flag from the previous life would otherwise
	# trigger a false unlock (e.g. "Back from the Brink" after a 1-HP challenge retry).
	_body_kill_count = 0
	_took_damage_this_life = false
	_dropped_below_10hp = false
	_timeboost_life_time = 0.0
	_brute_check_timer = 0.0
	_tankbomber_death_times.clear()

	# Reset player
	player.respawn(Vector2(arena_width / 2.0, arena_height / 2.0))
	player.score = 0
	player.score_changed.emit(0)
	_kill_count = 0
	_last_contact_monster_type = -1
	# Tear down any previous custom level. remove_child() FIRST so the old LevelManager
	# leaves the "level_manager" group immediately — otherwise (on Retry) the freshly
	# built level's spawners would register with the stale, queue_free()-pending manager
	# and never fire.
	_level_mode = false
	_level_manager = null
	_current_level_scene = null
	if _level_layout and is_instance_valid(_level_layout):
		remove_child(_level_layout)
		_level_layout.queue_free()
	_level_layout = null

# ============================================================
# ORIENTATION / VIEWPORT RESIZE
# ============================================================

## Create the follow-camera: zoomed to the player, smoothly trailing, hard-clamped to
## the playfield so you never see outside the 1920x1080 arena.
func _setup_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.queue_free()
	_camera = Camera2D.new()
	_camera.name = "GameCamera"
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(ARENA_W)
	_camera.limit_bottom = int(ARENA_H)
	# Rigid follow (no position smoothing): the camera updates in lockstep with the
	# player at the physics rate, so there's no render-rate "drift"/judder while the
	# camera scrolls. (Smoothing chased the target between physics ticks → choppy.)
	_camera.position_smoothing_enabled = false
	var z := SaveManager.get_game_zoom()
	_camera.zoom = Vector2(z, z)
	_camera.global_position = player.global_position if player else Vector2(ARENA_W * 0.5, ARENA_H * 0.5)
	add_child(_camera)
	_camera.make_current()
	_camera.reset_smoothing()

## Permanent "ENDLESS ARENA" floor watermark. A standalone Sprite2D (NOT part of the
## FloorPaint canvas) rendered just above the floor (z=-9, above the painted floor at
## z=-10) but below the player/monsters — so the Cleaner / Clean Sweep powerups can never
## erase it: it's a fixed part of the map. Faint (15%) and 3x smaller, centered.
func _setup_endless_arena() -> void:
	if not ResourceLoader.exists(ENDLESS_DECAL_PATH):
		return
	_endless_arena = Sprite2D.new()
	_endless_arena.name = "EndlessArenaWatermark"
	_endless_arena.texture = load(ENDLESS_DECAL_PATH)
	_endless_arena.centered = true
	_endless_arena.global_position = Vector2(ARENA_W * 0.5, ARENA_H * 0.5)
	_endless_arena.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)  # 3x smaller
	_endless_arena.modulate.a = 0.15                       # 15% opacity
	_endless_arena.z_index = -9   # above the painted floor (z=-10), below player/monsters
	_endless_arena.visible = false  # endless mode only
	add_child(_endless_arena)

## Same watermark for challenges ("CHALLENGE ARENA"), shown by start_custom_level.
func _setup_challenge_arena() -> void:
	if not ResourceLoader.exists(CHALLENGE_DECAL_PATH):
		return
	_challenge_arena = Sprite2D.new()
	_challenge_arena.name = "ChallengeArenaWatermark"
	_challenge_arena.texture = load(CHALLENGE_DECAL_PATH)
	_challenge_arena.centered = true
	_challenge_arena.global_position = Vector2(ARENA_W * 0.5, ARENA_H * 0.5)
	_challenge_arena.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	_challenge_arena.modulate.a = 0.15
	_challenge_arena.z_index = -9
	_challenge_arena.visible = false  # challenge mode only
	add_child(_challenge_arena)

## Monster/projectile speed factor derived from the camera zoom. Speeds are tuned for camera
## zoom 1.5; the default camera 2.2 ("1.7×") shows proportionally less look-ahead, so enemies
## slow — reaction time stays roughly constant. Zooming OUT never speeds them up (≤ 1.0).
func _reaction_speed_mult() -> float:
	# Full compensation would be 1.5/zoom. That felt too slow, so use the MEDIAN between the
	# full slow-down and the original speed (1.0).
	var full := 1.5 / SaveManager.get_game_zoom()
	return clampf((full + 1.0) * 0.5, 0.45, 1.0)

func _apply_game_zoom() -> void:
	if _camera and is_instance_valid(_camera):
		var z := SaveManager.get_game_zoom()
		_camera.zoom = Vector2(z, z)

## Update the four WorldBoundaryShape2D distances to match the current arena dimensions
## (including the shrinking-arena inset, which pushes every side inward).
func _update_wall_shapes() -> void:
	var walls_body: StaticBody2D = get_node_or_null("WallsBody")
	if walls_body == null:
		return

	# We have 4 CollisionShape2D children: WallTop, WallBottom, WallLeft, WallRight
	var wall_top: CollisionShape2D = walls_body.get_node_or_null("WallTop")
	var wall_left: CollisionShape2D = walls_body.get_node_or_null("WallLeft")
	var wall_bottom: CollisionShape2D = walls_body.get_node_or_null("WallBottom")
	var wall_right: CollisionShape2D = walls_body.get_node_or_null("WallRight")

	if wall_top and wall_top.shape is WorldBoundaryShape2D:
		(wall_top.shape as WorldBoundaryShape2D).distance = _arena_inset
	if wall_left and wall_left.shape is WorldBoundaryShape2D:
		(wall_left.shape as WorldBoundaryShape2D).distance = _arena_inset
	if wall_bottom and wall_bottom.shape is WorldBoundaryShape2D:
		(wall_bottom.shape as WorldBoundaryShape2D).distance = -(arena_height - _arena_inset)
	if wall_right and wall_right.shape is WorldBoundaryShape2D:
		(wall_right.shape as WorldBoundaryShape2D).distance = -(arena_width - _arena_inset)

func _on_viewport_size_changed() -> void:
	# The playfield is a fixed 1920x1080; the camera frames it, so there's nothing to
	# refit on resize/rotation. (Kept connected in case future logic needs it.)
	pass

func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100  ## Above everything
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	# Fade from black to transparent
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_fade_layer.queue_free)

## Build a full-screen greyscale overlay (shader-based desaturation).
## Sits on layer 45 — below DeathScreen (50) and PauseMenu (55).
func _build_death_greyscale() -> void:
	_greyscale_layer = CanvasLayer.new()
	_greyscale_layer.layer = 45
	_greyscale_layer.visible = false
	add_child(_greyscale_layer)

	_greyscale_rect = ColorRect.new()
	_greyscale_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_greyscale_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_res: Shader = load("res://assets/shaders/death_greyscale.gdshader") as Shader
	if shader_res:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("intensity", 0.0)
		_greyscale_rect.material = mat
	else:
		push_warning("GameWorld: death_greyscale.gdshader not found")

	_greyscale_layer.add_child(_greyscale_rect)

## Start the death effect: hide player, begin slowdown + greyscale.
func _start_death_effect() -> void:
	# Hide the entire player node (sprite + collision shape debug)
	player.visible = false

	# Activate greyscale overlay
	_greyscale_layer.visible = true

	# Start real-time tracking (driven by _process)
	_death_effect_active = true
	_death_effect_elapsed = 0.0
	Engine.time_scale = 1.0

## Fully restore game state: time_scale, greyscale, player visibility.
## Called only by retry / menu — NOT by on_player_death_complete.
func _stop_death_effect() -> void:
	_death_effect_active = false
	_slowpill_active = false
	_stoppill_active = false
	GameManager.time_stopped = false
	_hide_stoppill_overlay()
	Engine.time_scale = 1.0
	AudioManager.set_sfx_pitch(1.0)
	AudioManager.set_music_pitch(1.0)
	AudioManager.set_music_paused(false)
	get_tree().paused = false

	# Hide greyscale
	if _greyscale_layer:
		_greyscale_layer.visible = false
	if _greyscale_rect and _greyscale_rect.material:
		(_greyscale_rect.material as ShaderMaterial).set_shader_parameter("intensity", 0.0)

	# Restore player visibility
	player.visible = true

## Drives death slowdown + greyscale, or slowpill time effect.
## process_mode is default (PAUSABLE) so this stops when tree is paused.
func _process(delta: float) -> void:
	if _death_effect_active:
		_process_death_effect(delta)
		return
	if _stoppill_active:
		_process_stoppill(delta)
	elif _slowpill_active:
		_process_slowpill(delta)

func _process_death_effect(delta: float) -> void:
	var real_delta := minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	_death_effect_elapsed += real_delta
	var t := clampf(_death_effect_elapsed / DEATH_EFFECT_DURATION, 0.0, 1.0)
	# Slowdown: quadratic ease-in (fast at first, crawls to near-zero)
	Engine.time_scale = maxf((1.0 - t) * (1.0 - t), 0.01)
	# Greyscale intensity
	if _greyscale_rect and _greyscale_rect.material:
		(_greyscale_rect.material as ShaderMaterial).set_shader_parameter("intensity", t)

func _process_slowpill(delta: float) -> void:
	var real_delta := minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	_slowpill_elapsed += real_delta
	if _slowpill_elapsed >= SLOWPILL_DURATION:
		_deactivate_slowpill()
	elif _slowpill_elapsed >= SLOWPILL_FADE_START:
		# Lerp from slow-mo back to normal over the last 2 seconds
		var fade_t := (_slowpill_elapsed - SLOWPILL_FADE_START) / (SLOWPILL_DURATION - SLOWPILL_FADE_START)
		var new_scale := lerpf(SLOWPILL_TIME_SCALE, 1.0, fade_t)
		Engine.time_scale = new_scale
		AudioManager.set_sfx_pitch(new_scale)
		AudioManager.set_music_pitch(new_scale)   # music ramps back up with the world

# ============================================================
# PHYSICS LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		if position != Vector2.ZERO:
			position = Vector2.ZERO  # Clear any residual screen-shake offset
		return

	# Safety net: if the player is dead in a numbered level but no respawn is in flight,
	# auto-reset the level (covers any death path that didn't reach _on_player_died).
	if _numbered_level and player and player.is_dead and not _level_respawning:
		_respawn_level()
		return

	# Near-miss haptics: a light buzz when the player skims past a saw / extended piston.
	if _numbered_level and player and not player.is_dead:
		_nearmiss_scan_t -= delta
		_nearmiss_cd -= delta
		if _nearmiss_scan_t <= 0.0:
			_nearmiss_scan_t = 0.15
			if _nearmiss_cd <= 0.0 and _check_near_miss():
				_nearmiss_cd = 0.6
				GameManager.vibrate(15)

	_grenade_fired_this_frame = false
	_decoy_fired_this_frame = false
	_laser_fired_this_frame = false

	# Keyboard input (PC demo controls)
	_process_keyboard_input()

	# Update elapsed time display
	hud.update_time(GameManager.elapsed_time)

	# Paint detection for player slowdown
	_paint_check_timer += delta
	if _paint_check_timer >= PAINT_CHECK_INTERVAL:
		_paint_check_timer = 0.0
		_check_player_paint()

	# Monster-monster avoidance (batched for performance)
	_avoidance_timer += delta
	if _avoidance_timer >= AVOIDANCE_INTERVAL:
		_avoidance_timer = 0.0
		_compute_monster_avoidance()

	# Floor pickups shove each other apart so they can never stack / hide one another.
	_separate_pickups()

	# Active powerup effects
	_apply_powerup_effects(delta)

	# Zone effects
	_process_zone_effects(delta)

	# Check monster-player collisions (contact damage)
	_check_monster_player_collisions()

	# "Matador": 3+ Brutes charging at the same time (throttled scan)
	_brute_check_timer += delta
	if _brute_check_timer >= 0.25:
		_brute_check_timer = 0.0
		_check_charged_brutes()

	# Lootcrate spawn check
	_process_lootcrate_spawning(delta)

	# Challenge gimmicks: blackout follow, shrinking arena, limited-ammo run end
	if _level_mode and _level_manager:
		_process_challenge_modifiers(delta)

	# Rage (anti-camping): too few kills while the field is crowded → speed up monsters
	if not player.is_dead and not GameManager.time_stopped:
		_rage_timer += delta
		if _rage_timer >= RAGE_WINDOW:
			_rage_timer = 0.0
			if _rage_kills_in_window < RAGE_MIN_KILLS:
				_apply_rage_boost()
			_rage_kills_in_window = 0

	# Track session play time (saved on death/menu exit)
	_session_elapsed += delta

	# Time-based achievements (deduped by AchievementManager)
	_check_time_achievements()

	# Camera follow + screen-shake decay
	_update_camera(delta)

# ============================================================
# SPAWNING
# ============================================================

## Called by Bullet._fire_bullet() via player reference.
## True while the FMJ powerup is active — the player uses this to pick its shot sound.
func is_fmj_active() -> bool:
	return _powerup_manager != null and _powerup_manager.has_active(Powerup.Type.FMJ)

func is_freeze_active() -> bool:
	return _powerup_manager != null and _powerup_manager.has_active(Powerup.Type.SHOOT_FREEZE)

func spawn_bullet(pos: Vector2, dir: Vector2, spd: float, dmg: float, r: float, col: Color, secondary: bool = false) -> void:
	if not secondary:
		_pending_bullets += 1
	# Grenade intercept — if grenade is selected, fire grenade instead of bullet
	if _grenade_fired_this_frame:
		return  # Already fired grenade this frame, suppress remaining bullets
	# Challenge grenade mode (e.g. Horda): every shot throws a grenade (no item needed).
	if _level_mode and _level_manager and bool(_level_manager.grenade_mode):
		_fire_grenade(pos, dir)
		_grenade_fired_this_frame = true
		return
	if _item_manager and _item_manager.is_grenade_selected():
		_fire_grenade(pos, dir)
		_item_manager.consume_selected_grenade()
		_grenade_fired_this_frame = true
		return

	# Decoy intercept — if decoy is selected, throw decoy instead of bullet
	if _decoy_fired_this_frame:
		return
	if _item_manager and _item_manager.is_decoy_selected():
		_fire_decoy(pos, dir)
		_item_manager.consume_selected_decoy()
		_decoy_fired_this_frame = true
		return

	# Laser intercept — if laser is selected, fire laser instead of bullet
	if _laser_fired_this_frame:
		return  # Already fired laser this frame, suppress remaining bullets
	# Challenge laser mode (e.g. Sniper): every shot is a laser beam instead of a bullet.
	if _level_mode and _level_manager and bool(_level_manager.laser_mode):
		_fire_laser(pos, dir)
		_laser_fired_this_frame = true
		return
	if _item_manager and _item_manager.is_laser_selected():
		_fire_laser(pos, dir)
		_item_manager.consume_selected_laser()
		_laser_fired_this_frame = true
		return

	if _bullet_scene == null:
		return

	var has_fmj := _powerup_manager and _powerup_manager.has_active(Powerup.Type.FMJ)
	var has_octoshoot := _powerup_manager and _powerup_manager.has_active(Powerup.Type.OCTOSHOOT)
	var has_freeze := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_FREEZE)
	var has_bounce := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_BOUNCE)

	# Octoshoot: fire 8 bullets in all compass directions (only for primary bullets)
	if has_octoshoot and not secondary:
		for i in 8:
			var angle := i * (TAU / 8.0)
			var octo_dir := Vector2.from_angle(angle)
			var b: Bullet = _bullet_scene.instantiate() as Bullet
			b.setup(pos, octo_dir, spd, dmg, r, col, i > 0)  # First bullet is primary, rest secondary
			if has_fmj:
				b.is_fmj = true
			b.is_freeze = has_freeze
			b.is_bounce = has_bounce
			bullet_container.add_child(b)
			b.hit_monster.connect(_on_bullet_hit_monster)
			b.hit_wall.connect(_on_bullet_hit_wall)
			b.hit_crate.connect(_on_bullet_hit_crate)
		return

	var bullet: Bullet = _bullet_scene.instantiate() as Bullet
	bullet.setup(pos, dir, spd, dmg, r, col, secondary)

	# FMJ powerup — bullets pass through everything
	if has_fmj:
		bullet.is_fmj = true
	bullet.is_freeze = has_freeze
	bullet.is_bounce = has_bounce

	bullet_container.add_child(bullet)

	# Connect bullet signals
	bullet.hit_monster.connect(_on_bullet_hit_monster)
	bullet.hit_wall.connect(_on_bullet_hit_wall)
	bullet.hit_crate.connect(_on_bullet_hit_crate)

## Called by MonsterSpawner signal.
func _on_monster_spawn_requested(type: MonsterTypes.Type, pos: Vector2, elapsed_time: float, split_tier: int) -> void:
	_spawn_monster(type, pos, elapsed_time, split_tier)

func _spawn_monster(type: MonsterTypes.Type, pos: Vector2, elapsed_time: float = 0.0, split_tier: int = 0, special_donor: int = -1) -> Monster:
	if _monster_scene == null:
		return null
	var monster: Monster = _monster_scene.instantiate() as Monster
	monster.initialize(type, elapsed_time, split_tier)
	monster.global_position = pos

	# Some monsters are SPECIAL hybrids: base shape/movement + a random OTHER type's colour and
	# signature power. special_donor: -1 = roll SPECIAL_CHANCE; -2 = NEVER special (splitter
	# children); >=0 = forced donor (splitter-donor children stay splitter-hybrids).
	if special_donor == -1 and randf() < SPECIAL_CHANCE 	and not (_level_mode and not _numbered_level):   # no mutants in CHALLENGES
		special_donor = _pick_special_donor(type)
	if special_donor >= 0:
		monster.make_special(special_donor, split_tier)

	# Apply sprite from SpriteLoader (scales to radius, which make_special may have changed).
	# Reaction-time compensation: a closer camera (phone zoom) shows less look-ahead, so
	# monsters slow down by the same factor the world got bigger (tuned at zoom 1.5).
	monster.speed *= _reaction_speed_mult()

	_apply_monster_sprite(monster, type, split_tier)
	if monster.is_special:
		_apply_special_look(monster)

	# If stoppill active, tint new monster blue immediately (specials keep their shader tint).
	if _stoppill_active and not monster.is_special:
		var sprite: Sprite2D = monster.get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(0.4, 0.6, 1.0)

	# Connect signals
	monster.died.connect(_on_monster_died)
	monster.spawned_children.connect(_on_monster_spawned_children.bind(monster))
	if type == MonsterTypes.Type.HEALER or monster.special_type == MonsterTypes.Type.HEALER:
		monster.healed_pulse.connect(_on_healer_pulse)
		monster.fired_bullet.connect(_on_monster_fired_bullet)

	monster_container.add_child(monster)
	return monster

## Pick a random donor type for a special hybrid — any signature type except BASIC and the base.
func _pick_special_donor(base: MonsterTypes.Type) -> int:
	var pool: Array = []
	for t in SPECIAL_DONORS:
		if t != base:
			pool.append(t)
	return pool[randi() % pool.size()]

## Recolour a special monster's sprite to its donor colour (a flat tinted silhouette of the base
## shape) and, for Tankbomber donors, add a small black centre dot to tell it from the Brute.
func _apply_special_look(monster: Monster) -> void:
	var sprite: Sprite2D = monster.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	if _special_shader == null:
		# Recolour ONLY the coloured fill to the donor colour; keep the black outline (stroke)
		# intact. Fill pixels are saturated (high max component), the outline is ~black (max≈0).
		_special_shader = Shader.new()
		_special_shader.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV);\n\tfloat bright = max(max(t.r, t.g), t.b);\n\tfloat fill = smoothstep(0.18, 0.45, bright);\n\tvec3 rgb = mix(t.rgb, tint.rgb, fill);\n\tCOLOR = vec4(rgb, t.a * COLOR.a);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = _special_shader
	mat.set_shader_parameter("tint", monster.monster_color)
	sprite.material = mat
	if monster.special_type == MonsterTypes.Type.TANKBOMBER:
		var dot := Polygon2D.new()
		dot.color = Color(0.0, 0.0, 0.0, 1.0)
		var pts := PackedVector2Array()
		var rr: float = monster.radius * 0.34
		for i in 12:
			var a: float = TAU * float(i) / 12.0
			pts.append(Vector2(cos(a), sin(a)) * rr)
		dot.polygon = pts
		dot.z_index = 2
		monster.add_child(dot)

## Healer ranged attack: spawn a paint projectile flying toward the player.
## Sized to ~the healer's footprint so it stays hidden under the shooter on spawn.
func _on_monster_fired_bullet(from_pos: Vector2, dir: Vector2) -> void:
	if _enemy_bullet_tex == null:
		var path := "res://assets/sprites/enemies/healer_bullet.svg"
		if ResourceLoader.exists(path):
			_enemy_bullet_tex = load(path)
	if _enemy_bullet_tex == null:
		return

	var stats := MonsterTypes.STATS[MonsterTypes.Type.HEALER]
	var spd: float = stats.get("bullet_speed", 320.0) * _enemy_projectile_speed_mult
	var dmg_pct: float = stats.get("bullet_damage_percent", 0.10)
	var healer_radius: float = stats.get("radius", 32.0)
	# Slightly smaller than the healer's diameter so the whole sprite hides under it.
	# (25% smaller than the previous 1.7x footprint.)
	var diameter := healer_radius * 1.275

	var eb := EnemyBullet.new()
	eb.setup(from_pos, dir, spd * _reaction_speed_mult(), player.max_health * dmg_pct, _enemy_bullet_tex, diameter)
	bullet_container.add_child(eb)

## Public: spawn a generic enemy projectile (used by level turrets). `color` tints it,
## `diameter` sizes it. Reuses the Healer paint-blob sprite.
func spawn_enemy_projectile(pos: Vector2, dir: Vector2, speed: float, damage: float, diameter: float, color: Color = Color.WHITE, outlined: bool = false, hits_monsters: bool = false) -> void:
	var tex: Texture2D
	if outlined:
		tex = _get_outlined_ball_tex()   # white ball + black outline (turret shots)
	else:
		if _enemy_bullet_tex == null:
			var path := "res://assets/sprites/enemies/healer_bullet.svg"
			if ResourceLoader.exists(path):
				_enemy_bullet_tex = load(path)
		tex = _enemy_bullet_tex
	if tex == null:
		return
	var eb := EnemyBullet.new()
	eb.setup(pos, dir, speed * _reaction_speed_mult(), damage, tex, diameter)
	eb.hits_monsters = hits_monsters   # turret shots hurt monsters too; healer shots never
	eb.modulate = color
	bullet_container.add_child(eb)

var _outlined_ball_tex: GradientTexture2D = null
## White disc with a black outline ring (hard gradient stops), used by turret bullets.
func _get_outlined_ball_tex() -> Texture2D:
	if _outlined_ball_tex == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.offsets = PackedFloat32Array([0.0, 0.70, 0.97])
		g.colors = PackedColorArray([Color.WHITE, Color.BLACK, Color(0, 0, 0, 0)])
		_outlined_ball_tex = GradientTexture2D.new()
		_outlined_ball_tex.gradient = g
		_outlined_ball_tex.fill = GradientTexture2D.FILL_RADIAL
		_outlined_ball_tex.fill_from = Vector2(0.5, 0.5)
		_outlined_ball_tex.fill_to = Vector2(1.0, 0.5)
		_outlined_ball_tex.width = 64
		_outlined_ball_tex.height = 64
	return _outlined_ball_tex

func _apply_monster_sprite(monster: Monster, type: MonsterTypes.Type, split_tier: int) -> void:
	var sprite: Sprite2D = monster.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	# Ghost starts visible (purple); its _think_ghost() will swap to grey when phasing out
	var tex: Texture2D
	if type == MonsterTypes.Type.GHOST:
		tex = SpriteLoader.get_ghost_visible_texture()
	else:
		tex = SpriteLoader.get_monster_texture(type, split_tier)
	if tex:
		sprite.texture = tex
		# Scale sprite to match monster radius (sprite has own colors - no modulate)
		var tex_size := tex.get_size()
		var target_diameter := monster.radius * 2.0
		var scale_factor := target_diameter / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
	# Sprites have their own colors; only Ghost uses alpha-based modulate (set in monster._think_ghost)

## Equipped trail that follows the player (skips "none" / missing texture).
const PlayerTrailScript := preload("res://scripts/game/player_trail.gd")
const SparkTrailScript := preload("res://scripts/game/spark_trail.gd")
const TrailDataRes := preload("res://scripts/data/trail_data.gd")
var _player_trail
func _setup_player_trail() -> void:
	if _player_trail and is_instance_valid(_player_trail):
		_player_trail.queue_free()
		_player_trail = null
	var trail_id: String = SaveManager.get_equipped_trail()
	if not SaveManager.is_trail_owned(trail_id):
		trail_id = "none"  # never render a trail the player doesn't own
	var path: String = TrailDataRes.texture_path(trail_id)
	if path == "" or not ResourceLoader.exists(path):
		return
	var trail
	if TrailDataRes.get_style(trail_id) == "spark":
		trail = SparkTrailScript.new()   # popping spark sprites
	else:
		trail = PlayerTrailScript.new()  # stretched ribbon
	trail.name = "PlayerTrail"
	add_child(trail)
	trail.setup(player, load(path))
	_player_trail = trail

## Create the accessibility ring around the player; visibility from the setting.
const PlayerIndicatorScript := preload("res://scripts/game/player_indicator.gd")
func _setup_player_indicator() -> void:
	if _player_indicator and is_instance_valid(_player_indicator):
		_player_indicator.queue_free()
	var ind = PlayerIndicatorScript.new()
	ind.name = "PlayerIndicator"
	ind.base_radius = player.radius + 14.0
	ind.ring_color = Color.html(String(SaveManager.get_setting("indicator_color", "26ffff")))
	ind.visible = bool(SaveManager.get_setting("player_indicator", false))
	player.add_child(ind)
	_player_indicator = ind

func _apply_player_sprite() -> void:
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var skin_id: String = SaveManager.get_equipped_skin()
	if not SaveManager.is_skin_owned(skin_id):
		skin_id = "default"  # never render a skin the player doesn't own
	var tex := SpriteLoader.get_player_texture(skin_id)
	if tex:
		sprite.texture = tex
		var tex_size := tex.get_size()
		var target_diameter := player.radius * 2.0
		var scale_factor := target_diameter / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
	# Player sprite has its own color baked in; no modulate

# ============================================================
# COLLISION & PAINT
# ============================================================

func _check_player_paint() -> void:
	if player.is_dead:
		return
	# Cell-based paint erosion with seamless drag-streak smearing.
	var slow := floor_paint.process_player_paint(player.global_position, player.radius, player.player_color, player.velocity)
	player.set_paint_slow(slow)
	_player_on_paint = slow < 1.0

## "Matador": unlock when 3+ Brutes are charging the player at once.
func _check_charged_brutes() -> void:
	if _level_mode:
		return   # endless-only achievement
	var charging := 0
	for m: Node in monster_container.get_children():
		if m is Monster and (m as Monster).monster_type == MonsterTypes.Type.BRUTE and (m as Monster).is_charging():
			charging += 1
			if charging >= 3:
				AchievementManager.unlock("endless_3chargedbrutes")
				return

func _compute_monster_avoidance() -> void:
	var monsters: Array = monster_container.get_children()
	for m: Node in monsters:
		if m is Monster:
			(m as Monster).compute_avoidance(monsters)

## Floor pickups (powerups + item pickups + loot crates) must never sit ON TOP of each other —
## a stacked pair would hide one. Each physics frame, gently shove every overlapping pair apart
## along the line between them until they clear. Cheap: only a handful are ever on the map.
const PICKUP_SEPARATION := 0.34   ## fraction of the overlap resolved per frame (smooth push)

func _separate_pickups() -> void:
	var nodes: Array[Node2D] = []
	for cont: Node in [_powerup_container, _item_container]:
		if cont == null:
			continue
		for c: Node in cont.get_children():
			if (c is Powerup or c is ItemPickup or c is LootCrate) and not c.is_queued_for_deletion():
				nodes.append(c as Node2D)
	var n := nodes.size()
	if n < 2:
		return
	for i in range(n):
		var a := nodes[i]
		var ra := _pickup_radius(a)
		for j in range(i + 1, n):
			var b := nodes[j]
			var min_sep := ra + _pickup_radius(b)
			var diff := a.global_position - b.global_position
			var d2 := diff.length_squared()
			if d2 <= 0.0001:
				# Exactly stacked → kick along a random axis so the pair can start separating.
				var kick := Vector2.RIGHT.rotated(randf() * TAU) * (min_sep * 0.5)
				a.global_position += kick
				b.global_position -= kick
			elif d2 < min_sep * min_sep:
				var d := sqrt(d2)
				var push := diff / d * ((min_sep - d) * 0.5 * PICKUP_SEPARATION)
				a.global_position += push
				b.global_position -= push
	# Keep them inside the arena so a shove near a wall can't push one off-map.
	var m := 40.0
	for nd: Node2D in nodes:
		nd.global_position.x = clampf(nd.global_position.x, m, arena_width - m)
		nd.global_position.y = clampf(nd.global_position.y, m, arena_height - m)

## Effective (scaled) collision radius used for pickup separation.
func _pickup_radius(n: Node2D) -> float:
	var base := 35.0 if n is LootCrate else 33.0
	return base * absf(n.scale.x)

func _check_monster_player_collisions() -> void:
	if player.is_dead or player.is_invulnerable:
		return
	for m: Node in monster_container.get_children():
		if not m is Monster:
			continue
		var monster: Monster = m as Monster
		if monster.is_spawning or monster.hp <= 0:
			continue
		# Squared compare avoids a per-monster sqrt every frame.
		var rsum := player.radius + monster.radius
		if player.global_position.distance_squared_to(monster.global_position) < rsum * rsum:
			# Monster explodes on contact — deals % of player max HP then dies
			_last_contact_monster_type = monster.monster_type
			var contact_damage := player.max_health * monster.contact_hp_percent
			player.take_damage(contact_damage)

			# Push player away from monster
			var push_dir := (player.global_position - monster.global_position).normalized()
			player.velocity += push_dir * 300.0

			# Kill the monster (triggers death splat + particles + score via died signal)
			monster.hp = 0.0
			monster._die()
			# "Bumper Cars": killed a monster with the player's own body (endless only)
			_body_kill_count += 1
			if _body_kill_count >= 15 and not _level_mode:
				AchievementManager.unlock("endless_kill15monsterswithownbody_onelife")
			break  # Only one contact per frame (i-frames protect the rest)

# ============================================================
# SIGNAL HANDLERS
# ============================================================

## Recolor one stick to `hue`, keeping the existing white-default alphas (0.3 ring / 0.6 knob).
func _tint_joystick(js: TouchJoystick, hue: Color) -> void:
	if js == null:
		return
	js.base_color = Color(hue.r, hue.g, hue.b, 0.3)
	js.knob_color = Color(hue.r, hue.g, hue.b, 0.6)
	js.queue_redraw()

func _on_move_joystick(direction: Vector2) -> void:
	# Move joystick only works when WASD is NOT held (keyboard takes priority for movement)
	if not _keyboard_moving:
		player.set_move_input(direction)

func _on_aim_joystick(direction: Vector2) -> void:
	# Aim joystick ALWAYS works — even when WASD is held (allows WASD + aim joystick combo)
	_joystick_aiming = direction.length_squared() > 0.01
	player.set_aim_input(direction)

# ============================================================
# KEYBOARD INPUT (PC demo)
# ============================================================
## WASD/arrows = movement. Space = shoot in last move direction.
## WASD and aim joystick can be used simultaneously:
##   WASD controls movement, aim joystick controls shooting.
##   Space only fires if the aim joystick is idle.
## Both joysticks also work simultaneously on mobile.
func _process_keyboard_input() -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0

	# --- Movement: WASD overrides move joystick ---
	if dir.length_squared() > 0.01:
		_keyboard_moving = true
		_keyboard_move = dir.normalized()
		_last_move_dir = _keyboard_move
		player.set_move_input(_keyboard_move)
	elif _keyboard_moving:
		# Keys released → give control back to move joystick
		_keyboard_moving = false
		player.set_move_input(Vector2.ZERO)

	# --- Aiming: Space only fires when aim joystick is idle ---
	var shoot := Input.is_key_pressed(KEY_SPACE)
	if shoot and not _joystick_aiming:
		player.set_aim_input(_last_move_dir)
	elif not shoot and not _joystick_aiming:
		# Neither space nor joystick → stop aiming
		# (but don't zero out if joystick is active — it handles itself)
		player.set_aim_input(Vector2.ZERO)

func _on_player_died(_p: Player) -> void:
	if _level_finishing:
		return   # the level is already won — the win beats a same-frame death
	# Freeze elapsed time at moment of death
	_death_time = GameManager.elapsed_time
	GameManager.vibrate(120)   # strong haptic buzz on death
	# Deactivate time effects (death effect takes over time_scale)
	_slowpill_active = false
	_stoppill_active = false
	GameManager.time_stopped = false
	_hide_stoppill_overlay()
	AudioManager.set_sfx_pitch(1.0)
	# Clear any slowpill/stoppill effect on the music, then duck it for the death seq.
	AudioManager.set_music_pitch(1.0)
	AudioManager.set_music_paused(false)
	# Big death splat
	floor_paint.add_splat(player.global_position, player.player_color, 3.0)
	particles.spawn_death_particles(player.global_position, player.player_color, 30)
	AudioManager.play_sfx_random("monster_death", 4)  # player splats like a monster (no dedicated death sfx yet)
	# Numbered Level mode: NEVER a death screen — hide the player (only the death splat stays),
	# quick fade out, reset the level, fade back in at the start. Keyed on `_numbered_level`, NOT
	# on `_level_manager` (which can be freed mid-reload → previously fell through to the death
	# screen "level failed" menu on the odd turret/spike death).
	if _level_mode and _numbered_level:
		_streak_active = false   # any death breaks the no-death marathon run
		# Level deaths still count toward the "die 100 times" achievement.
		SaveManager.add_stat("total_deaths", 1)
		if SaveManager.get_stat("total_deaths") >= 100.0:
			AchievementManager.unlock("game_die100times")
		# 5 deaths in the same level → offer "skip for an ad" under the timer.
		# The FINAL level (30) can never be skipped.
		_level_deaths += 1
		if _level_deaths >= 5 and int(_level_manager.level_number) < 30 		and hud and hud.has_method("set_skip_visible"):
			hud.set_skip_visible(true)
		player.visible = false
		_death_flash()   # brief slow-mo (no flash) so the death reads clearly
		_respawn_level()
		return
	# Duck the music during the death sequence (keeps playing, just quieter).
	AudioManager.duck_music()
	# Death effect: hide sprite, slowdown + greyscale over 2s
	_start_death_effect()

## Numbered Level death flow: quick fade to black → rebuild the level from scratch
## (player back at the start) → fade back in. No death screen; only the pause menu exists
## in levels. Reuses the custom-level retry path.
func _respawn_level() -> void:
	var scene: PackedScene = _current_level_scene
	if scene == null or _level_respawning:
		return
	_level_respawning = true
	_save_play_time()   # flush the session-time delta before the reset
	_ensure_respawn_overlay()
	_respawn_overlay.color.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true)
	_respawn_tw = tw
	tw.tween_property(_respawn_overlay, "color:a", 1.0, 0.28).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		GameManager.start_endless()       # reuse the PLAYING state machine (same as retry)
		start_custom_level(scene))         # full reset + re-instantiate + begin()
	tw.tween_interval(0.05)
	tw.tween_property(_respawn_overlay, "color:a", 0.0, 0.28).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_level_respawning = false)

var _nearmiss_scan_t: float = 0.0
var _nearmiss_cd: float = 0.0
## True when the player is skimming (close but not touching) a saw or an extended piston head.
func _check_near_miss() -> bool:
	var pp: Vector2 = player.global_position
	for s in get_tree().get_nodes_in_group("level_saws"):
		if not (s is Node2D):
			continue
		var r: float = float(s.get("size")) * 0.5
		var d: float = pp.distance_to((s as Node2D).global_position)
		if d > r * float(s.get("hit_fraction")) + player.radius and d < r + player.radius + 50.0:
			return true
	for p in get_tree().get_nodes_in_group("pistons"):
		if not (p is Node2D) or not bool(p.get("_out")):
			continue
		var d2: float = pp.distance_to((p as Node2D).global_position)
		var hr: float = float(p.get("size")) * 0.5
		if d2 > hr + player.radius and d2 < hr + player.radius + 55.0:
			return true
	return false

## Level-death juice: a brief moment of slow motion (no flash). Time scale is restored
## by _reset_game inside the respawn.
func _death_flash() -> void:
	Engine.time_scale = 0.3

func _ensure_respawn_overlay() -> void:
	if _respawn_overlay and is_instance_valid(_respawn_overlay):
		return
	var lay := CanvasLayer.new()
	lay.layer = 99   # above gameplay, below the pause menu (55) is fine; pause can't open mid-fade
	lay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(lay)
	_respawn_overlay = ColorRect.new()
	_respawn_overlay.color = Color(0, 0, 0, 0)
	_respawn_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_respawn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(_respawn_overlay)

func on_player_death_complete(_p: Player) -> void:
	# Numbered levels ALWAYS respawn via _respawn_level() — never a death/"challenge failed"
	# screen, no matter how the death was triggered (saw/laser/piston/etc.) or the timing.
	if _numbered_level:
		return
	# Challenges: if a respawn already revived the player, there's nothing to finalize.
	if _level_respawning or not player.is_dead:
		return
	# Stop the _process loop but keep greyscale + frozen state
	_death_effect_active = false
	# Restore time_scale so death screen animation plays normally
	Engine.time_scale = 1.0
	# End game and freeze tree — game stays frozen behind death menu
	GameManager.end_game()
	get_tree().paused = true  # DeathScreen has process_mode ALWAYS, so it still works
	# Save session time (flush unsaved delta before final stats)
	_save_play_time()
	# Custom level / challenge: death ends the run → score it in stars (survival-time
	# challenges are ONLY evaluated here) and show the challenge result screen.
	if _level_mode:
		var stars := -1
		if _level_manager and _level_manager.challenge_id != "":
			stars = _level_manager.compute_stars()
			if stars >= 1:
				SaveManager.set_challenge_stars(_level_manager.challenge_id, stars)
				AchievementManager.check_challenge_achievements()
		var ch_rec := _save_challenge_record(_level_manager)
		SaveManager.save_game()
		if _death_screen and _level_manager:
			_death_screen.show_challenge_result(stars >= 1, _level_manager.level_name, _level_manager.description, stars, false, -1.0, false, ch_rec[0], ch_rec[1], ch_rec[2], ch_rec[3])
		return
	SaveManager.add_stat("total_deaths", 1)
	# Achievement: killed by a basic monster
	if _last_contact_monster_type == MonsterTypes.Type.BASIC:
		AchievementManager.unlock("endless_getkilledbybasic")
	# "Try, Try Again": 100 total deaths
	if SaveManager.get_stat("total_deaths") >= 100.0:
		AchievementManager.unlock("game_die100times")
	# "Touch Grass": 5h total play time (flushed above) — also unlocks the Deprived skin
	if SaveManager.get_stat("total_play_time") >= 18000.0:
		SaveManager.own_skin("Player_deprived")
		AchievementManager.unlock("game_playfor24hours")
	# Save run stats
	var is_new_best := _death_time > SaveManager.get_endless_best()
	SaveManager.save_endless_time(_death_time)
	var best_kills := int(SaveManager.get_stat("endless_best_kills"))
	if _kill_count > best_kills:
		SaveManager.set_stat("endless_best_kills", _kill_count)
	SaveManager.save_game()
	# Show death screen with frozen survival time + kill count + best time
	if _death_screen:
		var best_time := SaveManager.get_endless_best()
		_death_screen.show_death_screen(_death_time, _kill_count, best_time, is_new_best)

func _save_play_time() -> void:
	if _session_elapsed > SaveManager.get_stat("longest_session_time"):
		SaveManager.set_stat("longest_session_time", _session_elapsed)
	SaveManager.add_stat("total_play_time", _session_elapsed)
	_session_elapsed = 0.0  # Reset so we don't double-count on retry
	if _pending_bullets > 0:
		SaveManager.add_stat("total_bullets_fired", _pending_bullets)
		_pending_bullets = 0

## Survival-time achievements — checked each frame; AchievementManager dedupes so
## repeated calls past a threshold are cheap no-ops.
func _check_time_achievements() -> void:
	var t := GameManager.elapsed_time
	# Survival achievements are ENDLESS-only (levels/challenges also tick elapsed_time).
	if not _level_mode:
		if t >= 180.0:
			AchievementManager.unlock("endless_survive3mins")
		if t >= 300.0:
			AchievementManager.unlock("endless_survive5mins")
			# "Untouchable": reached 5 min having taken zero damage this life
			if not _took_damage_this_life:
				AchievementManager.unlock("endless_survive5minwithouttakingdamage")
		if t >= 600.0:
			AchievementManager.unlock("endless_survive10mins")
	# "Touch Grass": 5h total play time — also unlocks the Deprived skin.
	if not SaveManager.is_achievement_unlocked("game_playfor24hours"):
		if SaveManager.get_stat("total_play_time") + _session_elapsed >= 18000.0:
			SaveManager.own_skin("Player_deprived")
			AchievementManager.unlock("game_playfor24hours")

func _on_death_retry() -> void:
	_stop_death_effect()
	_death_screen.hide_death_screen()
	# Retry the same custom level if one was being played; otherwise restart endless.
	if _current_level_scene:
		var scene := _current_level_scene
		GameManager.start_endless()  # reuse the PLAYING state machine
		start_custom_level(scene)
		# NO respawn here: _reset_game (inside start_custom_level) already respawned the
		# player, and LevelManager.begin() then applied the level's start conditions
		# (e.g. 1 HP) — a respawn now would overwrite them with full health.
		return
	GameManager.start_endless()
	start_endless()
	player.respawn(Vector2(arena_width / 2.0, arena_height / 2.0))

## Green NEXT LEVEL button on the win screen → load level (N+1). If the next scene doesn't
## exist (past the last level) fall back to the main menu.
func _on_next_level() -> void:
	var cur := int(_level_manager.level_number) if _level_manager else 0
	var path := "res://scenes/levels/level_%d.tscn" % (cur + 1)
	if not ResourceLoader.exists(path):
		_on_death_menu()   # no further level (e.g. after the final level 30)
		return
	# Beating level 29 UNLOCKS the finale (level 30). Don't drop the player straight into the
	# boss — send them to the level select, which plays the level-30 unlock animation + sound.
	# (The FINAL boss gate — every level 1-29 must have ≥ bronze — is enforced inside the
	# level select itself, so a skipped 0-star level still can't shortcut to the boss.)
	if cur + 1 == 30:
		GameManager.pending_unlock_level = 30
		_on_death_menu()   # back to the menu, which opens the level select + reveal
		return
	_stop_death_effect()
	_death_screen.hide_death_screen()
	GameManager.start_endless()  # reuse the PLAYING state machine
	start_custom_level(load(path))

func _on_death_menu() -> void:
	_stop_death_effect()
	_death_screen.hide_death_screen()
	GameManager.pending_menu_popup = _menu_return_popup()
	GameManager.set_state(GameManager.GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## Which selector the main menu should reopen when the player leaves via MENU: the challenge
## list after a challenge, the level list after a numbered level, nothing after endless.
func _menu_return_popup() -> String:
	if _level_manager and is_instance_valid(_level_manager) and String(_level_manager.challenge_id) != "":
		return "challenges"
	if _numbered_level:
		return "levels"
	return ""

# ============================================================
# PAUSE
# ============================================================

## Auto-pause when app loses focus (home button, alt-tab, etc.).
## GameManager already pauses the tree; we just need to show the pause menu overlay.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _pause_menu and not GameManager.is_game_over:
			GameManager.pause_game()
			AudioManager.duck_music()
			_refresh_pause_level_info()
			_pause_menu.show_pause(false)   # auto-pause: never show the ad slot

func _on_pause_requested() -> void:
	if GameManager.is_game_over:
		return
	GameManager.pause_game()
	AudioManager.duck_music()  # music keeps playing, quieter, while paused
	_refresh_pause_level_info()
	_pause_menu.show_pause()

## Show the current numbered level's name + star-rating line under the ad in the pause menu.
## Only the RATING part of the description is shown (from the first "★") — no mechanic text.
func _refresh_pause_level_info() -> void:
	if _pause_menu == null:
		return
	if _numbered_level and _level_manager and is_instance_valid(_level_manager):
		var desc := String(_level_manager.description)
		var star_idx := desc.find("★")
		var rating := desc.substr(star_idx).strip_edges() if star_idx >= 0 else ""
		_pause_menu.set_level_info(String(_level_manager.level_name), rating)
	else:
		_pause_menu.clear_level_info()

## "Skip for an ad" (after 5 deaths): placeholder ad → unlock + load the next level.
## No stars/time are saved for the skipped level.
func _on_skip_level() -> void:
	if not _numbered_level or _level_manager == null or not is_instance_valid(_level_manager):
		return
	var cur := int(_level_manager.level_number)
	if cur >= 30:
		return   # the final boss level cannot be skipped
	# Skipping costs a rewarded ad. On fallback builds (no plugin) this grants instantly.
	AdManager.show_rewarded(AdManager.REWARDED_SKIP, func(success: bool) -> void:
		if success and is_instance_valid(self):
			_do_skip_level(cur))

## Actually perform the skip once the rewarded ad has granted (or on a no-ad build).
func _do_skip_level(cur: int) -> void:
	var path := "res://scenes/levels/level_%d.tscn" % (cur + 1)
	SaveManager.unlock_level(cur + 1)
	SaveManager.save_game()
	_streak_active = false            # skipping breaks the no-death marathon
	# A death-respawn may be mid-fade — kill it, or its queued callback would re-load
	# the OLD level right after the skip.
	if _respawn_tw and _respawn_tw.is_valid():
		_respawn_tw.kill()
	_respawn_tw = null
	_level_respawning = false
	if _respawn_overlay and is_instance_valid(_respawn_overlay):
		_respawn_overlay.color.a = 0.0
	if not ResourceLoader.exists(path):
		_on_death_menu()
		return
	GameManager.start_endless()       # reuse the PLAYING state machine
	start_custom_level(load(path))

func _on_pause_resume() -> void:
	_pause_menu.hide_pause()
	GameManager.resume_game()
	AudioManager.restore_music()

## Player pressed Apply in the in-game settings — re-read the live-affecting settings
## so changes (player indicator on/off + color, floor color-distinction) take effect now.
func _on_settings_applied() -> void:
	_color_distinction = float(SaveManager.get_setting("color_distinction", 0.5))
	floor_paint.top_splat_darken = _color_distinction * 0.7
	_setup_player_indicator()
	_apply_game_zoom()   # live-apply the game-zoom slider
	_apply_bg_brightness()   # live-apply the background-lightness slider
	# Live-apply the game-GUI scale (HUD / inventory / joysticks rebuild in place).
	var new_gui := SaveManager.get_game_gui_scale()
	if not is_equal_approx(new_gui, _last_game_gui_scale):
		_last_game_gui_scale = new_gui
		_rebuild_game_gui()
	if hud and hud.has_method("apply_hp_opacity_settings"):
		hud.apply_hp_opacity_settings()   # live-apply HP-bar opacity settings

## Rebuild the in-game overlays at the new game-GUI scale and re-feed their state.
func _rebuild_game_gui() -> void:
	hud.rescale_live()
	# Re-apply the dynamic HUD state the rebuild can't know about.
	hud.update_health(player.health, player.max_health)
	hud.update_time(GameManager.elapsed_time)
	# Level/tier labels (also hides the rebuilt mode panel in endless/challenges).
	if GameManager.state == GameManager.GameState.PLAYING_LEVEL and not _level_mode:
		hud.update_level(spawner.current_level)
		hud.update_tier(spawner.current_tier)
	else:
		hud.update_level(-1)
		hud.update_tier(-1)
	# Re-create rows for the powerups that are still active.
	if _powerup_manager:
		for t in _powerup_manager.get_active_types():
			hud.show_powerup(t, _powerup_manager.get_texture(t), Powerup.TYPE_NAMES.get(t, "Powerup"))
	# Challenge extras (1-HP gauge hide, ammo + kill counters).
	if _level_mode and _level_manager:
		if hud.has_method("set_hp_gauge_visible"):
			hud.set_hp_gauge_visible(not bool(_level_manager.hide_hp_bar))
		hud.set_ammo_visible(int(_level_manager.ammo_limit) > 0)
		if int(_level_manager.ammo_limit) > 0:
			hud.update_ammo(player.ammo)
		hud.set_kill_counter_visible(bool(_level_manager.show_kill_counter))
		if bool(_level_manager.show_kill_counter):
			hud.update_kill_counter(_level_manager._kills)
	# Inventory + joysticks.
	if _inventory_ui and _item_manager:
		_inventory_ui.rescale_live(_item_manager.inventory, _item_manager)
	if move_joystick:
		move_joystick.rescale_live()
	if aim_joystick:
		aim_joystick.rescale_live()

## A white wash above the floor (below entities) whose alpha = the bg_brightness setting,
## so the dark background can be lightened LIVE without touching the baked paint canvas.
func _setup_bg_lighten() -> void:
	if _bg_lighten == null:
		_bg_lighten = ColorRect.new()
		_bg_lighten.name = "BgLighten"
		_bg_lighten.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_lighten.z_index = -8   # above floor (-10) + endless watermark (-9), below entities (>=0)
		add_child(_bg_lighten)
	_bg_lighten.position = Vector2.ZERO
	_bg_lighten.size = Vector2(arena_width, arena_height)
	_apply_bg_brightness()

func _apply_bg_brightness() -> void:
	if _bg_lighten == null:
		return
	var b := clampf(float(SaveManager.get_setting("bg_brightness", 0.3)), 0.0, 1.0)
	_bg_lighten.color = Color(1.0, 1.0, 1.0, b * 0.4)   # up to a 40% white wash

# ============================================================
# CHALLENGE GIMMICKS (blackout / shrinking arena / limited ammo)
# ============================================================

## Per-physics-frame driver for the active challenge's special mechanics.
func _process_challenge_modifiers(delta: float) -> void:
	if bool(_level_manager.blackout):
		_update_blackout()
	if bool(_level_manager.shrink_arena) and not player.is_dead:
		_shrink_timer += delta
		if _shrink_timer >= float(_level_manager.shrink_interval):
			_shrink_timer = 0.0
			_apply_shrink_step()
	# Limited ammo: once the last bullet has resolved (none in flight), end + score the run.
	if int(_level_manager.ammo_limit) > 0 and not player.is_dead and not GameManager.is_game_over:
		if player.ammo == 0 and not _any_player_bullets_alive():
			_ammo_out_timer += delta
			if _ammo_out_timer >= 1.0:
				_finish_challenge_scored()
		else:
			_ammo_out_timer = 0.0

func _any_player_bullets_alive() -> bool:
	for c in bullet_container.get_children():
		if c is Bullet:
			return true
	return false

## HUD callback for the limited-ammo counter (called by the player on each shot).
func on_player_ammo_changed(n: int) -> void:
	hud.update_ammo(n)

## End + score a challenge run that finished without death or a win goal (ammo out).
func _finish_challenge_scored() -> void:
	GameManager.end_game()
	get_tree().paused = true
	_save_play_time()
	var stars := -1
	if _level_manager and _level_manager.challenge_id != "":
		stars = _level_manager.compute_stars()
		if stars >= 1:
			SaveManager.set_challenge_stars(_level_manager.challenge_id, stars)
			AchievementManager.check_challenge_achievements()
	var ch_rec := _save_challenge_record(_level_manager)
	SaveManager.save_game()
	if _death_screen and _level_manager:
		_death_screen.show_challenge_result(stars >= 1, _level_manager.level_name, _level_manager.description, stars, false, -1.0, false, ch_rec[0], ch_rec[1], ch_rec[2], ch_rec[3])

## Rage: boost every currently-alive monster's speed by 50% (only when the field is
## crowded enough — a near-empty arena shouldn't punish the player).
func _apply_rage_boost() -> void:
	var alive: Array = []
	for m in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and (m as Monster).hp > 0.0 and not (m as Monster).is_spawning:
			alive.append(m)
	if alive.size() < RAGE_MIN_MONSTERS:
		return
	for m: Monster in alive:
		m.speed = minf(m.speed * RAGE_SPEED_MULT, RAGE_SPEED_CAP)

# ---- Blackout (darkness with a visibility circle around the player) ----

func _setup_blackout() -> void:
	if _blackout_layer == null:
		_blackout_layer = CanvasLayer.new()
		_blackout_layer.name = "BlackoutLayer"
		_blackout_layer.layer = 9   # above the world + stoppill tint, below the HUD (11)
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blackout_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = BLACKOUT_SHADER
		_blackout_mat.shader = sh
		rect.material = _blackout_mat
		_blackout_layer.add_child(rect)
		add_child(_blackout_layer)
	_blackout_layer.visible = true
	_update_blackout()

func _hide_blackout() -> void:
	if _blackout_layer:
		_blackout_layer.visible = false

## Keep the visibility hole centered on the player (screen-space).
func _update_blackout() -> void:
	if _blackout_mat == null or player == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	# The player's ON-SCREEN position, normalised to 0..1 across the viewport — same space the
	# shader's UV is in, so the hole tracks the player at any window size / zoom.
	var center: Vector2 = player.get_global_transform_with_canvas().origin
	_blackout_mat.set_shader_parameter("hole_center", Vector2(center.x / vp.x, center.y / vp.y))
	# blackout_radius is authored in 1080p design px → express it as a fraction of the height.
	var radius_uv: float = float(_level_manager.blackout_radius) / 1080.0
	_blackout_mat.set_shader_parameter("hole_radius", radius_uv)
	_blackout_mat.set_shader_parameter("edge_soft", radius_uv * 0.4)
	_blackout_mat.set_shader_parameter("aspect", vp.x / vp.y)

# ---- Shrinking arena (black walls close in every N seconds) ----

func _apply_shrink_step() -> void:
	var min_w: float = float(_level_manager.shrink_min_width)
	var min_h: float = float(_level_manager.shrink_min_height)
	var step: float = float(_level_manager.shrink_step)
	# Max inset that still leaves the minimum inner size.
	var max_inset := minf((arena_width - min_w) * 0.5, (arena_height - min_h) * 0.5)
	var new_inset: float = minf(_arena_inset + step, maxf(max_inset, 0.0))
	if is_equal_approx(new_inset, _arena_inset):
		return
	_arena_inset = new_inset
	_update_shrink_walls()
	_update_wall_shapes()
	# Keep the player inside the new bounds.
	if player and not player.is_dead:
		var m: float = _arena_inset + player.radius
		player.global_position = player.global_position.clamp(
			Vector2(m, m), Vector2(arena_width - m, arena_height - m))
	_add_shake(3.0)
	GameManager.vibrate(40)

## (Re)build the 4 full-black rectangles covering the shrunk-away dead zone.
func _update_shrink_walls() -> void:
	for w in _shrink_walls:
		if is_instance_valid(w):
			w.queue_free()
	_shrink_walls.clear()
	if _arena_inset <= 0.0:
		return
	var i := _arena_inset
	var rects := [
		Rect2(0, 0, arena_width, i),                                 # top
		Rect2(0, arena_height - i, arena_width, i),                  # bottom
		Rect2(0, i, i, arena_height - 2.0 * i),                      # left
		Rect2(arena_width - i, i, i, arena_height - 2.0 * i),        # right
	]
	for r: Rect2 in rects:
		var wall := ColorRect.new()
		wall.color = Color.BLACK
		wall.position = r.position
		wall.size = r.size
		wall.z_index = 30   # above all gameplay entities (laser is z=8)
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wall)
		_shrink_walls.append(wall)

func _on_pause_menu() -> void:
	_stop_death_effect()
	_pause_menu.hide_pause()
	GameManager.pending_menu_popup = _menu_return_popup()
	GameManager.set_state(GameManager.GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_player_health_changed(current: float, max_hp: float) -> void:
	hud.update_health(current, max_hp)
	# Damage feedback: light shake + red edge vignette on meaningful HP loss.
	# Zone damage is excluded — it has its own sustained vignette (no shake/flash).
	if not _applying_zone_damage and _last_player_health >= 0.0 and current < _last_player_health - 0.5:
		_add_shake(SHAKE_PLAYER_HIT)
		_flash_damage_vignette()
		player.flash_hit()        # bright red flash on the player sprite
		GameManager.vibrate(45)   # short haptic buzz on taking a hit
	# Any HP loss (including zone damage) breaks the flawless-run achievement.
	if _last_player_health >= 0.0 and current < _last_player_health - 0.5:
		_took_damage_this_life = true
	# "Back from the Brink": drop to 10 HP or less, then heal back up to 100+ HP — in one
	# life, ENDLESS only. (Challenges reuse the PLAYING_ENDLESS state, so _level_mode is
	# the discriminator that excludes them.)
	if not _level_mode and GameManager.state == GameManager.GameState.PLAYING_ENDLESS:
		if current > 0.0 and current <= 10.0:
			_dropped_below_10hp = true
		elif _dropped_below_10hp and current >= 100.0:
			_dropped_below_10hp = false
			AchievementManager.unlock("game_healfrom10andloverto100hp")
	_last_player_health = current

func _on_player_score_changed(score: int) -> void:
	hud.update_score(score)

# ============================================================
# POWERUP SYSTEM
# ============================================================

func _on_powerup_activated(type: Powerup.Type) -> void:
	AudioManager.play_sfx("powerup_pickup")

	# CLEANERMAX is instant (no duration) — clear all paint, no HUD timer row.
	if type == Powerup.Type.CLEANERMAX:
		_activate_cleanermax()
		return

	# Show HUD row for this type
	var tex := _powerup_manager.get_texture(type)
	var type_name: String = Powerup.TYPE_NAMES.get(type, "Powerup")
	hud.show_powerup(type, tex, type_name)

	# Apply immediate effect
	match type:
		Powerup.Type.SHOOT_BOOST:
			player.is_powered_up = true
		Powerup.Type.SPEED_BOOST:
			player.speed_multiplier = 2.0
		Powerup.Type.CLEANER:
			player.set_paint_slow(1.0)
		Powerup.Type.SHURIKEN:
			_activate_shuriken()
		Powerup.Type.HPBOOSTMAX:
			# Invincibility. In endless the player SEES their HP so top it up as a bonus; in
			# levels/challenges HP is hidden and forced (often 1 HP) → grant ONLY the damage
			# immunity, never refill the (invisible) HP.
			if not _level_mode:
				player.health = player.max_health
				player.health_changed.emit(player.health, player.max_health)
			player.is_invulnerable = true
			player.is_powerup_invincible = true
		Powerup.Type.STOPPILL:
			_activate_stoppill()
		Powerup.Type.OCTOSHOOT:
			pass  ## Handled per-bullet in spawn_bullet()

func _on_powerup_deactivated(type: Powerup.Type) -> void:
	AudioManager.play_sfx("powerup_end")
	hud.hide_powerup_type(type)

	# Remove effect for this type
	match type:
		Powerup.Type.SHOOT_BOOST:
			player.is_powered_up = false
		Powerup.Type.SPEED_BOOST:
			player.speed_multiplier = 1.0
		Powerup.Type.CLEANER:
			floor_paint.hide_cleaner_eraser()
		Powerup.Type.SHURIKEN:
			_deactivate_shuriken()
		Powerup.Type.HPBOOSTMAX:
			player.is_invulnerable = false
			player.is_powerup_invincible = false
		Powerup.Type.STOPPILL:
			_deactivate_stoppill()
		Powerup.Type.OCTOSHOOT:
			pass  ## Effect just stops — no cleanup needed

func _on_powerup_timer_updated(type: Powerup.Type, remaining: float) -> void:
	hud.update_powerup_timer(type, remaining)

## Per-frame powerup effects — iterates ALL active powerups (they stack).
func _apply_powerup_effects(delta: float) -> void:
	if player.is_dead:
		return
	var active_types: Array = _powerup_manager.get_active_types()
	if active_types.is_empty():
		return

	# Achievement: more than 3 powerups active at once (endless only)
	if active_types.size() > 3 and not _level_mode:
		AchievementManager.unlock("endless_morethan3powerups")

	for type: int in active_types:
		match type:
			Powerup.Type.CLEANER:
				# Immune to paint slow
				player.set_paint_slow(1.0)
				# Permanent paint erasure — stamped at controlled rate
				_cleaner_stamp_timer += delta
				if _cleaner_stamp_timer >= CLEANER_STAMP_INTERVAL:
					_cleaner_stamp_timer -= CLEANER_STAMP_INTERVAL
					floor_paint.stamp_permanent_eraser(player.global_position, 50.0)
				# Live visual feedback (persistent eraser follows player)
				floor_paint.erase_paint_radius(player.global_position, 50.0)
				# Decorative particles
				for _i in 4:
					var angle := randf() * TAU
					var dist := randf() * 50.0
					var offset := Vector2(cos(angle) * dist, sin(angle) * dist)
					particles.spawn_cleaner_particles(player.global_position + offset)

			Powerup.Type.HP_BOOST:
				# Regen 12 HP per second (4x of 3)
				if player.health < player.max_health:
					player.health = minf(player.health + 12.0 * delta, player.max_health)
					player.health_changed.emit(player.health, player.max_health)

			Powerup.Type.SHOOT_BOOST:
				pass  ## Triple shot handled by player.is_powered_up flag

			Powerup.Type.SPEED_BOOST:
				pass  ## Speed handled by player.speed_multiplier

			Powerup.Type.FMJ:
				pass  ## FMJ handled per-bullet at spawn time

			Powerup.Type.OCTOSHOOT:
				pass  ## Octoshoot handled per-bullet at spawn time

			Powerup.Type.SHURIKEN:
				pass  ## Shuriken handled by _active_shuriken node

			Powerup.Type.HPBOOSTMAX:
				# Keep invulnerable for the full duration
				player.is_invulnerable = true
				player.is_powerup_invincible = true

			Powerup.Type.STOPPILL:
				pass  ## Time stop handled in _process_stoppill

func _on_monster_died(monster: Monster) -> void:
	_rage_kills_in_window += 1
	var mpos := monster.global_position
	# Hit-stop "punch" when a chunky monster dies (Tank/Brute/Bomber/Spawner).
	var chunky: bool = monster.monster_type in HIT_STOP_TYPES
	if chunky:
		_hit_stop()
	# Screen-shake kick on EVERY kill — a gentle rumble while mowing down, a firmer punch on
	# chunky types. _add_shake uses max(), so a whole swarm dying at once can't stack into
	# nausea; it just holds the gentle rumble.
	_add_shake(SHAKE_KILL_BIG if chunky else SHAKE_KILL)
	# Death paint splat — central splat + small detail splats. Where kills pile up, the pool
	# deepens (darker) and grows (a visible "rampage trail" builds where you fight).
	# Color distinction, two layers: this immediate BOTTOM layer darkens 1.6x the setting
	# (50% setting → 80%); the gradual TOP layer (particle-baked splats, see
	# floor_paint.top_splat_darken) darkens by the plain setting. Both scale with it.
	var pool := _register_kill_heat(mpos)     # 0..1 local kill density (recent)
	var splat_color := monster.monster_color.darkened(minf(_color_distinction * 1.6, 1.0) * 0.7)
	var pool_color := splat_color.darkened(pool * 0.4)
	floor_paint.add_splat(mpos, pool_color, monster.paint_scale * (0.8 + pool * 0.7))
	for _i in 4:
		var offset := Vector2(CMath.rand(-25, 25), CMath.rand(-25, 25))
		floor_paint.add_splat(mpos + offset, pool_color, monster.paint_scale * CMath.rand(0.1, 0.3))
	# Death particles + chunky gibs in the monster's colour (gibs settle into the paint layer).
	particles.spawn_death_particles(mpos, monster.monster_color, 15)
	particles.spawn_gibs(mpos, monster.monster_color, CMath.rand_int(4, 6))
	# Sharp inflate-and-burst of the body (a throwaway copy — the real node is freed below).
	_spawn_death_pop(monster)
	# Neighbours cringe when something dies right next to them — the pack reacts to each kill.
	_flinch_monsters_near(mpos, monster)
	# Player score + kill counter + per-type tracking
	player.add_score(monster.score_value)
	_kill_count += 1
	# Kill-count achievements (one life = one ENDLESS run; levels/challenges don't count)
	if not _level_mode:
		if _kill_count == 200:
			AchievementManager.unlock("endless_kill200enemies_onelife")
		elif _kill_count == 500:
			AchievementManager.unlock("endless_kill500enemies_onelife")
		elif _kill_count == 1000:
			AchievementManager.unlock("endless_kill1000enemies_onelife")
	# Track per-type kills for stats
	var type_key := "kills_%s" % MonsterTypes.Type.keys()[monster.monster_type].to_lower()
	SaveManager.add_stat(type_key, 1)
	SaveManager.add_stat("total_kills", 1)
	# Custom-level goal tracking
	if _level_manager and _level_manager.has_method("notify_monster_killed"):
		_level_manager.notify_monster_killed()
		if bool(_level_manager.show_kill_counter):
			hud.update_kill_counter(_level_manager._kills)
	# Sound (positional - x-axis only)
	var monster_x: float = monster.global_position.x
	AudioManager.play_sfx_random_at("monster_death", 4, monster_x)
	# Drop chance on death: when it triggers, split it 50/50 between an item and a
	# (common) powerup. Rare powerups never drop from monsters.
	if _item_manager and _item_manager.is_running and randf() < ItemManager.MONSTER_DROP_CHANCE:
		if randf() < 0.5:
			_drop_random_item(monster.global_position)
		else:
			_drop_random_powerup(monster.global_position)
	# "Nip It in the Bud": kill a Spawner before it produced any grunts (endless only).
	if monster.monster_type == MonsterTypes.Type.SPAWNER and not monster.spawner_has_spawned \
	and not _level_mode:
		AchievementManager.unlock("endless_spawnerkilledbeforespawningbasics")
	# Tankbomber: record the death for the chain achievement, THEN detonate (the blast
	# kills more tankbombers whose deaths recurse here — 3 within 0.2s = Chain Reaction).
	if monster.monster_type == MonsterTypes.Type.TANKBOMBER:
		var now := Time.get_ticks_msec()
		_tankbomber_death_times.append(now)
		while _tankbomber_death_times.size() > 0 and now - int(_tankbomber_death_times[0]) > 200:
			_tankbomber_death_times.pop_front()
		if _tankbomber_death_times.size() >= 3:
			AchievementManager.unlock("game_explode3bombtankswithkillingone")
		_tankbomber_explode(monster.global_position)
	elif monster._sp_explode:
		# Tankbomber-donor hybrid: detonate the same grenade-style blast (no chain achievement).
		_tankbomber_explode(monster.global_position)
	# Remove monster
	monster.queue_free()

func _on_monster_spawned_children(children: Array, parent: Monster) -> void:
	# This fires from a monster's _die()/_think_spawner, which run INSIDE the physics flush —
	# adding a body there errors ("Can't change state while flushing queries"). Defer each
	# child's spawn so add_child runs safely after the flush.
	var is_spawner := parent.monster_type == MonsterTypes.Type.SPAWNER
	for child_data: Dictionary in children:
		_spawn_child_deferred.call_deferred(
			int(child_data["type"]), child_data["position"], int(child_data.get("split_tier", 0)),
			int(child_data.get("special", -1)), is_spawner, parent)

## Deferred spawn of one split/spawner child (runs after the physics flush).
func _spawn_child_deferred(type: int, pos: Vector2, split_tier: int, special: int, is_spawner: bool, parent: Monster) -> void:
	var m: Monster = _spawn_monster(type, pos, spawner.elapsed_time, split_tier, special)
	if m == null:
		return
	m.skip_spawn_delay()   # spawned children are immediately active (no spawn delay)
	if is_spawner:
		m._parent_spawner = parent if is_instance_valid(parent) else null
		m.disable_collision()
		var sprite: Sprite2D = m.get_node_or_null("Sprite2D")
		if sprite:
			var target_scale := sprite.scale
			sprite.scale = Vector2.ZERO
			var tw := m.create_tween()
			tw.tween_property(sprite, "scale", target_scale, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_bullet_hit_monster(bullet: Bullet, monster: Monster) -> void:
	particles.spawn_impact_particles(bullet.global_position, bullet.bullet_color)
	if not bullet.is_secondary:
		var bullet_x: float = bullet.global_position.x
		AudioManager.play_sfx_random_at("bullet_hit", 4, bullet_x)

	# Hit flash: sprite flashes red for 0.05 s then reverts
	var sprite: Sprite2D = monster.get_node_or_null("Sprite2D")
	if sprite and monster.is_inside_tree():
		# Restore to blue tint if stoppill active, otherwise white
		var restore_color := Color(0.4, 0.6, 1.0) if _stoppill_active else Color.WHITE
		var tw := monster.create_tween()
		tw.tween_property(sprite, "modulate", Color.RED, 0.0)
		tw.tween_interval(0.05)
		tw.tween_property(sprite, "modulate", restore_color, 0.0)

func _on_bullet_hit_wall(bullet: Bullet) -> void:
	particles.spawn_impact_particles(bullet.global_position, bullet.bullet_color, 4)

func _on_level_started(level_num: int) -> void:
	hud.update_level(level_num)

func _on_level_completed(_level_num: int) -> void:
	# Legacy wave-based level mode (auto_start_mode="level_1" test path only). Numbered
	# levels save real time-based stars in the LevelManager win flow — never here.
	pass

func _on_wave_started(_wave_num: int) -> void:
	# Endless mode: tier label stays hidden — difficulty info is purely internal.
	# Level mode: tier is managed by _on_level_started, not per-wave.
	pass

# ============================================================
# ITEM SYSTEM
# ============================================================

func _fire_grenade(pos: Vector2, dir: Vector2) -> void:
	if _grenade_scene == null:
		return

	var has_fmj := _powerup_manager and _powerup_manager.has_active(Powerup.Type.FMJ)
	var has_bullet_boost := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_BOOST)
	var has_cleaner := _powerup_manager and _powerup_manager.has_active(Powerup.Type.CLEANER)
	var has_octoshoot := _powerup_manager and _powerup_manager.has_active(Powerup.Type.OCTOSHOOT)
	var has_freeze := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_FREEZE)

	# Hidden "Grenade Apocalypse": grenade thrown with Octoshoot + FMJ both active.
	if has_fmj and has_octoshoot:
		AchievementManager.unlock("game_grenadeapocalypse")

	# Build direction list based on active powerups
	var directions: Array[Vector2] = [dir]
	if has_octoshoot:
		# Octoshoot + Grenade: throw 8 grenades in all compass directions
		directions.clear()
		for i in 8:
			directions.append(Vector2.from_angle(i * (TAU / 8.0)))
	elif has_bullet_boost:
		# Bulletboost + Grenade: throw 2 grenades (spread left and right)
		var spread_rad := deg_to_rad(player.powerup_spread_angle)
		directions = [dir.rotated(-spread_rad), dir.rotated(spread_rad)]

	for d: Vector2 in directions:
		var grenade: Grenade = _grenade_scene.instantiate() as Grenade
		grenade.setup(pos, d)
		# FMJ + Grenade: red tint, no explode on monster contact
		if has_fmj:
			grenade.is_fmj = true
		# Cleaner + Grenade: light blue tint
		if has_cleaner:
			grenade.is_cleaner = true
		# Freeze + Grenade: no damage, freezes every monster caught in the blast for life.
		if has_freeze:
			grenade.is_freeze = true
		grenade.exploded.connect(_on_grenade_exploded)
		bullet_container.add_child(grenade)

	AudioManager.play_sfx("grenade_pin")

func _on_grenade_exploded(grenade: Grenade) -> void:
	var pos := grenade.global_position
	# FMJ: 2x explosion radius
	var radius_mult := 2.0 if grenade.is_fmj else 1.0
	var explosion_radius := Grenade.EXPLOSION_RADIUS * radius_mult

	# Kill all monsters in blast radius (one-shot) — OR, with Freeze Shot active, deal NO
	# damage and freeze them SOLID for the rest of their life instead (the boss is a separate
	# "boss" node, so it's naturally excluded — it still takes its normal grenade hit below).
	var grenade_kills := 0
	for m: Node in monster_container.get_children():
		if not m is Monster:
			continue
		var monster := m as Monster
		if monster.is_spawning or monster.hp <= 0:
			continue
		var dist := pos.distance_to(monster.global_position)
		if dist <= explosion_radius + monster.radius:
			if grenade.is_freeze:
				monster.apply_freeze(Monster.FREEZE_PERMANENT, 0.0)
			else:
				monster.prevent_split = true  # Grenade kill prevents splitter from splitting
				monster.take_damage(Grenade.DAMAGE)  # one-shot kill
				grenade_kills += 1
	# Achievements: kills from a single grenade (endless only)
	if not _level_mode:
		if grenade_kills >= 5:
			AchievementManager.unlock("endless_5killswith1grenade")
		if grenade_kills >= 10:
			AchievementManager.unlock("endless_10killswith1grenade")
	# Player self-damage if in blast radius (a Freeze grenade deals NO damage at all → skip).
	if not player.is_dead and not grenade.is_freeze:
		var player_dist := pos.distance_to(player.global_position)
		if player_dist <= explosion_radius + player.radius:
			var self_dmg := player.max_health * Grenade.PLAYER_DAMAGE_PERCENT
			player.take_damage(self_dmg)

	# Explosion visual — color depends on combo
	var explosion_color: Color
	if grenade.is_freeze:
		explosion_color = Color(0.5, 0.8, 1.0)   # icy blast
	elif grenade.is_cleaner:
		# Cleaner + Grenade: light blue, cleaner decals
		explosion_color = Color(0.4, 0.8, 1.0)
		# Erase paint in explosion area instead of adding splats
		floor_paint.erase_paint_radius(pos, explosion_radius)
		floor_paint.stamp_permanent_eraser(pos, explosion_radius)
	else:
		explosion_color = Color(1.0, 0.5, 0.0)
		# No ground splats for grenades

	particles.spawn_death_particles(pos, explosion_color, int(40 * radius_mult))
	AudioManager.play_sfx("grenade_explosion")
	# Explosion sprite — scales up fast to blast radius, then fades out
	_spawn_explosion_sprite(pos, explosion_radius, grenade.is_fmj, grenade.is_cleaner)
	# Very light screen shake (FMJ blast = slightly stronger)
	_add_shake(SHAKE_GRENADE_FMJ if grenade.is_fmj else SHAKE_GRENADE)

	# Check if grenade blast hit any lootcrates
	for crate_node: Node in _lootcrate_container.get_children():
		if not crate_node is LootCrate:
			continue
		var crate := crate_node as LootCrate
		if crate.hp <= 0:
			continue
		var crate_dist := pos.distance_to(crate.global_position)
		if crate_dist <= explosion_radius + 35.0:  # 35 = crate collision radius
			crate.take_hit(LootCrate.GRENADE_DMG)

	# Grenades also hurt the FINAL BOSS: 20% of its max HP (x1.5 with FMJ).
	for bz: Node in get_tree().get_nodes_in_group("boss"):
		if bz is Node2D and bz.has_method("grenade_hit") 		and pos.distance_to((bz as Node2D).global_position) <= explosion_radius + float(bz.get("size")) * 0.42:
			bz.grenade_hit(1.5 if grenade.is_fmj else 1.0)
	# Grenades wreck level props (spawners + turrets) caught in the blast.
	_explode_spawners(pos, explosion_radius)
	_explode_turrets(pos, explosion_radius)

## Throw a decoy — lures every monster to it for its fuse, then detonates.
## Single throw (no octoshoot/bulletboost multiplication — one lure target only).
func _fire_decoy(pos: Vector2, dir: Vector2) -> void:
	if _decoy_scene == null:
		return
	var decoy: Decoy = _decoy_scene.instantiate() as Decoy
	decoy.setup(pos, dir)
	decoy.exploded.connect(_on_decoy_exploded)
	bullet_container.add_child(decoy)
	# Every monster now chases the decoy instead of the player.
	Monster.set_lure_target(decoy)
	AudioManager.play_sfx("decoy_beep", 0.5)

func _on_decoy_exploded(decoy: Decoy) -> void:
	var pos := decoy.global_position
	# Stop luring (only if this is still the active decoy).
	Monster.clear_lure_target(decoy)
	var explosion_radius := Decoy.EXPLOSION_RADIUS

	# Kill all monsters in the (smaller) blast radius — one-shot.
	for m: Node in monster_container.get_children():
		if not m is Monster:
			continue
		var monster := m as Monster
		if monster.is_spawning or monster.hp <= 0:
			continue
		if pos.distance_to(monster.global_position) <= explosion_radius + monster.radius:
			monster.prevent_split = true
			monster.take_damage(Grenade.DAMAGE)
	# Player self-damage if too close (same rule as grenade)
	if not player.is_dead:
		var player_dist := pos.distance_to(player.global_position)
		if player_dist <= explosion_radius + player.radius:
			player.take_damage(player.max_health * Grenade.PLAYER_DAMAGE_PERCENT)

	# Monochrome visuals (grenade explosion sprite, desaturated) + grey particles
	particles.spawn_death_particles(pos, Color(0.9, 0.9, 0.9), 28)
	AudioManager.play_sfx("decoy_explosion")
	_spawn_explosion_sprite(pos, explosion_radius, false, false, true)
	_add_shake(SHAKE_GRENADE)

	# Decoy blast can also break lootcrates
	for crate_node: Node in _lootcrate_container.get_children():
		if not crate_node is LootCrate:
			continue
		var crate := crate_node as LootCrate
		if crate.hp <= 0:
			continue
		if pos.distance_to(crate.global_position) <= explosion_radius + 35.0:
			crate.take_hit(LootCrate.GRENADE_DMG)
	# Decoy blast destroys monster spawners in range.
	_explode_spawners(pos, explosion_radius)
	_explode_turrets(pos, explosion_radius)

## Destroy every monster spawner caught in a blast of `radius` at `pos` (any explosion source).
func _explode_spawners(pos: Vector2, radius: float) -> void:
	for sp: Node in get_tree().get_nodes_in_group("spawners"):
		if sp is Node2D and sp.has_method("blast_destroy") \
		and pos.distance_to((sp as Node2D).global_position) <= radius + 45.0:
			sp.call_deferred("blast_destroy")

## Destroy turrets caught in a blast (grenade / barrel / exploding monster / decoy).
func _explode_turrets(pos: Vector2, radius: float) -> void:
	for t: Node in get_tree().get_nodes_in_group("turrets"):
		if t is Node2D and t.has_method("blast_destroy") and pos.distance_to((t as Node2D).global_position) <= radius + 45.0:
			t.call_deferred("blast_destroy")

## Public grenade-style blast at a world position — used by level objects such as
## exploding barrels. Kills nearby monsters, hurts the player if close, hits loot
## crates, and chain-detonates other barrels in range.
func explode_at(pos: Vector2, radius_mult: float = 1.0) -> void:
	var explosion_radius := Grenade.EXPLOSION_RADIUS * radius_mult
	for m: Node in monster_container.get_children():
		if not m is Monster:
			continue
		var monster := m as Monster
		if monster.is_spawning or monster.hp <= 0:
			continue
		if pos.distance_to(monster.global_position) <= explosion_radius + monster.radius:
			monster.take_damage(Grenade.DAMAGE)
	if not player.is_dead:
		if pos.distance_to(player.global_position) <= explosion_radius + player.radius:
			player.take_damage(player.max_health * Grenade.PLAYER_DAMAGE_PERCENT)
	particles.spawn_death_particles(pos, Color(1.0, 0.5, 0.0), 40)
	AudioManager.play_sfx("grenade_explosion")
	_spawn_explosion_sprite(pos, explosion_radius)
	_add_shake(SHAKE_GRENADE)
	# Hit loot crates in range.
	for crate_node: Node in _lootcrate_container.get_children():
		if crate_node is LootCrate and (crate_node as LootCrate).hp > 0:
			if pos.distance_to(crate_node.global_position) <= explosion_radius + 35.0:
				(crate_node as LootCrate).take_hit(LootCrate.GRENADE_DMG)
	# Chain-detonate other barrels caught in the blast.
	for b: Node in get_tree().get_nodes_in_group("barrels"):
		if b is Node2D and b.has_method("chain_explode") \
		and pos.distance_to((b as Node2D).global_position) <= explosion_radius + 45.0:
			b.call_deferred("chain_explode")
	# Destroy monster spawners caught in the blast.
	_explode_spawners(pos, explosion_radius)
	_explode_turrets(pos, explosion_radius)

## Tankbomber detonation — grenade-style blast when the monster dies.
## How close the player must be to a Tankbomber blast to actually get hurt. Deliberately
## TIGHTER than the blast's visual radius (150) and than its monster-chaining reach: the player
## should only take damage when they're properly INSIDE the explosion, not when its faded outer
## edge merely grazes them. (Was `150 + player.radius` ≈ 166 px, which read as "hit from way too
## far away".) Applies to plain Tankbombers AND their hybrid mutants — both come through here.
const TANKBOMBER_PLAYER_RADIUS := 140.0

func _tankbomber_explode(pos: Vector2) -> void:
	var explosion_radius := Grenade.EXPLOSION_RADIUS
	for m: Node in monster_container.get_children():
		if not m is Monster:
			continue
		var monster := m as Monster
		if monster.is_spawning or monster.hp <= 0:
			continue  # already-dead monsters (incl. the bomber itself) are skipped
		if pos.distance_to(monster.global_position) <= explosion_radius + monster.radius:
			monster.prevent_split = true
			monster.take_damage(Grenade.DAMAGE)  # chains into other tankbombers
	# Player damage — tighter reach than the blast's visuals/chaining (see the const above).
	if not player.is_dead:
		if pos.distance_to(player.global_position) <= TANKBOMBER_PLAYER_RADIUS:
			player.take_damage(player.max_health * Grenade.PLAYER_DAMAGE_PERCENT)
	particles.spawn_death_particles(pos, Color(1.0, 0.5, 0.0), 40)
	AudioManager.play_sfx("grenade_explosion")
	_spawn_explosion_sprite(pos, explosion_radius)
	_add_shake(SHAKE_GRENADE)
	for crate_node: Node in _lootcrate_container.get_children():
		if not crate_node is LootCrate:
			continue
		var crate := crate_node as LootCrate
		if crate.hp <= 0:
			continue
		if pos.distance_to(crate.global_position) <= explosion_radius + 35.0:
			crate.take_hit(LootCrate.GRENADE_DMG)
	# Tankbomber blast destroys monster spawners too.
	_explode_spawners(pos, explosion_radius)
	_explode_turrets(pos, explosion_radius)

## "Counter-Charge": the laser killed a Brute that was mid-charge.
func _on_laser_monsters_hit(monsters: Array) -> void:
	# Sniper "die on miss": a laser that hits no monster ends the run immediately.
	if _level_mode and _level_manager and bool(_level_manager.die_on_miss) and monsters.is_empty():
		if player and not player.is_dead:
			player.take_zone_damage(99999.0)
		return
	for m in monsters:
		if m is Monster and (m as Monster).monster_type == MonsterTypes.Type.BRUTE and (m as Monster).is_charging():
			AchievementManager.unlock("game_killchargingbrutewithlaser")
			return

## Fire laser beam — instant full-map damage pass.
func _fire_laser(pos: Vector2, dir: Vector2) -> void:
	var has_fmj := _powerup_manager and _powerup_manager.has_active(Powerup.Type.FMJ)
	var has_bullet_boost := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_BOOST)
	var has_octoshoot := _powerup_manager and _powerup_manager.has_active(Powerup.Type.OCTOSHOOT)
	var has_freeze := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_FREEZE)

	# Build direction list based on active powerups
	var directions: Array[Vector2] = [dir]
	if has_octoshoot:
		# Octoshoot + Laser: fire 8 lasers in all compass directions
		directions.clear()
		for i in 8:
			directions.append(Vector2.from_angle(i * (TAU / 8.0)))
	elif has_bullet_boost:
		# Bulletboost + Laser: fire 3 lasers (same spread as triple shot)
		var spread_rad := deg_to_rad(player.powerup_spread_angle)
		directions.append(dir.rotated(spread_rad))
		directions.append(dir.rotated(-spread_rad))

	AudioManager.play_sfx("laser_shot")

	for d: Vector2 in directions:
		var laser := LaserBeam.new()
		laser.setup(pos, d, has_fmj)  # FMJ + Laser: 3x wider
		laser.is_freeze = has_freeze  # Freeze + Laser: no damage, freezes monsters for life
		laser.monsters_hit.connect(_on_laser_monsters_hit)  # connect BEFORE add_child (damage pass runs in _ready)
		add_child(laser)

		# Laser also hits lootcrates — check all crates against beam line
		var beam_length := maxf(arena_width, arena_height) * 2.0
		var half_w := laser.beam_width / 2.0
		var perp := Vector2(-d.y, d.x)
		for crate_node: Node in _lootcrate_container.get_children():
			if not crate_node is LootCrate:
				continue
			var crate := crate_node as LootCrate
			if crate.hp <= 0:
				continue
			var to_crate := crate.global_position - pos
			var along := to_crate.dot(d)
			var across := absf(to_crate.dot(perp))
			if along > -50.0 and along < beam_length and across <= half_w + 35.0:
				crate.take_hit(LootCrate.LASER_DMG)


func _activate_katana() -> void:
	# Remove any existing katana spin
	if _active_katana and is_instance_valid(_active_katana):
		_active_katana.queue_free()
	_katana_kill_count = 0  # fresh count for this swing

	var has_bullet_boost := _powerup_manager and _powerup_manager.has_active(Powerup.Type.SHOOT_BOOST)

	if has_bullet_boost:
		# Bulletboost + Katana: 2 katanas, one on each side
		_active_katana = KatanaSpin.new()
		_active_katana.setup(player, 0.0)  # First katana starts at angle 0
		_active_katana.monster_hit.connect(_on_katana_hit_monster)
		_active_katana.finished.connect(_on_katana_finished)
		add_child(_active_katana)
		# Second katana — opposite side
		var katana2 := KatanaSpin.new()
		katana2.setup(player, PI)  # Starts at 180 degrees (opposite)
		katana2.monster_hit.connect(_on_katana_hit_monster)
		add_child(katana2)
	else:
		_active_katana = KatanaSpin.new()
		_active_katana.setup(player)
		_active_katana.monster_hit.connect(_on_katana_hit_monster)
		_active_katana.finished.connect(_on_katana_finished)
		add_child(_active_katana)

	AudioManager.play_sfx("katana_equip")

func _on_katana_hit_monster(monster: Monster) -> void:
	if monster.hp > 0 and not monster.is_spawning:
		monster.prevent_split = true  # Katana kill prevents splitter from splitting
		monster.take_damage(KatanaSpin.KATANA_DAMAGE)
		AudioManager.play_sfx_random_at("katana_hit", 4, monster.global_position.x)
		_hit_stop()  # satisfying micro-freeze on katana impact (guarded against stacking)
		# Achievement: kills within a single katana swing
		if monster.hp <= 0:
			_katana_kill_count += 1
			if _katana_kill_count >= 10:
				AchievementManager.unlock("game_kill10enemieswithonekatanaswing")
		# HP Boost + Katana: heal 5 HP per kill
		if _powerup_manager and _powerup_manager.has_active(Powerup.Type.HP_BOOST):
			if monster.hp <= 0 and not player.is_dead:
				player.health = minf(player.health + 5.0, player.max_health)
				player.health_changed.emit(player.health, player.max_health)

func _on_katana_finished() -> void:
	_active_katana = null

func _activate_slowpill() -> void:
	_slowpill_active = true
	_slowpill_elapsed = 0.0
	# fixed_pitch=true: play the cue at normal pitch BEFORE set_sfx_pitch() slows everything,
	# and keep it exempt — otherwise the slow-motion drops it to 0.3x and it's inaudible.
	AudioManager.play_sfx("timestop_effect", 2.0, 0.0, true)
	Engine.time_scale = SLOWPILL_TIME_SCALE
	AudioManager.set_sfx_pitch(SLOWPILL_TIME_SCALE)
	AudioManager.set_music_pitch(SLOWPILL_TIME_SCALE)   # slow the music too

func _deactivate_slowpill() -> void:
	_slowpill_active = false
	AudioManager.set_sfx_pitch(1.0)
	AudioManager.set_music_pitch(1.0)
	if not _death_effect_active and not _stoppill_active:
		Engine.time_scale = 1.0

# ---- STOPPILL (time stop — flag-based) ----

func _activate_stoppill() -> void:
	_stoppill_active = true
	_stoppill_elapsed = 0.0
	GameManager.time_stopped = true
	# Cancel slowpill if active (stoppill overrides)
	if _slowpill_active:
		_slowpill_active = false
		Engine.time_scale = 1.0
		AudioManager.set_sfx_pitch(1.0)
		AudioManager.set_music_pitch(1.0)
	AudioManager.play_sfx("timestop_effect", 2.0)
	AudioManager.set_music_paused(true)   # freeze the music with time
	# Tint all monsters blue to show they're frozen
	_tint_all_monsters(Color(0.4, 0.6, 1.0, 1.0))
	# Show blue overlay at low opacity
	_show_stoppill_overlay(0.08)

func _process_stoppill(delta: float) -> void:
	_stoppill_elapsed += delta

	if _stoppill_elapsed >= STOPPILL_DURATION:
		_deactivate_stoppill()
		return

	if _stoppill_elapsed < STOPPILL_FADEIN_END:
		# Fade in: 0→1s — overlay fades from 0 to 0.08
		var t := _stoppill_elapsed / STOPPILL_FADEIN_END
		_update_stoppill_overlay(lerpf(0.0, 0.08, t))
	elif _stoppill_elapsed >= STOPPILL_FADEOUT_START:
		# Fade out: 8→10s — overlay fades from 0.08 to 0, monsters untint
		var t := (_stoppill_elapsed - STOPPILL_FADEOUT_START) / (STOPPILL_DURATION - STOPPILL_FADEOUT_START)
		_update_stoppill_overlay(lerpf(0.08, 0.0, t))
		# Lerp monster tint back to white
		var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.4, 0.6, 1.0), 1.0 - t)
		_tint_all_monsters(tint)

func _deactivate_stoppill() -> void:
	_stoppill_active = false
	GameManager.time_stopped = false
	AudioManager.set_music_paused(false)   # resume the music
	# Restore monster tints to white
	_tint_all_monsters(Color.WHITE)
	# Remove overlay
	_hide_stoppill_overlay()

func _tint_all_monsters(color: Color) -> void:
	for m: Node in monster_container.get_children():
		if m is Monster:
			var sprite: Sprite2D = m.get_node_or_null("Sprite2D")
			if sprite:
				sprite.modulate = color

func _show_stoppill_overlay(alpha: float) -> void:
	if _stoppill_overlay == null:
		_stoppill_overlay = ColorRect.new()
		_stoppill_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_stoppill_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stoppill_overlay.z_index = 100
		# Add to a CanvasLayer so it sits above game but below HUD
		var layer := CanvasLayer.new()
		layer.layer = 10  # Below HUD (11)
		layer.name = "StoppillOverlay"
		add_child(layer)
		layer.add_child(_stoppill_overlay)
	_stoppill_overlay.color = Color(0.2, 0.4, 1.0, alpha)
	_stoppill_overlay.visible = true

func _update_stoppill_overlay(alpha: float) -> void:
	if _stoppill_overlay:
		_stoppill_overlay.color = Color(0.2, 0.4, 1.0, alpha)

func _hide_stoppill_overlay() -> void:
	if _stoppill_overlay:
		var layer := _stoppill_overlay.get_parent()
		if layer:
			layer.queue_free()
		_stoppill_overlay = null

func _on_inventory_changed() -> void:
	if _inventory_ui and _item_manager:
		_inventory_ui.update_inventory(_item_manager.inventory, _item_manager)
		_inventory_ui.set_selected(_item_manager.selected_index)

func _on_item_selected(index: int) -> void:
	if _inventory_ui:
		_inventory_ui.set_selected(index)

func _on_inventory_tapped(index: int) -> void:
	if _item_manager == null or GameManager.is_game_over or player.is_dead:
		return
	if index < 0 or index >= _item_manager.inventory.size():
		return
	var type: ItemPickup.ItemType = _item_manager.inventory[index]
	_item_manager.use_item(index)  # Handles consumption, sounds, selection toggle
	# Apply instant effects
	match type:
		ItemPickup.ItemType.SLOWPILL:
			_activate_slowpill()
		ItemPickup.ItemType.KATANA:
			_activate_katana()
		ItemPickup.ItemType.HP25:
			player.health = minf(player.health + player.max_health * 0.15, player.max_health)
			player.health_changed.emit(player.health, player.max_health)
		# Grenade: handled via selection → spawn_bullet intercept
		# Laser: handled via selection → spawn_bullet intercept

# ============================================================
# LOOTCRATE SYSTEM
# ============================================================

## Free only BOSS healing metins on level reset (count_as_target=false) — those are
## parented to us and would otherwise linger across a respawn. LEVEL-placed metins
## (count_as_target=true, e.g. key metins) live in the level layout and reload with it,
## so they MUST be kept — freeing them here broke every metin-key level.
func _clear_metins() -> void:
	for m: Node in get_tree().get_nodes_in_group("metins"):
		if is_instance_valid(m) and not bool(m.get("count_as_target")):
			m.queue_free()

## Wipe keys dropped by metins in a previous life/level (authored keys re-spawn with the
## layout, so they aren't in this group and are untouched).
func _clear_dropped_keys() -> void:
	for k: Node in get_tree().get_nodes_in_group("dropped_keys"):
		if is_instance_valid(k):
			k.queue_free()

func _process_lootcrate_spawning(delta: float) -> void:
	# Positive gate: this loose-prop spawner (the % lootcrate / % metin rolls) runs ONLY in
	# true Endless mode. Numbered levels and challenges never enable it, so a boss level
	# can never grow loose (non-boss) metins/crates. Belt: also bail if a boss is present.
	if not _endless_props_active:
		return
	if not get_tree().get_nodes_in_group("boss").is_empty():
		return
	if not _lootcrate_container:
		return
	_lootcrate_spawn_timer += delta
	if _lootcrate_spawn_timer < 1.0:
		return
	_lootcrate_spawn_timer -= 1.0
	# ONE shared roll per second for both prop kinds, then a 25/75 split (metin/crate).
	# A kind at its own cap hands the spawn to the other; both capped = nothing.
	# (Metins live in _lootcrate_container too, so caps are counted per KIND — counting
	# raw children here once starved crates completely.)
	if randf() >= PROP_SPAWN_CHANCE:
		return
	var crates := 0
	for c: Node in _lootcrate_container.get_children():
		if c is LootCrate and (c as LootCrate).hp > 0:
			crates += 1
	var metins := get_tree().get_nodes_in_group("metins").size()
	var want_metin := randf() < PROP_METIN_SHARE
	if want_metin and metins >= METIN_MAX:
		want_metin = false
	if not want_metin and crates >= LOOTCRATE_MAX:
		if metins >= METIN_MAX:
			return
		want_metin = true
	if want_metin:
		_spawn_metin()
	else:
		_spawn_lootcrate()

func _spawn_lootcrate() -> void:
	var pos := Vector2(
		randf_range(LOOTCRATE_SPAWN_MARGIN, arena_width - LOOTCRATE_SPAWN_MARGIN),
		randf_range(LOOTCRATE_SPAWN_MARGIN, arena_height - LOOTCRATE_SPAWN_MARGIN)
	)
	var crate := LootCrate.new()
	crate.global_position = pos
	crate.destroyed.connect(_on_lootcrate_destroyed)
	_lootcrate_container.add_child(crate)

## Endless: a Metin totem (random colour) that fights back when shot (spawns scaling
## monsters) and drops 2 loot rolls when destroyed. Shares the loot-crate spawn budget.
func _spawn_metin() -> void:
	if _lootcrate_container == null:
		return
	var pos := Vector2(
		randf_range(LOOTCRATE_SPAWN_MARGIN, arena_width - LOOTCRATE_SPAWN_MARGIN),
		randf_range(LOOTCRATE_SPAWN_MARGIN, arena_height - LOOTCRATE_SPAWN_MARGIN)
	)
	var script: Script = load("res://scripts/game/level/level_metin.gd")
	var m := StaticBody2D.new()
	m.set_script(script)
	m.set("color", ["blue", "green", "red"].pick_random())
	m.set("size", 140.0)
	m.set("max_hp", 700.0)
	m.set("random_type", true)
	m.set("spawn_count", 2)
	m.set("spawn_per_damage", 250.0)
	m.set("drop_count", 2)
	m.global_position = pos
	_lootcrate_container.add_child(m)

func _on_bullet_hit_crate(bullet: Bullet, crate: LootCrate) -> void:
	if crate.hp <= 0:
		return
	var dmg := LootCrate.FMJ_BULLET_DMG if bullet.is_fmj else LootCrate.NORMAL_BULLET_DMG
	var destroyed := crate.take_hit(dmg)
	# Impact particles + a gentle rumble on a surviving hit (same "juice" as shooting a monster;
	# a destroying hit gets its bigger punch in _on_lootcrate_destroyed instead).
	particles.spawn_impact_particles(bullet.global_position, Color(0.6, 0.4, 0.2))
	if not destroyed:
		_add_shake(SHAKE_KILL * 0.7)

func _on_lootcrate_destroyed(crate: LootCrate) -> void:
	var pos := crate.global_position
	# Break particles + chunky wooden gibs that settle into the paint, plus a firm shake —
	# the same immersive burst a monster kill gets. (Break sound plays in LootCrate._break.)
	particles.spawn_death_particles(pos, Color(0.6, 0.4, 0.2), 12)
	particles.spawn_gibs(pos, Color(0.55, 0.4, 0.22), CMath.rand_int(5, 7))
	_add_shake(SHAKE_KILL_BIG)

	# Roll loot
	var loot_type := crate.get_loot_type()
	match loot_type:
		LootCrate.LootType.ITEM:
			_drop_random_item(pos)
		LootCrate.LootType.POWERUP:
			_drop_random_powerup(pos)
		LootCrate.LootType.RARE_POWERUP:
			_drop_rare_powerup(pos)

func _drop_random_item(pos: Vector2) -> void:
	if _item_manager == null:
		return
	if _level_mode:
		# 1-HP levels: drop any item EXCEPT the HP+25 heal (useless at 1 HP).
		var types := [ItemPickup.ItemType.GRENADE, ItemPickup.ItemType.SLOWPILL,
					  ItemPickup.ItemType.KATANA, ItemPickup.ItemType.LASER,
					  ItemPickup.ItemType.DECOY]
		_item_manager._spawn_pickup(types[randi() % types.size()], pos)
	else:
		_item_manager._spawn_item_at(pos)

func _drop_random_powerup(pos: Vector2) -> void:
	# Spawn a normal powerup pickup at this position
	var types := [Powerup.Type.SHOOT_BOOST, Powerup.Type.SPEED_BOOST, Powerup.Type.FMJ]
	if not _level_mode:
		types.append(Powerup.Type.HP_BOOST)   # HP boost is pointless in 1-HP levels/challenges
	if not _numbered_level:
		types.append(Powerup.Type.CLEANER)    # Cleaner is removed from numbered levels (per design)
	var type: Powerup.Type = types[randi() % types.size()]
	_spawn_powerup_at(pos, type)

func _drop_rare_powerup(pos: Vector2) -> void:
	# Spawn a rare powerup at this position
	var rare_types := [Powerup.Type.OCTOSHOOT, Powerup.Type.SHURIKEN, Powerup.Type.SHOOT_BOUNCE]
	if not _numbered_level:
		# HP-max, Time-Stop and Cleaner-max are all excluded from numbered levels.
		rare_types.append(Powerup.Type.HPBOOSTMAX)
		rare_types.append(Powerup.Type.STOPPILL)
		rare_types.append(Powerup.Type.CLEANERMAX)
	var type: Powerup.Type = rare_types[randi() % rare_types.size()]
	_spawn_powerup_at(pos, type)

## One loot roll at `pos`: 40% item, 40% powerup, 20% rare powerup (loot-crate odds).
func _roll_and_drop_loot(pos: Vector2) -> void:
	var r := randf()
	if r < 0.40:
		_drop_random_item(pos)
	elif r < 0.80:
		_drop_random_powerup(pos)
	else:
		_drop_rare_powerup(pos)

## Public: a destroyed Metin totem drops `count` loot rolls (1 in the Totem challenge,
## 2 in endless), each 40/40/20 item/powerup/rare. Every drop spawns at the totem's centre
## and gets TOSSED a short hop in its own random direction (little scatter pop).
func drop_metin_loot(pos: Vector2, count: int = 1) -> void:
	for i in maxi(count, 1):
		_roll_and_drop_loot(pos)
	# Some drops add_child DEFERRED (item manager), so scan for the new arrivals at idle
	# time and toss each un-tossed pickup near the totem outward (deferred = after they land).
	_toss_metin_drops.call_deferred(pos)

## Toss every not-yet-tossed pickup sitting at the totem centre a short hop outward.
func _toss_metin_drops(pos: Vector2) -> void:
	for cont in [_powerup_container, _item_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			if not (c is Node2D) or c.has_meta("metin_tossed"):
				continue
			if (c as Node2D).global_position.distance_to(pos) > 20.0:
				continue   # not from this totem
			c.set_meta("metin_tossed", true)
			var off := Vector2.from_angle(randf() * TAU) * randf_range(45.0, 95.0)
			var tw := (c as Node2D).create_tween()
			tw.tween_property(c, "global_position", pos + off, 0.3) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Spawn a powerup pickup at a specific position (used by lootcrate drops).
func _spawn_powerup_at(pos: Vector2, type: Powerup.Type) -> void:
	# Time-Stop + Cleaner effects are removed from numbered levels — catch every path
	# (crate/metin/explicit pickup) here and swap to a plain offensive powerup.
	if _numbered_level and type in [Powerup.Type.STOPPILL, Powerup.Type.CLEANER, Powerup.Type.CLEANERMAX]:
		type = Powerup.Type.SHOOT_BOOST
	var scene: PackedScene = load("res://scenes/game/powerup.tscn")
	if scene == null or _powerup_container == null:
		return
	var powerup: Powerup = scene.instantiate() as Powerup
	var tex: Texture2D = _powerup_manager.get_texture(type)
	powerup.initialize(type, tex, 66.0)
	powerup.global_position = pos
	# Connect collected signal — activate() triggers _on_powerup_activated which handles HUD + SFX
	powerup.collected.connect(func(p: Powerup) -> void:
		_powerup_manager.activate(p.powerup_type)
	)
	# Loot-crate drops run inside the bullet→crate collision flush, so adding the
	# pickup (which registers its CollisionShape2D with the physics server on
	# enter_tree) must be deferred to avoid "Can't change this state while
	# flushing queries". Position is retained since the container is at the origin.
	_powerup_container.call_deferred("add_child", powerup)

# ============================================================
# SHURIKEN
# ============================================================

func _activate_shuriken() -> void:
	# Remove any existing shurikens first
	_deactivate_shuriken()
	# Spawn two shurikens orbiting on opposite sides (0° and 180°)
	for start_angle: float in [0.0, PI]:
		var sh := ShurikenOrbit.new()
		sh.setup(player, start_angle)
		sh.monster_hit.connect(_on_shuriken_hit_monster)
		add_child.call_deferred(sh)   # deferred: powerup pickup runs in a physics flush; _ready sets Area2D monitoring
		_active_shurikens.append(sh)

func _deactivate_shuriken() -> void:
	for sh in _active_shurikens:
		if sh and is_instance_valid(sh):
			sh.remove()
	_active_shurikens.clear()

func _on_shuriken_hit_monster(monster: Monster) -> void:
	if monster.hp > 0 and not monster.is_spawning:
		monster.prevent_split = true
		monster.take_damage(ShurikenOrbit.SHURIKEN_DAMAGE)
		AudioManager.play_sfx_random_at("katana_hit", 4, monster.global_position.x)

# ============================================================
# VISUAL EFFECTS
# ============================================================

## Grenade explosion sprite — scales up extremely fast to blast radius, then fades out.
func _spawn_explosion_sprite(pos: Vector2, explosion_radius: float = Grenade.EXPLOSION_RADIUS, is_fmj: bool = false, is_cleaner: bool = false, grayscale: bool = false) -> void:
	var tex_path := "res://assets/sprites/items/grenade_explosion.svg"
	if not ResourceLoader.exists(tex_path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.global_position = pos
	sprite.z_index = 8  # Above monsters and katana
	# Grayscale (Decoy): desaturate to black & white via shader. Otherwise FMJ=red,
	# Cleaner=light blue tint.
	if grayscale:
		var gs_path := "res://assets/shaders/grayscale_sprite.gdshader"
		if ResourceLoader.exists(gs_path):
			var mat := ShaderMaterial.new()
			mat.shader = load(gs_path)
			sprite.material = mat
	elif is_fmj:
		sprite.modulate = Color(1.0, 0.3, 0.3)
	elif is_cleaner:
		sprite.modulate = Color(0.4, 0.8, 1.0)
	# Start tiny
	sprite.scale = Vector2(0.05, 0.05)
	add_child(sprite)
	# Calculate target scale so sprite matches explosion radius diameter
	var tex_size := sprite.texture.get_size()
	var target_diameter := explosion_radius * 2.0
	var target_sf := target_diameter / maxf(tex_size.x, tex_size.y)
	# Scale up extremely fast (0.15s), then fade out (0.4s)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(target_sf, target_sf), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(sprite.queue_free)

## Green heal flash on a monster — same pattern as red damage flash but green + longer.
func _flash_heal(monster: Monster) -> void:
	var sprite: Sprite2D = monster.get_node_or_null("Sprite2D")
	if sprite == null or not monster.is_inside_tree():
		return
	var tw := monster.create_tween()
	tw.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.0)  # Bright white flash
	tw.tween_interval(0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)

## Called when a healer monster pulses — flash healed monsters green + show heal aura.
func _on_healer_pulse(healer: Monster, healed_monsters: Array) -> void:
	# Flash each healed monster green
	for m in healed_monsters:
		if m is Monster and is_instance_valid(m):
			_flash_heal(m as Monster)
	# Heal effect aura on the healer itself
	if is_instance_valid(healer):
		_spawn_heal_effect(healer.global_position)

## Heal effect sprite — spawns on the healer, fades out over 1.5s.
func _spawn_heal_effect(healer_pos: Vector2) -> void:
	var tex_path := "res://assets/sprites/enemies/heal_effect.svg"
	if not ResourceLoader.exists(tex_path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.global_position = healer_pos
	sprite.z_index = 4  # Under monsters (monsters z=6)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)  # 70% opacity
	# Scale to match heal radius diameter
	var tex_size := sprite.texture.get_size()
	var heal_radius: float = MonsterTypes.STATS[MonsterTypes.Type.HEALER].get("heal_radius", 165.0)
	var sf := (heal_radius * 2.0) / maxf(tex_size.x, tex_size.y)
	sprite.scale = Vector2(sf, sf)
	add_child(sprite)
	# Fade out over 1.5s
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(sprite.queue_free)

# ============================================================
# CLEANERMAX (instant clear-all-paint rare powerup)
# ============================================================

var _cleanmax_ring_tex: Texture2D = null

## Instant rare powerup: wipes ALL floor paint with an expanding shockwave sweep.
func _activate_cleanermax() -> void:
	var center := player.global_position if is_instance_valid(player) \
		else Vector2(arena_width * 0.5, arena_height * 0.5)

	# Radius needed to reach the farthest arena corner from the player.
	var corners := [Vector2.ZERO, Vector2(arena_width, 0.0),
					Vector2(0.0, arena_height), Vector2(arena_width, arena_height)]
	var max_dist := 0.0
	for c: Vector2 in corners:
		max_dist = maxf(max_dist, center.distance_to(c))

	# Expanding cyan ring sprite (the visible "sweep").
	if _cleanmax_ring_tex == null:
		_cleanmax_ring_tex = _make_ring_texture(256, 0.18)
	var ring := Sprite2D.new()
	ring.texture = _cleanmax_ring_tex
	ring.global_position = center
	ring.z_index = 9
	ring.modulate = Color(0.4, 0.9, 1.0, 0.95)
	ring.scale = Vector2(64.0 / 256.0, 64.0 / 256.0)
	add_child(ring)

	var end_sf := (max_dist * 2.2) / 256.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(end_sf, end_sf), 0.55) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(ring, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)

	# Brief cyan full-screen flash for punch.
	_flash_fullscreen(Color(0.4, 0.9, 1.0, 0.22), 0.35)

	# Wipe all paint shortly after the wave launches (reads as the wave clearing it).
	var clear_timer := get_tree().create_timer(0.12)
	clear_timer.timeout.connect(func() -> void:
		if is_instance_valid(floor_paint):
			floor_paint.clear()
	)

	# Decorative particle burst.
	if is_instance_valid(particles):
		particles.spawn_death_particles(center, Color(0.4, 0.9, 1.0), 24)

## Build a soft-edged white ring (annulus) texture, tinted via modulate.
func _make_ring_texture(size: int, thickness_frac: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(size * 0.5, size * 0.5)
	var outer := size * 0.5
	var inner := outer * (1.0 - thickness_frac)
	var mid := (outer + inner) * 0.5
	var half_band := maxf((outer - inner) * 0.5, 1.0)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= outer and d >= inner:
				var a := clampf(1.0 - absf(d - mid) / half_band, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

## One-shot full-screen color flash that fades out and self-frees.
func _flash_fullscreen(color: Color, duration: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = color
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)

# ============================================================
# SCREEN SHAKE + DAMAGE VIGNETTE
# ============================================================

## Request a screen shake of the given strength (px). Keeps the strongest pending.
## Every shake source funnels through here, so the comfort toggle is honoured everywhere.
## Read live (not cached): Settings can be opened mid-run from the pause menu.
func _add_shake(amount: float) -> void:
	if not bool(SaveManager.get_setting("screen_shake", true)):
		return
	_shake_strength = maxf(_shake_strength, amount)

## Record a kill at `pos` on the coarse heat map and return the local pool factor (0..1)
## BEFORE this kill — 0 = fresh spot, 1 = you've been slaughtering here. Drives the
## "rampage" paint pooling (darker + bigger splats where kills stack up).
func _register_kill_heat(pos: Vector2) -> float:
	var cell := Vector2i(int(floor(pos.x / KILL_HEAT_CELL)), int(floor(pos.y / KILL_HEAT_CELL)))
	var h: float = float(_kill_heat.get(cell, 0.0))
	var pool: float = clampf(h / KILL_HEAT_MAX, 0.0, 1.0)
	_kill_heat[cell] = minf(h + 1.0, KILL_HEAT_MAX)
	return pool

## Cool the kill-heat map every frame so old battlegrounds fade back to "fresh".
func _decay_kill_heat(delta: float) -> void:
	if _kill_heat.is_empty():
		return
	var drop := KILL_HEAT_DECAY * delta
	var stale: Array = []
	for cell: Vector2i in _kill_heat:
		var h: float = float(_kill_heat[cell]) - drop
		if h <= 0.0:
			stale.append(cell)
		else:
			_kill_heat[cell] = h
	for cell: Vector2i in stale:
		_kill_heat.erase(cell)

## A throwaway copy of the monster's sprite that quickly inflates and bursts (fades) — the
## "pop" of the death squash-and-stretch. The real monster is queue_free'd right after.
## Plain Sprite2D, so adding it during the physics flush is safe (like the charge-ghost).
func _spawn_death_pop(monster: Monster) -> void:
	var src := monster.get_node_or_null("Sprite2D") as Sprite2D
	if src == null or src.texture == null:
		return
	var pop := Sprite2D.new()
	pop.texture = src.texture
	pop.material = src.material          # keep special-hybrid donor tint
	pop.global_position = monster.global_position
	pop.rotation = src.global_rotation
	pop.scale = src.global_scale
	pop.z_index = 6
	add_child(pop)
	var base: Vector2 = pop.scale
	var tw := create_tween()
	tw.tween_property(pop, "scale", base * 1.55, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.13)
	tw.chain().tween_callback(pop.queue_free)

## Make every monster within a small radius of a death cringe (a quick startle pop). The
## pack visibly reacts to each kill instead of ignoring their falling neighbours.
func _flinch_monsters_near(pos: Vector2, exclude: Monster) -> void:
	const FLINCH_R2 := 130.0 * 130.0
	for m in monster_container.get_children():
		if m == exclude or not (m is Monster):
			continue
		var mm := m as Monster
		if mm.global_position.distance_squared_to(pos) <= FLINCH_R2:
			mm.flinch()

## Tiny global freeze for "impact" feel (big kills / katana). Uses Engine.time_scale and
## an unscaled real-time timer so it un-freezes itself. Skipped while a slow/stop time
## effect is active (so it can't fight slowpill/stoppill) and guarded against stacking.
func _hit_stop() -> void:
	if _hit_stop_active or _slowpill_active or _stoppill_active or GameManager.time_stopped:
		return
	if GameManager.is_game_over or player.is_dead:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.0
	# ignore_time_scale=true → the timer still ticks in real seconds while frozen.
	await get_tree().create_timer(HIT_STOP_DURATION, true, false, true).timeout
	# Only restore if no real time effect took over while we were frozen.
	if not _slowpill_active and not _stoppill_active and not GameManager.time_stopped:
		Engine.time_scale = 1.0
	_hit_stop_active = false

## Per-frame: follow the player with the camera, and apply decaying screen-shake as a
## (non-smoothed) camera offset so it stays crisp instead of being smoothed away.
func _update_camera(delta: float) -> void:
	if _camera and is_instance_valid(_camera) and player:
		_camera.global_position = player.global_position
		if _shake_strength > 0.05:
			_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
			_shake_strength = move_toward(_shake_strength, 0.0, SHAKE_DECAY * delta)
		elif _camera.offset != Vector2.ZERO:
			_camera.offset = Vector2.ZERO
	# The world root stays at origin now — shake lives on the camera.
	if position != Vector2.ZERO:
		position = Vector2.ZERO
	# Cool the rampage paint-pool map so old battlegrounds fade back to "fresh".
	_decay_kill_heat(delta)

## Create the vignette overlay once (lazy — only when first hit happens).
func _ensure_vignette() -> void:
	if is_instance_valid(_vignette_rect):
		return
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.layer = 12
	add_child(_vignette_layer)
	_vignette_rect = ColorRect.new()
	_vignette_rect.anchor_right = 1.0
	_vignette_rect.anchor_bottom = 1.0
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.color = Color.WHITE
	var shader_path := "res://assets/shaders/damage_vignette.gdshader"
	if ResourceLoader.exists(shader_path):
		_vignette_mat = ShaderMaterial.new()
		_vignette_mat.shader = load(shader_path)
		_vignette_mat.set_shader_parameter("intensity", 0.0)
		_vignette_mat.set_shader_parameter("vig_color", Color(1.0, 0.0, 0.0, 1.0))
		_vignette_rect.material = _vignette_mat
	# Hidden until something actually flashes it. A full-screen fragment shader is fill-rate
	# heavy on phones — leaving it visible at intensity 0 burned GPU every frame after the
	# first hit for the whole run. Shown on flash/danger, hidden again when it fades to 0.
	_vignette_rect.visible = false
	_vignette_layer.add_child(_vignette_rect)

## Hide the full-screen vignette rect once it has faded out (stops it rendering when idle).
func _hide_vignette() -> void:
	if is_instance_valid(_vignette_rect):
		_vignette_rect.visible = false

## Flash the red damage vignette: spike to peak, fade out.
func _flash_damage_vignette() -> void:
	_ensure_vignette()
	if _vignette_mat == null:
		return
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_rect.visible = true
	_vignette_mat.set_shader_parameter("intensity", 0.55)
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(
		func(v: float) -> void: _vignette_mat.set_shader_parameter("intensity", v),
		0.55, 0.0, 0.45).set_ease(Tween.EASE_OUT)
	_vignette_tween.finished.connect(_hide_vignette)

## Sustained red edge vignette while the player stands in a danger zone — it
## gently pulses (as if continuously taking damage) and fades out on exit.
func _update_danger_vignette(active: bool, delta: float) -> void:
	if active:
		_ensure_vignette()
		if _vignette_mat == null:
			return
		# Take over the intensity from any one-shot flash tween.
		if _vignette_tween and _vignette_tween.is_valid():
			_vignette_tween.kill()
		_vignette_rect.visible = true
		_danger_vig_time += delta
		var pulse := 0.42 + 0.12 * sin(_danger_vig_time * 6.0)
		_vignette_mat.set_shader_parameter("intensity", pulse)
		_in_danger_zone = true
	elif _in_danger_zone:
		# Player just left the danger zone — fade the sustained vignette out.
		_in_danger_zone = false
		_danger_vig_time = 0.0
		if _vignette_mat:
			if _vignette_tween and _vignette_tween.is_valid():
				_vignette_tween.kill()
			var start_v: float = _vignette_mat.get_shader_parameter("intensity")
			_vignette_tween = create_tween()
			_vignette_tween.tween_method(
				func(v: float) -> void: _vignette_mat.set_shader_parameter("intensity", v),
				start_v, 0.0, 0.3).set_ease(Tween.EASE_OUT)
			_vignette_tween.finished.connect(_hide_vignette)

# ============================================================
# ZONE EFFECTS
# ============================================================

func _process_zone_effects(delta: float) -> void:
	if _level_mode:
		return   # custom levels don't use auto zones
	if not _zone_manager or not _zone_manager.is_running:
		return

	var effects := _zone_manager.process_zone_effects(player.global_position, delta)

	# Timeboost: accelerate game timer 2x
	if effects["timeboost"]:
		GameManager.elapsed_time += delta  # Extra tick (normal tick already in GameManager)
		hud.set_time_boosted(true)
		# "Time Lord": 60s spent inside timeboost zones in one life (endless only)
		_timeboost_life_time += delta
		if _timeboost_life_time >= 60.0 and not _level_mode:
			AchievementManager.unlock("endless_1minuteintimeboostzone_onelife")
	else:
		hud.set_time_boosted(false)

	# Danger zone: continuous DPS as a fraction of max HP — bypasses i-frames.
	# total_damage is a fraction-per-frame; resolve it against the player's max HP.
	var dmg_fraction: float = effects["total_damage"]
	var in_danger := dmg_fraction > 0.0
	if in_danger:
		_applying_zone_damage = true   ## Suppress the per-frame hit shake/flash
		player.take_zone_damage(dmg_fraction * player.max_health)
		_applying_zone_damage = false
	_update_danger_vignette(in_danger, delta)

const TIMEBOOST_CRATE_THRESHOLD := 10.0  ## Seconds player must be inside timeboost zone

func _on_zone_expired(zone: Zone) -> void:
	# If player spent 10+ seconds in a timeboost zone, spawn a lootcrate
	if zone.zone_type == Zone.Type.TIMEBOOST and zone.player_time_inside >= TIMEBOOST_CRATE_THRESHOLD:
		_spawn_lootcrate()
