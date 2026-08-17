extends Node
## AdManager (autoload) — one place the whole game asks for a rewarded ad.
##
## Call `AdManager.show_rewarded(AdManager.REWARDED_SPIN, func(success): ...)`.
## The callback fires with `true` when the reward is granted (player watched the ad, or
## we're on a build with no ad plugin so we grant it) and `false` when they dismissed
## early / the ad failed to load or show.
##
## FALLBACK: on desktop, in the editor, or on any build where the native AdMob plugin
## isn't present, `_available` is false and every request instantly succeeds — so the
## game is fully playable without ads. On Android with the Poing Studios plugin checked
## in the export preset, real rewarded ads run (loaded on demand per unit).
##
## ── SETUP CHECKLIST ──────────────────────────────────────────────────────────
## • The ad-unit IDs below are PLACEHOLDERS in this public repository. The real units
##   live in the AdMob console of the published build and are deliberately not committed
##   (a public live unit ID invites invalid traffic, which gets AdMob accounts banned).
##   Drop your own unit IDs in here to wire the game up to your own AdMob app.
## • The APP ID is NOT used here — it goes into the plugin's export/AndroidManifest
##   config (Project → Export → Android).
## • Keep USE_TEST_ADS = true while developing (serves Google dummy ads, safe to click).
##   Flip to false ONLY for the store build. Never click your own LIVE ads → account ban.

signal availability_changed(available: bool)

# ── Ad-unit IDs — replace with your own from the AdMob console ────────────────
const REWARDED_SPIN := "ca-app-pub-0000000000000000/0000000001"     ## daily box "open (ad)"
const REWARDED_SKIP := "ca-app-pub-0000000000000000/0000000002"     ## skip a level after 5 deaths
const REWARDED_SUPPORT := "ca-app-pub-0000000000000000/0000000003"  ## "support the author" (all owned)
const BANNER_PAUSE := "ca-app-pub-0000000000000000/0000000004"      ## MREC in the pause menu (see pause_menu.gd)

# Google's official TEST rewarded unit — always safe to click, serves a dummy ad.
const REWARDED_TEST := "ca-app-pub-3940256099942544/5224354917"

# TRUE serves Google test ads for EVERY unit. Flip to false for the production build.
const USE_TEST_ADS := true

## Devices listed here ALWAYS get test ads, even with USE_TEST_ADS = false. This is the safe
## way to verify the REAL ad units before release: the build ships live unit IDs (so you're
## testing the actual integration), but your own phone still sees dummy ads — clicking your own
## LIVE ads is invalid traffic and gets AdMob accounts banned.
##
## To get your ID: install the build, launch it, and in `adb logcat` look for a line like
##   "Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("33BE2250B43518CCDA7DE426D04EE231"))"
## Paste that hash below.
const TEST_DEVICE_IDS: Array[String] = []

# The native singleton the Poing plugin registers on Android; absent everywhere else.
const NATIVE_SINGLETON := "PoingGodotAdMobRewardedAd"

## Public privacy-policy page — linked from the main menu (Google Play requires a reachable
## policy for any app that serves ads) and used as the fallback for the privacy link.
const PRIVACY_POLICY_URL := "https://cursor961.github.io/colorsplat-privacy/"

const OVERLAY_SCRIPT := "res://scripts/ui/ad_loading_overlay.gd"
## A tiny no-content endpoint (HTTP 204) used purely to tell "online" from "offline".
const CONNECTIVITY_URL := "https://connectivitycheck.gstatic.com/generate_204"

