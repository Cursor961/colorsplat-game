class_name PopupAnim
## Shared open/close animation for modal popups — the "skins popup" feel:
## the dim overlay fades, and the panel pops in with a scale + fade (and pops out
## on close). Keeps every popup visually consistent from one place.
##
## Usage (reference via a local preload alias to avoid global-class coupling):
##   const Anim := preload("res://scripts/utils/popup_anim.gd")
##   func show_popup() -> void:
##       visible = true
##       Anim.open(_overlay, _panel, OVERLAY_ALPHA)
##   func _on_close() -> void:
##       Anim.close(_overlay, _panel, func() -> void:
##           visible = false
##           closed.emit())
##
## `overlay` is the full-rect dim ColorRect; `panel` is the centered content node
## that should scale/fade (a Panel, PanelContainer, or VBoxContainer).

const OPEN_OVERLAY_T := 0.25
const OPEN_PANEL_T := 0.35
const OPEN_FADE_T := 0.20
const CLOSE_OVERLAY_T := 0.20
const CLOSE_PANEL_T := 0.20
const CLOSE_FADE_T := 0.15

## Animate a popup in. Overlay fades to `overlay_alpha`; panel scales 0.5 -> 1 with
## a back-ease overshoot and fades in. Re-arms the overlay for outside-tap close.
static func open(overlay: ColorRect, panel: Control, overlay_alpha: float = 0.75) -> Tween:
	if overlay:
		var c := overlay.color
		overlay.color = Color(c.r, c.g, c.b, 0.0)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if panel:
		panel.pivot_offset = _pivot(panel)
		panel.scale = Vector2(0.5, 0.5)
		panel.modulate.a = 0.0
	var tw := (panel if panel else overlay).create_tween()
	tw.set_parallel(true)
	if overlay:
		tw.tween_property(overlay, "color:a", overlay_alpha, OPEN_OVERLAY_T).set_ease(Tween.EASE_OUT)
	if panel:
		tw.tween_property(panel, "scale", Vector2.ONE, OPEN_PANEL_T).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(panel, "modulate:a", 1.0, OPEN_FADE_T).set_ease(Tween.EASE_OUT)
	return tw

## Animate a popup out, then run `on_done` (typically hides the popup / emits).
## Disables overlay input during the animation so it can't be re-triggered.
static func close(overlay: ColorRect, panel: Control, on_done: Callable) -> Tween:
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel:
		panel.pivot_offset = _pivot(panel)
	var tw := (panel if panel else overlay).create_tween()
	tw.set_parallel(true)
	if overlay:
		tw.tween_property(overlay, "color:a", 0.0, CLOSE_OVERLAY_T).set_ease(Tween.EASE_IN)
	if panel:
		tw.tween_property(panel, "scale", Vector2(0.7, 0.7), CLOSE_PANEL_T).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tw.tween_property(panel, "modulate:a", 0.0, CLOSE_FADE_T).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(on_done)
	return tw

static func _pivot(panel: Control) -> Vector2:
	var sz := panel.size
	if sz == Vector2.ZERO:
		sz = panel.custom_minimum_size
	return sz * 0.5

## Restyle a ScrollContainer's vertical scrollbar to the game look: wider, with a
## subtle dark rounded track and a green rounded grabber. `sf` = the popup's scale.
static func style_scrollbar(sc: ScrollContainer, sf: float) -> void:
	if sc == null:
		return
	var vbar := sc.get_v_scroll_bar()
	if vbar == null:
		return
	var w := maxi(8, int(18.0 * sf))
	var r := maxi(3, int(9.0 * sf))
	vbar.custom_minimum_size = Vector2(w, 0)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.09, 0.12, 0.55)
	track.set_corner_radius_all(r)
	track.content_margin_left = maxf(1.0, 2.0 * sf)
	track.content_margin_right = maxf(1.0, 2.0 * sf)
	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("scroll_focus", track)

	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.30, 0.72, 0.32)
	grab.set_corner_radius_all(r)
	vbar.add_theme_stylebox_override("grabber", grab)
	var grab_h := StyleBoxFlat.new()
	grab_h.bg_color = Color(0.42, 0.84, 0.44)
	grab_h.set_corner_radius_all(r)
	vbar.add_theme_stylebox_override("grabber_highlight", grab_h)
	var grab_p := StyleBoxFlat.new()
	grab_p.bg_color = Color(0.22, 0.58, 0.24)
	grab_p.set_corner_radius_all(r)
	vbar.add_theme_stylebox_override("grabber_pressed", grab_p)
