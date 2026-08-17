class_name AdLoadingOverlay
extends CanvasLayer
## Full-screen BLACK cover shown while a rewarded ad loads: "Spouští se reklama" + a spinner.
## AdManager fades it IN the moment a rewarded ad is requested (bridging the load delay before
## the native ad covers the screen) and fades it OUT once the ad closes / fails. It runs with
## PROCESS_MODE_ALWAYS so the fade + spinner keep animating while the tree is paused (rewarded
## ads pause the game).

const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

var _root: Control
var _label: Label
var _spinner: TextureRect
var _spin_speed: float = 4.2     ## rad/s

func _ready() -> void:
	layer = 200                  # above every in-game layer (FadeOverlay is 100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sf: float = minf(vp.x / 1920.0, vp.y / 1080.0)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # swallow taps under the cover
	_root.modulate = Color(1, 1, 1, 0.0)               # start transparent → fade in
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	_label = Label.new()
	_label.text = Loc.t("ad_loading")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(vp.x, 80.0 * sf)
	_label.position = Vector2(0.0, vp.y * 0.40)
	var f := UIT.load_font()
	if f:
		_label.add_theme_font_override("font", f)
	_label.add_theme_font_size_override("font_size", int(52 * sf))
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)

	var ss: float = 120.0 * sf
	_spinner = TextureRect.new()
	_spinner.texture = _make_spinner_tex(96)
	_spinner.size = Vector2(ss, ss)
	_spinner.pivot_offset = Vector2(ss * 0.5, ss * 0.5)
	_spinner.position = Vector2(vp.x * 0.5 - ss * 0.5, vp.y * 0.54)
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_spinner)

func _process(delta: float) -> void:
	if _spinner and _spinner.visible:
		_spinner.rotation += _spin_speed * delta

## Fade the black cover IN — call the instant the ad is requested.
func begin() -> void:
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.28)

## Swap to the "no internet" message and drop the spinner (no reward is coming).
func show_offline() -> void:
	if _label:
		_label.text = Loc.t("ad_offline")
	if _spinner:
		_spinner.visible = false

## Fade the cover OUT, then run `after` and free.
func finish(after: Callable) -> void:
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		if after.is_valid():
			after.call()
		queue_free())

## Procedural spinner: a ring whose alpha ramps around the circle (a comet tail) — reads as a
## spinning loader once rotated. Built once into an ImageTexture.
func _make_spinner_tex(sz: int) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c: float = sz * 0.5
	var outer: float = sz * 0.5 - 1.0
	var inner: float = sz * 0.34
	for y in sz:
		for x in sz:
			var d := Vector2(float(x) - c, float(y) - c)
			var r := d.length()
			if r <= outer and r >= inner:
				var a: float = fposmod(atan2(d.y, d.x) + PI, TAU) / TAU   # 0..1 around the ring
				img.set_pixel(x, y, Color(1, 1, 1, a))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)
