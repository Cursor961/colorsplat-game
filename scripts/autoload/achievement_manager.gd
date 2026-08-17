extends Node
## AchievementManager (Autoload) — unlocks achievements and shows Steam-style
## toasts in the bottom-right corner. Toasts render globally via an owned
## CanvasLayer, so they work in gameplay AND menus. Unlock state persists via
## SaveManager (deduped — a toast only shows the first time).
##
## Gameplay calls AchievementManager.unlock("id"). Condition checking lives in the
## gameplay code (e.g. game_world); this manager just dedupes, persists, toasts.

const Ach := preload("res://scripts/data/achievement_data.gd")
const TrailMeta := preload("res://scripts/data/trail_data.gd")
const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

## The exclusive skin granted by completing every achievement (the "100%" reward).
const META_SKIN_100 := "Player_100"
## The exclusive skin granted by the flawless no-death level marathon.
const NODEATH_SKIN := "Player_skeleton"
## Number of BUILT levels used by the level achievements (30 = incl. the final boss).
const LEVELS_TOTAL := 30

signal achievement_unlocked(id: String)

const TOAST_LAYER := 90
const HOLD_TIME := 4.0

var _font: Font
var _layer: CanvasLayer
var _queue: Array[String] = []
var _showing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = UIT.load_font()
	_layer = CanvasLayer.new()
	_layer.layer = TOAST_LAYER
	add_child(_layer)

## Unlock an achievement. Shows a toast only the first time it's unlocked.
func unlock(id: String) -> void:
	if Ach.get_info(id).is_empty():
		push_warning("AchievementManager: unknown achievement '%s'" % id)
		return
	if SaveManager.unlock_achievement(id):
		achievement_unlocked.emit(id)
		_queue.append(id)
		if not _showing:
			_show_next()
		# The flawless marathon grants the exclusive Skeleton skin.
		if id == "levels_inrowwithnodeath":
			SaveManager.own_skin(NODEATH_SKIN)
			check_collection_achievements()
		# Completing any achievement may complete the "100%" meta achievement.
		# (Skip when we ourselves just unlocked it, to avoid re-entry.)
		if id != "game_unlockallachievements":
			_check_all_achievements()

## Unlocks "Full Wardrobe" once every skin (except the 100% reward) and every trail
## is owned. Call after granting cosmetics (daily box) and on menu load.
func check_collection_achievements() -> void:
	if SaveManager.is_achievement_unlocked("game_unlockallskins"):
		return
	for sid in SpriteLoader.get_available_skins():
		var s := String(sid)
		if s == META_SKIN_100:
			continue  # the 100% skin is the reward, not part of the collection goal
		if not SaveManager.is_skin_owned(s):
			return
	for t: Dictionary in TrailMeta.TRAILS:
		var tid := String(t.get("id", ""))
		if tid == "" or tid == "none":
			continue
		if not SaveManager.is_trail_owned(tid):
			return
	unlock("game_unlockallskins")

## Unlocks "Challenger" (5 challenges) and "Challenge Master" (all challenges).
## Call after a challenge is marked complete.
func check_challenge_achievements() -> void:
	var done: Array = SaveManager.data.get("progress", {}).get("challenges_completed", [])
	if done.size() >= 5:
		unlock("game_complete5challenges")
	var all_done := true
	var all_3stars := true
	for ch: Dictionary in Ach.ChallengeReg.CHALLENGES:
		var cid := String(ch.get("id", ""))
		if cid not in done and SaveManager.get_challenge_stars(cid) < 1:
			all_done = false
		if SaveManager.get_challenge_stars(cid) < 3:
			all_3stars = false
	if Ach.ChallengeReg.CHALLENGES.size() > 0:
		if all_done:
			unlock("game_completeallchallenges")
		if all_3stars:
			unlock("game_completeallchallengesON3STARS")

## Unlocks "Level Conqueror" (all levels done) + "Three-Star General" (all on 3 stars).
## Call after a numbered level is completed. (The no-death marathon is tracked in game_world.)
func check_level_achievements() -> void:
	var all_done := true
	var all_3stars := true
	for n in range(1, LEVELS_TOTAL + 1):
		var stars := SaveManager.get_level_stars(n)
		if stars < 1:
			all_done = false
		if stars < 3:
			all_3stars = false
	if all_done:
		unlock("levels_completeall")
	if all_3stars:
		unlock("levels_completeallon3stars")

## Unlocks "100% Complete" once every OTHER achievement is unlocked, granting the
## exclusive 100% skin as a bonus.
func _check_all_achievements() -> void:
	if SaveManager.is_achievement_unlocked("game_unlockallachievements"):
		return
	for a: Dictionary in Ach.ACHIEVEMENTS:
		var aid := String(a.get("id", ""))
		# The meta one itself + the cosmetic/playtime ones don't gate 100 % completion.
		if aid == "game_unlockallachievements" or aid in Ach.NON_COMPLETION_IDS:
			continue
		if not SaveManager.is_achievement_unlocked(aid):
			return
	# All other achievements done → grant the bonus skin, then unlock the meta one.
	SaveManager.own_skin(META_SKIN_100)
	unlock("game_unlockallachievements")

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var id: String = _queue.pop_front()
	_build_and_play_toast(id)

func _s(v: float, sf: float) -> int:
	return maxi(1, int(v * sf))

func _build_and_play_toast(id: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	var sf := SaveManager.ui_sf(vp)

	var color: Color = Ach.get_color(id)
	var panel_w := 500.0 * sf
	var panel_h := 108.0 * sf
	var margin := 26.0 * sf

	var panel := Panel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.size = Vector2(panel_w, panel_h)
	# Start off-screen to the right, anchored near the bottom.
	var final_x := vp.x - panel_w - margin
	var start_x := vp.x + 20.0
	var y := vp.y - panel_h - margin
	panel.position = Vector2(start_x, y)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.11, 0.97).lerp(color, 0.12)  # slight color tint
	sb.border_color = color
	sb.set_border_width_all(maxi(2, int(3 * sf)))
	sb.set_corner_radius_all(int(16 * sf))
	sb.content_margin_left = 16 * sf
	sb.content_margin_right = 18 * sf
	sb.content_margin_top = 12 * sf
	sb.content_margin_bottom = 12 * sf
	panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(panel)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16 * sf
	row.offset_top = 12 * sf
	row.offset_right = -18 * sf
	row.offset_bottom = -12 * sf
	row.add_theme_constant_override("separation", int(16 * sf))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	# Icon
	var icon := TextureRect.new()
	var icon_sz := 92.0 * sf
	icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ipath := Ach.get_icon_path(id)
	if ResourceLoader.exists(ipath):
		icon.texture = load(ipath)
	row.add_child(icon)

	# Text column
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", int(2 * sf))
	row.add_child(col)

	var hdr := Label.new()
	hdr.text = Loc.t("ach_unlocked")
	_style(hdr, 22, sf, color.lightened(0.25), 3)
	col.add_child(hdr)

	var name_lbl := Label.new()
	name_lbl.text = Ach.display_name(id)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(name_lbl, 34, sf, Color.WHITE, 4)
	col.add_child(name_lbl)

	AudioManager.play_sfx("achievement_complete")

	# Slide in → hold → slide out → next
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:x", final_x, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(panel, "position:x", start_x, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void:
		panel.queue_free()
		_show_next())

func _style(lbl: Label, px: float, sf: float, col: Color, outline: int) -> void:
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", _s(px, sf))
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", _s(outline, sf))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
