extends Node
## SaveManager - Persistent save/load system (Autoload)
## Replaces SharedObject from Flash. Uses JSON file in user:// directory.

const SAVE_PATH := "user://colorsplat_save.json"
## Written first, then renamed over SAVE_PATH — a kill mid-write can only ever destroy the
## temp file, never the live save. The previous save is kept as a fallback.
const SAVE_TMP_PATH := "user://colorsplat_save.tmp"
const SAVE_BAK_PATH := "user://colorsplat_save.bak"
const SAVE_VERSION := 1

# ---- SAVE DATA (in-memory, synced to disk) ----
var data: Dictionary = {}

func _ready() -> void:
	load_game()

# ============================================================
# SAVE / LOAD
# ============================================================

## ATOMIC write. Opening SAVE_PATH for WRITE truncates it instantly, so a kill between the
## truncate and the flush (Android does this to backgrounded apps, and gameplay flushes stats
## every 2 s) used to leave an EMPTY save = total progress loss. Now the JSON goes to a temp
## file, the live save is copied to .bak, and only then is the temp renamed into place.
func save_game() -> void:
	_stats_dirty = false   # this write persists any pending stat changes
	var json := JSON.stringify(data, "\t")

	var file := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot open temp save for writing")
		return
	file.store_string(json)
	file.flush()
	file.close()

	# Sanity: never promote a temp file that didn't land intact.
	if not _file_holds_valid_json(SAVE_TMP_PATH):
		push_warning("SaveManager: temp save is corrupt, keeping the previous save")
		return

	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if FileAccess.file_exists(SAVE_PATH):
		dir.remove(SAVE_BAK_PATH)                 # rename fails onto an existing file
		dir.rename(SAVE_PATH, SAVE_BAK_PATH)      # previous good save becomes the backup
	dir.rename(SAVE_TMP_PATH, SAVE_PATH)

## True if `path` exists and parses as a JSON dictionary.
func _file_holds_valid_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	return JSON.parse_string(txt) is Dictionary

func load_game() -> void:
	# Live save first; fall back to the backup if it's missing or corrupt (interrupted write
	# on an older build, disk error, …) so a bad file can't wipe the player's progress.
	for path in [SAVE_PATH, SAVE_BAK_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var json_text := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if parsed is Dictionary:
			data = parsed
			if path == SAVE_BAK_PATH:
				push_warning("SaveManager: main save unreadable, recovered from backup")
			# Backfill keys added in newer app versions (never overwrites existing values).
			if _merge_defaults(data, _default_data()):
				save_game()
			_migrate_save()
			return
	_create_default_save()

func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"settings": {
			"music_volume": 80,
			"sfx_volume": 50,
			"vibration": true,
			"screen_shake": true,       ## comfort/accessibility: disable camera shake
			"orientation": "auto",
			"quality": "high",
			"paint_quality": "mid",
			"fps_limit": 60,
			"joystick_size": 1.0,
			"joystick_opacity": 0.5,
			"language": "system",
			"player_indicator": false,  ## accessibility: highlight ring around player
			"indicator_color": "26ffff",  ## hex (rrggbb) ring color, default cyan
			"color_distinction": 0.5,   ## 0..1: how much darker floor splats are vs monsters
			"bg_brightness": 0.3,       ## 0..1: lightens the (dark) game background/floor
			# Both read the platform-aware defaults below — NEVER hardcode these. A fresh install
			# goes through _create_default_save() and skips _migrate_save(), so a stale literal
			# here is what the player actually gets (a 1.6 literal fell under GAME_ZOOM_MIN and
			# clamped the phone to the minimum zoom instead of the "1.0×" default).
			"game_gui_scale": GAME_GUI_DEFAULT,  ## multiplier on the IN-GAME overlays (HUD, inventory, joysticks)
			"game_zoom": GAME_ZOOM_DEFAULT,      ## in-game camera zoom (shown as "1.0×" on the slider)
			"left_handed": false,       ## swap the move (left) and aim (right) joysticks
			"hpbar_opacity": 1.0,       ## 0..1 base opacity of the bottom HP gauge
			"dynamic_opacity": true,    ## fade the HP gauge to 40% when the player is near it
		},
		"progress": {
			"levels_unlocked": 1,
			"level_times": {},
			"level_stars": {},
			"endless_best_time": 0.0,
			"challenges_completed": [],   ## ids of completed challenges (for the select screen)
			"challenge_stars": {},        ## id -> best star count (0-3)
		},
		"cosmetics": {
			"owned_skins": ["default"],
			"owned_trails": ["none"],
			"equipped_skin": "default",
			"equipped_trail": "none",
			"boxes_available": 0,
			"last_box_open": 0,   ## unix time of last lucky-box open (24h free cooldown)
		},
		"stats": {
			"total_kills": 0,
			"total_deaths": 0,
			"total_play_time": 0.0,
			"total_levels_completed": 0,
			"total_ads_watched": 0,
			"total_bullets_fired": 0,
			"longest_powerup": 0.0,
			"highest_level": 0,
			"highest_tier": 0,
			"kills_basic": 0,
			"kills_tank": 0,
			"kills_speeder": 0,
			"kills_brute": 0,
			"kills_healer": 0,
			"kills_spawner": 0,
			"kills_splitter": 0,
			"kills_ghost": 0,
			"kills_tankbomber": 0,
			"endless_best_kills": 0,
			"longest_session_time": 0.0,
		},
		"achievements": [],   ## list of unlocked achievement ids
		"gdpr_consent": false,
		"first_launch": true,
		"tutorial_completed": false,
	}