var _available := false            ## true only when the native plugin is really loaded
var _result_cb: Callable = Callable()  ## the caller waiting for the current show's result
var _earned := false               ## reward earned during the current show
var _current_ad = null             ## the RewardedAd currently loading/showing
var _was_paused := false           ## tree-pause state to restore once the ad closes
var _overlay: CanvasLayer = null   ## the black "loading ad" cover (fades in/out per show)
var _http: HTTPRequest = null      ## reused connectivity probe
var _pending_unit := ""            ## ad unit awaiting the connectivity check

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # ads pause the tree; the manager must keep running
	_available = Engine.has_singleton(NATIVE_SINGLETON)
	if not _available:
		return   # desktop / no plugin → show_rewarded() just grants instantly
	# GDPR: resolve consent BEFORE initialising the ads SDK (Google's required order in the
	# EEA/UK). _finish_consent() does the actual MobileAds.initialize once we have an answer.
	_request_consent(false)

# ============================================================
# GDPR / UMP CONSENT (EEA + UK)
# ============================================================
## Google requires a consent flow before serving ads to European users, and requires the choice
## to stay changeable afterwards (main menu → "Privacy settings" → show_consent_form()).
## Uses the Poing plugin's UMP (User Messaging Platform) wrapper.

signal consent_resolved

var _ads_initialised := false
var _force_form := false        ## true when the player re-opened the form from the menu

## Ask UMP for the current consent state. `force` = the player asked to change it, so wipe the
## stored answer and always present the form.
func _request_consent(force: bool) -> void:
	if not _available:
		return
	_force_form = force
	var ci = UserMessagingPlatform.consent_information
	if force:
		ci.reset()
	ci.update(ConsentRequestParameters.new(), _on_consent_updated, _on_consent_update_failed)

func _on_consent_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_form_failed)
	else:
		_finish_consent()   # outside the EEA/UK → no form needed

func _on_consent_update_failed(_error) -> void:
	_finish_consent()       # couldn't reach the consent service → carry on (non-personalised)

func _on_consent_form_loaded(form) -> void:
	var ci = UserMessagingPlatform.consent_information
	# Show it when consent is REQUIRED, or whenever the player asked to change their choice.
	if _force_form or ci.get_consent_status() == ci.ConsentStatus.REQUIRED:
		form.show(_on_consent_form_dismissed)
	else:
		_finish_consent()

func _on_consent_form_failed(_error) -> void:
	_finish_consent()

func _on_consent_form_dismissed(_error) -> void:
	_finish_consent()

## Consent answered (or not needed) → remember it and bring the ads SDK up exactly once.
func _finish_consent() -> void:
	_force_form = false
	var ci = UserMessagingPlatform.consent_information
	var st = ci.get_consent_status()
	SaveManager.set_setting("gdpr_consent",
		st == ci.ConsentStatus.OBTAINED or st == ci.ConsentStatus.NOT_REQUIRED)
	consent_resolved.emit()
	if _ads_initialised:
		return
	_ads_initialised = true
	# Register test devices (if any) BEFORE init, so they get dummy ads even on a live build.
	if not TEST_DEVICE_IDS.is_empty():
		var rc := RequestConfiguration.new()
		rc.test_device_ids = TEST_DEVICE_IDS
		MobileAds.set_request_configuration(rc)
	var init_listener := OnInitializationCompleteListener.new()
	MobileAds.initialize(init_listener)
	availability_changed.emit(true)

## Re-open the consent form (main menu → Privacy settings). On builds without the ads plugin
## there's nothing to consent to, so fall back to opening the privacy policy instead.
func show_consent_form() -> void:
	if _available:
		_request_consent(true)
	else:
		OS.shell_open(PRIVACY_POLICY_URL)

## Effective unit id: swap in Google's test unit while USE_TEST_ADS is on.
func _unit(unit_id: String) -> String:
	return REWARDED_TEST if USE_TEST_ADS else unit_id

## Is the ad system live (real ads)? UI can use this to decide whether to even show an
## ad button. On fallback builds it's false — but show_rewarded() still grants instantly.
func is_available() -> bool:
	return _available

