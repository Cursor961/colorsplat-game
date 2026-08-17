extends Node
## AudioManager - Sound effects and dynamic music (Autoload)
## Converted from Sound_Engine.as + Song.as

# ---- VOLUME ----
var global_volume: float = 0.65   ## Master volume (from original)
var _music_volume: float = 1.0
var _effect_volume: float = 1.0
var is_muted: bool = false
const PAN_MULT := 1.0

# ---- SFX PLAYERS ----
## Fixed pool of reusable voices. play_sfx() used to create + free an AudioStreamPlayer per
## call, which during an octoshoot burst meant dozens of node allocations per second on a
## phone. Voices are now recycled round-robin; when all are busy the oldest one is stolen.
const SFX_POOL_SIZE := 24
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0        ## round-robin cursor (also the voice-stealing victim)
var _sfx_pitch: float = 1.0  ## Global SFX pitch scale (slowpill sets to 0.3)

# ---- MUSIC ----
var _music_player: AudioStreamPlayer
## Playlists. Menu: random start, then plays the next track in order when one ends.
## Game: random start, then a random track that isn't the one that just finished.
const MENU_TRACKS: Array[String] = [
	"res://assets/audio/music/menu_1.mp3",
	"res://assets/audio/music/menu_2.mp3",
]
const GAME_TRACKS: Array[String] = [
	"res://assets/audio/music/game_1.mp3",
	"res://assets/audio/music/game_2.mp3",
	"res://assets/audio/music/game_3.mp3",
	"res://assets/audio/music/game_4.mp3",
	"res://assets/audio/music/game_5.mp3",
	"res://assets/audio/music/game_6.mp3",
	"res://assets/audio/music/game_7.mp3",
]
const MUSIC_DUCK_DEATH := 0.22   ## music drops to this fraction while the player dies
var _music_mode: String = ""     ## "menu" | "game" | ""
var _music_track_idx: int = -1
var _music_duck: float = 1.0     ## 1.0 normal; lowered (not stopped) on player death

# ---- DYNAMIC MUSIC STATE ----
var drums_intensity: float = 0.0   ## 0-1, driven by monster count (count/60)
var melody_intensity: float = 0.0  ## 0-1, driven by powerup state

func _ready() -> void:
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"  ## "Music" bus does not exist yet; use Master until bus layout is set up
	# Keep music playing while the tree is paused (pause menu / game-over screen) so it
	# can be ducked-but-audible instead of going silent. SFX players stay pausable.
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	# Pre-create the reusable SFX voices (see SFX_POOL_SIZE).
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)
	# Sync saved volumes on launch (SaveManager autoloads before AudioManager).
	_music_volume = float(SaveManager.get_setting("music_volume", 80)) / 100.0
	_effect_volume = float(SaveManager.get_setting("sfx_volume", 50)) / 100.0

var music_volume: float:
	get: return 0.0 if is_muted else _music_volume * global_volume
	set(v): _music_volume = v

var effect_volume: float:
	get: return 0.0 if is_muted else _effect_volume * global_volume
	set(v): _effect_volume = v

# NOTE: drums_intensity / melody_intensity are reserved for future dynamic-music
# layering. They were previously recomputed every physics frame (two group queries)
# but nothing reads them, so that per-frame work was removed. Set them from gameplay
# code if/when music layering is wired up.

# ============================================================
# SFX
# ============================================================

## Play a sound effect. pan: -1.0 (left) to 1.0 (right) — reserved for future bus effect.
## fixed_pitch: when true the player ignores the global slow-motion SFX pitch and is
## exempt from later set_sfx_pitch() changes — used for cues that must sound normal
## even while slow-motion (slowpill) is active (e.g. the time-stop "whoosh").
func play_sfx(sfx_name: String, volume_mult: float = 1.0, _pan: float = 0.0, fixed_pitch: bool = false) -> void:
	if is_muted:
		return

	var path := "res://assets/audio/sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/%s.ogg" % sfx_name
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/%s.mp3" % sfx_name
	if not ResourceLoader.exists(path):
		return  # missing SFX file → silently skip (e.g. there is no button_click.wav)

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: failed to load sfx '%s'" % sfx_name)
		return

	var player := _acquire_sfx_voice()
	if player == null:
		return
	player.stop()
	player.stream = stream
	player.volume_db = linear_to_db(effect_volume * volume_mult)
	if fixed_pitch:
		player.pitch_scale = 1.0
		player.set_meta("fixed_pitch", true)   # set_sfx_pitch() will skip this player
	else:
		if player.has_meta("fixed_pitch"):
			player.remove_meta("fixed_pitch")  # voice is recycled — clear a previous flag
		player.pitch_scale = _sfx_pitch
	player.play()

## First idle voice from the round-robin cursor; if every voice is busy, steal the one the
## cursor points at (the least-recently started) so a burst can never allocate new nodes.
func _acquire_sfx_voice() -> AudioStreamPlayer:
	var n := _sfx_pool.size()
	if n == 0:
		return null
	for i in n:
		var idx := (_sfx_next + i) % n
		if not _sfx_pool[idx].playing:
			_sfx_next = (idx + 1) % n
			return _sfx_pool[idx]
	var victim := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % n
	return victim