func _create_default_save() -> void:
	data = _default_data()
	save_game()

## Recursively fill any keys MISSING from `target` with the defaults, WITHOUT touching
## values the player already has. Run on every load so a save written by an OLDER app
## version gains keys/sections added in later updates (new settings, stats, cosmetic
## slots, …). Player progress + inventory are always preserved. Returns true if anything
## was added (so the caller can persist it).
func _merge_defaults(target: Dictionary, defaults: Dictionary) -> bool:
	var changed := false
	for key in defaults:
		if not target.has(key):
			target[key] = defaults[key]
			changed = true
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			if _merge_defaults(target[key], defaults[key]):
				changed = true
	return changed

func _migrate_save() -> void:
	# Handle save version migrations if needed
	var version: int = data.get("version", 0)
	if version < SAVE_VERSION:
		# Future migration logic goes here
		data["version"] = SAVE_VERSION
		save_game()
	# ONE-TIME mobile GUI rescale (2026-07): phones get the bigger in-game GUI. Mobile-only,
	# once — after that the player's own slider always wins.
	if OS.has_feature("mobile") and not bool(get_setting("mobile_scale_v3", false)):
		set_setting("game_gui_scale", GAME_GUI_DEFAULT)
		set_setting("mobile_scale_v2", true)
		set_setting("mobile_scale_v3", true)
	# ONE-TIME zoom reset (2026-07): default stored 2.2 (now shown as "1.0×", middle of a
	# stored 1.7–2.7 = "0.5×–1.5×" slider). Reset EVERY platform to the default once (old saves
	# used a different scale); after that the slider wins.
	if not bool(get_setting("zoom_scale_v4", false)):
		set_setting("game_zoom", GAME_ZOOM_DEFAULT)
		set_setting("zoom_scale_v4", true)

# ============================================================
# SETTINGS HELPERS
# ============================================================

func get_setting(key: String, default_val = null):
	return data.get("settings", {}).get(key, default_val)

func set_setting(key: String, value) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"][key] = value
	save_game()

# ---- Mobile / display convenience getters (with safe defaults for old saves) ----
## Menus render at this FIXED scale (the tuned "good" size). The game_gui_scale
## setting only multiplies the IN-GAME overlays (HUD, inventory, joysticks).
## Bumped 1.2 → 1.4 (overall menus a bit larger for phones).
const MENU_GUI_SCALE := 1.4
## The IN-GAME overlay baseline (mobile readability). The slider value (0.5-1.5)
## stacks ON TOP of this so the user's "1.0×" = a comfortable mobile size.
## (= old 1.35 baked with the user's preferred 0.7× → the new default "1.0×".)
const GAME_GUI_BASELINE := 0.945
## PLATFORM defaults: on phones everything is physically tiny at the desktop tuning, so
## fresh mobile installs start much closer (zoom 2.6 ≈ 1.7x bigger player) with a bigger
## in-game GUI. Monster speed auto-compensates for the zoom (see game_world), so the
## reaction time stays the same. Desktop keeps the original 1.5 / 1.0.
var GAME_GUI_DEFAULT: float = 1.25 if OS.has_feature("mobile") else 1.0
const GAME_GUI_MIN := 0.5       ## "0.5×"
const GAME_GUI_MAX := 1.5       ## "1.5×"
## Zoom slider shows `stored − 1.2` (pure relabel; camera math uses the raw stored value).
## Default = stored 2.2 → shown as "1.0×" and sits in the MIDDLE of the slider (the user's own
## preferred zoom). Range stored 1.7–2.7 → shown as "0.5×–1.5×". Same on desktop + mobile.
var GAME_ZOOM_DEFAULT: float = 2.2
const GAME_ZOOM_MIN := 1.7      ## shown as "0.5×"
const GAME_ZOOM_MAX := 2.7      ## shown as "1.5×"