## Request a rewarded ad for `unit_id`. `on_result` is called with a bool: true = grant.
## Loads on demand (a brief delay before the ad appears is normal for these rare spots).
func show_rewarded(unit_id: String, on_result: Callable) -> void:
	# A show is already in progress → refuse (caller keeps its state).
	if _result_cb.is_valid():
		on_result.call(false)
		return
	_result_cb = on_result
	_earned = false
	_pending_unit = unit_id
	# Fade the game to a black "Spouští se reklama" cover with a spinner the moment the ad is
	# requested — it bridges the load delay and then the native ad appears on top of it.
	_show_overlay()
	# A rewarded reward ALWAYS requires internet, so gate every path on a connectivity check
	# FIRST. Offline → show the "no internet" message and grant nothing (on real builds this
	# also avoids a long spinner that would just fail to load anyway).
	_probe_online(_on_online_checked)

## Connectivity result for the pending show. Offline → deny with a message. Online → grant
## (fallback build) or load + show the real rewarded ad.
func _on_online_checked(online: bool) -> void:
	if not online:
		if _overlay and is_instance_valid(_overlay):
			_overlay.show_offline()
		await get_tree().create_timer(1.4).timeout
		_finish(false)
		return
	# Fallback build (no ad plugin — desktop/editor): no real ad, so online = grant.
	if not _available:
		_finish(true)
		return
	# FREEZE the game while the real ad loads + covers the screen (e.g. the level-skip button
	# mid-run). Restored to the previous state in _finish().
	_was_paused = get_tree().paused
	get_tree().paused = true
	var load_cb := RewardedAdLoadCallback.new()
	load_cb.on_ad_loaded = func(ad) -> void:
		_current_ad = ad
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
			_finish(_earned)
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
			_finish(false)
		var reward_listener := OnUserEarnedRewardListener.new()
		reward_listener.on_user_earned_reward = func(_item) -> void:
			_earned = true
		ad.show(reward_listener)
	load_cb.on_ad_failed_to_load = func(_err) -> void:
		_finish(false)
	RewardedAdLoader.new().load(_unit(_pending_unit), AdRequest.new(), load_cb)

## Deliver the result of the current show: unfreeze, drop the ad, then fade the black cover
## out and hand the result back (so the reward UI appears as the screen clears).
func _finish(success: bool) -> void:
	get_tree().paused = _was_paused   # unfreeze (or stay paused if the caller was, e.g. game over)
	if _current_ad != null:
		_current_ad.destroy()
		_current_ad = null
	var cb := _result_cb
	_result_cb = Callable()
	_dismiss_overlay(func() -> void:
		if cb.is_valid():
			cb.call(success))

# ── Loading overlay ───────────────────────────────────────────────────────────
func _show_overlay() -> void:
	_dismiss_overlay_now()
	_overlay = load(OVERLAY_SCRIPT).new()
	add_child(_overlay)
	_overlay.begin()

func _dismiss_overlay(after: Callable) -> void:
	if _overlay and is_instance_valid(_overlay):
		var ov: CanvasLayer = _overlay
		_overlay = null
		ov.finish(after)
	elif after.is_valid():
		after.call()

func _dismiss_overlay_now() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

# ── Connectivity probe (fallback builds) ──────────────────────────────────────
## Ping a no-content endpoint; call `cb` with true if the request completes, false on any
## network failure/timeout. Used only when there's no ad plugin to enforce the requirement.
func _probe_online(cb: Callable) -> void:
	if _http == null or not is_instance_valid(_http):
		_http = HTTPRequest.new()
		_http.timeout = 5.0
		add_child(_http)
	_http.request_completed.connect(
		func(result: int, _code: int, _headers, _body) -> void:
			cb.call(result == HTTPRequest.RESULT_SUCCESS),
		CONNECT_ONE_SHOT)
	var err := _http.request(CONNECTIVITY_URL, [], HTTPClient.METHOD_GET)
	if err != OK:
		# Couldn't even start the request → treat as offline. Drop the pending one-shot.
		for c in _http.request_completed.get_connections():
			_http.request_completed.disconnect(c["callable"])
		cb.call(false)