## Play a random variant of a sound effect.
## Looks for files named {sfx_name}_1.wav, {sfx_name}_2.wav, ... up to count.
func play_sfx_random(sfx_name: String, count: int, volume_mult: float = 1.0, _pan: float = 0.0) -> void:
	var idx := randi_range(1, count)
	play_sfx("%s_%d" % [sfx_name, idx], volume_mult, _pan)

## Play a random variant with positional pan based on x position.
func play_sfx_random_at(sfx_name: String, count: int, x_pos: float, volume_mult: float = 1.0) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var center := viewport_width / 2.0
	var pan := clampf((x_pos - center) / center * PAN_MULT, -1.0, 1.0)
	play_sfx_random(sfx_name, count, volume_mult, pan)

## Play sound with positional pan based on x position.
func play_sfx_at(sfx_name: String, x_pos: float, volume_mult: float = 1.0) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var center := viewport_width / 2.0
	var pan := clampf((x_pos - center) / center * PAN_MULT, -1.0, 1.0)
	play_sfx(sfx_name, volume_mult, pan)

# ============================================================
# MUSIC
# ============================================================

## Start the menu playlist: random track, un-ducked. Call on every entry to the
## menu (app launch + return from a run) so the pick is fresh each time. Menu music
## lives on this autoload, so it keeps playing across submenu popups.
func play_menu_music() -> void:
	_music_duck = 1.0
	_music_player.pitch_scale = 1.0     # clear any slowpill slow-down
	_music_player.stream_paused = false # clear any stoppill freeze
	if MENU_TRACKS.is_empty():
		return
	_music_mode = "menu"
	_play_track(randi() % MENU_TRACKS.size())

## Start the gameplay playlist: random track, un-ducked.
func play_game_music() -> void:
	_music_duck = 1.0
	_music_player.pitch_scale = 1.0     # clear any slowpill slow-down
	_music_player.stream_paused = false # clear any stoppill freeze
	if GAME_TRACKS.is_empty():
		return
	_music_mode = "game"
	_play_track(randi() % GAME_TRACKS.size())

func _current_tracklist() -> Array:
	return MENU_TRACKS if _music_mode == "menu" else GAME_TRACKS

func _play_track(idx: int) -> void:
	var list := _current_tracklist()
	if idx < 0 or idx >= list.size():
		return
	_music_track_idx = idx
	var path: String = list[idx]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: music not found '%s'" % path)
		return
	var stream := load(path) as AudioStream
	# Disable internal looping so `finished` fires and the playlist can advance.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_music_player.stream = stream
	_update_music_volume()
	_music_player.play()

## When a track ends: menu cycles to the next; game picks a random different track.
func _on_music_finished() -> void:
	var list := _current_tracklist()
	if list.is_empty() or _music_mode == "":
		return
	if _music_mode == "menu":
		_play_track((_music_track_idx + 1) % list.size())
	else:
		_play_track(_pick_other(list.size(), _music_track_idx))

## Skip to another track right now — same selection rule as when one ends
## (game = a random track that isn't the current one; menu = the next in order).
func skip_track() -> void:
	if _music_mode == "":
		return
	_on_music_finished()

## Random index in [0,count) that isn't `exclude`.
func _pick_other(count: int, exclude: int) -> int:
	if count <= 1:
		return 0
	var idx := randi() % count
	while idx == exclude:
		idx = randi() % count
	return idx

## Lower music volume (player death, game-over screen, pause) without stopping it.
func duck_music(factor: float = MUSIC_DUCK_DEATH) -> void:
	_music_duck = clampf(factor, 0.0, 1.0)
	_update_music_volume()

## Restore music to full volume after a duck (e.g. resuming from pause).
func restore_music() -> void:
	_music_duck = 1.0
	_update_music_volume()

## Slow the music playback (Slowpill). 1.0 = normal speed; lower = slower + lower pitch.
func set_music_pitch(pitch: float) -> void:
	if _music_player:
		_music_player.pitch_scale = maxf(pitch, 0.05)

## Freeze / resume the music in place (Stoppill time stop).
func set_music_paused(paused: bool) -> void:
	if _music_player:
		_music_player.stream_paused = paused

func stop_music() -> void:
	_music_player.stop()
	_music_mode = ""

func toggle_mute() -> void:
	is_muted = not is_muted
	_update_music_volume()

## Apply the current music volume (setting × master × duck) to the player.
func _update_music_volume() -> void:
	_music_player.volume_db = linear_to_db(maxf(music_volume * _music_duck, 0.0001))

## Update volumes from settings.
func apply_settings(music_vol: float, sfx_vol: float) -> void:
	_music_volume = music_vol / 100.0
	_effect_volume = sfx_vol / 100.0
	_update_music_volume()

## Set global SFX pitch scale (affects all new SFX + currently playing ones).
func set_sfx_pitch(pitch: float) -> void:
	_sfx_pitch = pitch
	# Update all currently playing SFX players (except fixed-pitch cues)
	for child in get_children():
		if child is AudioStreamPlayer and child != _music_player and not child.has_meta("fixed_pitch"):
			child.pitch_scale = pitch