func get_game_gui_scale() -> float:
	return clampf(float(get_setting("game_gui_scale", GAME_GUI_DEFAULT)), GAME_GUI_MIN, GAME_GUI_MAX)

func set_game_gui_scale(v: float) -> void:
	set_setting("game_gui_scale", clampf(v, GAME_GUI_MIN, GAME_GUI_MAX))

func get_game_zoom() -> float:
	return clampf(float(get_setting("game_zoom", GAME_ZOOM_DEFAULT)), GAME_ZOOM_MIN, GAME_ZOOM_MAX)

func set_game_zoom(v: float) -> void:
	set_setting("game_zoom", clampf(v, GAME_ZOOM_MIN, GAME_ZOOM_MAX))

func is_left_handed() -> bool:
	return bool(get_setting("left_handed", false))

func set_left_handed(v: bool) -> void:
	set_setting("left_handed", v)

## Viewport-responsive UI scale factor (design space 1920x1080) at the fixed menu
## scale. Pass the viewport's visible size.
func ui_sf(viewport_size: Vector2) -> float:
	return minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0) * MENU_GUI_SCALE

## ui_sf multiplied by the GAME baseline and the user's game-GUI setting — for
## IN-GAME overlays only (HUD, inventory, virtual joysticks). The baseline bakes
## in a mobile-readable default so the user's slider "1.0×" already looks big.
func ui_sf_game(viewport_size: Vector2) -> float:
	return ui_sf(viewport_size) * GAME_GUI_BASELINE * get_game_gui_scale()

## Like ui_sf but capped so a modal panel of design size `panel_design` still fits
## within `frac` of the viewport — keeps popups from overflowing at high GUI scale.
func ui_sf_panel(viewport_size: Vector2, panel_design: Vector2, frac: float = 0.98) -> float:
	var s := ui_sf(viewport_size)
	if panel_design.x > 0.0:
		s = minf(s, viewport_size.x * frac / panel_design.x)
	if panel_design.y > 0.0:
		s = minf(s, viewport_size.y * frac / panel_design.y)
	return s

# ============================================================
# PROGRESS HELPERS
# ============================================================

func get_levels_unlocked() -> int:
	return data.get("progress", {}).get("levels_unlocked", 1)

func unlock_level(level_num: int) -> void:
	var current := get_levels_unlocked()
	if level_num > current:
		data["progress"]["levels_unlocked"] = level_num
		save_game()

func save_level_result(level_num: int, time_seconds: float, stars: int) -> void:
	var progress: Dictionary = data.get("progress", {})
	var times: Dictionary = progress.get("level_times", {})
	var star_dict: Dictionary = progress.get("level_stars", {})
	var key := str(level_num)

	# Only save if better time
	var prev_time = times.get(key, INF)
	if time_seconds < prev_time:
		times[key] = time_seconds

	# Only save if more stars
	var prev_stars: int = star_dict.get(key, 0)
	if stars > prev_stars:
		star_dict[key] = stars

	progress["level_times"] = times
	progress["level_stars"] = star_dict
	data["progress"] = progress

	# Unlock next level
	unlock_level(level_num + 1)

	# Update stats
	add_stat("total_levels_completed", 1)
	if level_num > get_stat("highest_level"):
		set_stat("highest_level", level_num)

	save_game()

func get_level_time(level_num: int) -> float:
	return data.get("progress", {}).get("level_times", {}).get(str(level_num), -1.0)

func get_level_stars(level_num: int) -> int:
	return data.get("progress", {}).get("level_stars", {}).get(str(level_num), 0)

func is_challenge_complete(id: String) -> bool:
	return id in data.get("progress", {}).get("challenges_completed", []) or get_challenge_stars(id) >= 1

func mark_challenge_complete(id: String) -> void:
	if id == "":
		return
	var prog: Dictionary = data.get("progress", {})
	var done: Array = prog.get("challenges_completed", [])
	if id not in done:
		done.append(id)
		prog["challenges_completed"] = done
		data["progress"] = prog
		save_game()

func get_challenge_stars(id: String) -> int:
	return int(data.get("progress", {}).get("challenge_stars", {}).get(id, 0))

## Store a challenge's star result (keeps the best). Also marks it completed at >=1 star.
func set_challenge_stars(id: String, stars: int) -> void:
	if id == "" or stars <= 0:
		return
	if stars > get_challenge_stars(id):
		var prog: Dictionary = data.get("progress", {})
		var dict: Dictionary = prog.get("challenge_stars", {})
		dict[id] = mini(stars, 3)
		prog["challenge_stars"] = dict
		data["progress"] = prog
		save_game()
	mark_challenge_complete(id)

## Store a challenge's per-run records: best (lowest) time, most kills, most targets.
## Any arg <= 0 is ignored so each challenge tracks only the metrics that apply to it.
func save_challenge_record(id: String, time_seconds: float = -1.0, kills: int = -1, targets: int = -1) -> void:
	if id == "":
		return
	var prog: Dictionary = data.get("progress", {})
	var recs: Dictionary = prog.get("challenge_records", {})
	var r: Dictionary = recs.get(id, {})
	# All challenge time records are SURVIVAL (survive the longest) → keep the MAX.
	if time_seconds > 0.0 and time_seconds > float(r.get("time", 0.0)):
		r["time"] = time_seconds
	if kills >= 0 and kills > int(r.get("kills", 0)):
		r["kills"] = kills
	if targets >= 0 and targets > int(r.get("targets", 0)):
		r["targets"] = targets
	recs[id] = r
	prog["challenge_records"] = recs
	data["progress"] = prog
	save_game()

## Read a challenge record field ("time" | "kills" | "targets"); 0.0 if none yet.
func get_challenge_record(id: String, field: String) -> float:
	return float(data.get("progress", {}).get("challenge_records", {}).get(id, {}).get(field, 0.0))

func save_endless_time(time_seconds: float) -> void:
	var best: float = data.get("progress", {}).get("endless_best_time", 0.0)
	if time_seconds > best:
		data["progress"]["endless_best_time"] = time_seconds
		save_game()

func get_endless_best() -> float:
	return data.get("progress", {}).get("endless_best_time", 0.0)

# ============================================================
# STATS HELPERS
# ============================================================

func get_stat(key: String) -> float:
	return data.get("stats", {}).get(key, 0.0)

## High-frequency (per kill, twice) — writing JSON to disk each time caused frame hitches
## when many monsters die at once (katana sweep). Mark dirty; flush on a timer / important
## saves / when the app backgrounds.
var _stats_dirty := false
var _flush_accum := 0.0

func set_stat(key: String, value: float) -> void:
	if not data.has("stats"):
		data["stats"] = {}
	data["stats"][key] = value
	_stats_dirty = true

func _process(delta: float) -> void:
	if _stats_dirty:
		_flush_accum += delta
		if _flush_accum >= 2.0:
			_flush_accum = 0.0
			save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT 			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _stats_dirty:
			save_game()

func add_stat(key: String, amount: float) -> void:
	var current := get_stat(key)
	set_stat(key, current + amount)

# ============================================================
# COSMETICS HELPERS
# ============================================================

func get_owned_skins() -> Array:
	return data.get("cosmetics", {}).get("owned_skins", ["default"])

func get_equipped_skin() -> String:
	return data.get("cosmetics", {}).get("equipped_skin", "default")

## Own a skin. Returns true only if it was newly added (false if already owned).
func own_skin(skin_id: String) -> bool:
	var skins: Array = get_owned_skins()
	if skin_id in skins:
		return false
	skins.append(skin_id)
	data["cosmetics"]["owned_skins"] = skins
	save_game()
	return true

## "default" is always owned; everything else must be unlocked from the lucky box.
func is_skin_owned(skin_id: String) -> bool:
	return skin_id == "default" or skin_id in get_owned_skins()

func equip_skin(skin_id: String) -> void:
	data["cosmetics"]["equipped_skin"] = skin_id
	save_game()

func get_equipped_trail() -> String:
	return data.get("cosmetics", {}).get("equipped_trail", "none")

func get_owned_trails() -> Array:
	return data.get("cosmetics", {}).get("owned_trails", ["none"])

func own_trail(trail_id: String) -> bool:
	var trails: Array = get_owned_trails()
	if trail_id in trails:
		return false
	trails.append(trail_id)
	data["cosmetics"]["owned_trails"] = trails
	save_game()
	return true

## "none" is always owned; everything else must be unlocked from the lucky box.
func is_trail_owned(trail_id: String) -> bool:
	return trail_id == "none" or trail_id in get_owned_trails()

func equip_trail(trail_id: String) -> void:
	if not data.has("cosmetics"):
		data["cosmetics"] = {}
	data["cosmetics"]["equipped_trail"] = trail_id
	save_game()

# ============================================================
# DAILY LUCKY BOX (24h free cooldown, wall-clock based so it counts offline)
# ============================================================

const BOX_COOLDOWN_SEC := 3600  ## 1 hour

func seconds_until_free_box() -> int:
	var last: int = int(data.get("cosmetics", {}).get("last_box_open", 0))
	if last <= 0:
		return 0
	var elapsed := int(Time.get_unix_time_from_system()) - last
	return maxi(0, BOX_COOLDOWN_SEC - elapsed)

func can_open_box_free() -> bool:
	return seconds_until_free_box() <= 0

## Reset the 24h cooldown (call whenever a box is opened, free OR via ad).
func mark_box_opened() -> void:
	if not data.has("cosmetics"):
		data["cosmetics"] = {}
	data["cosmetics"]["last_box_open"] = int(Time.get_unix_time_from_system())
	save_game()

# ============================================================
# ACHIEVEMENTS
# ============================================================

func get_unlocked_achievements() -> Array:
	return data.get("achievements", [])

func is_achievement_unlocked(id: String) -> bool:
	return id in get_unlocked_achievements()

## Mark an achievement unlocked. Returns true only the first time (so callers can
## trigger the toast once). No-op + false if already unlocked.
func unlock_achievement(id: String) -> bool:
	var unlocked: Array = get_unlocked_achievements()
	if id in unlocked:
		return false
	unlocked.append(id)
	data["achievements"] = unlocked
	save_game()
	return true

## SPEEDRUN reset: wipe EVERY bit of progress (levels, challenges, stats, achievements,
## cosmetics, tutorial flag) back to a fresh install. Device SETTINGS and the GDPR flag
## survive — they're preferences, not progress. Writes through the atomic save (the old
## save becomes the .bak, so one manual rescue is possible).
## SPEEDRUN reset. Wipes only the RUN progress — level unlocks/times/stars, challenge stars
## and completion — so the star-gated achievements can be re-earned. KEPT: all-time records
## the player still wants to see (challenge best times/scores, endless best), the GLOBAL
## stats (kills, deaths, playtime…), cosmetics (owned skins/trails), device settings, and the
## cosmetic/playtime achievements (they don't count toward 100 %). Selective — not a full wipe.
func reset_all_progress() -> void:
	var prog: Dictionary = data.get("progress", {})
	prog["levels_unlocked"] = 1
	prog["level_times"] = {}
	prog["level_stars"] = {}
	prog["challenge_stars"] = {}
	prog["challenges_completed"] = []
	# KEPT: prog["endless_best_time"] + prog["challenge_records"] (the records stay, just no
	# longer tied to any earned stars this run).
	data["progress"] = prog
	# Achievements: keep only the cosmetic/playtime ones.
	var AchData := load("res://scripts/data/achievement_data.gd")
	var kept_ach: Array = []
	for id in data.get("achievements", []):
		if id in AchData.NON_COMPLETION_IDS:
			kept_ach.append(id)
	data["achievements"] = kept_ach
	# GLOBAL stats, cosmetics, settings and gdpr are left untouched.
	save_game()
