class_name UITheme
## Shared UI building blocks — single source of truth for the UI font and the
## rounded StyleBoxFlat factory that every screen used to duplicate.
##
## Usage (reference via a local preload alias to avoid global-class coupling):
##   const UIT := preload("res://scripts/utils/ui_theme.gd")
##   _lilita = UIT.load_font()
##   var sb := UIT.make_sb(_sf, bg, border, corner, border_w, 16.0, 10.0)

const FONT_PATH := "res://assets/fonts/Baloo2-Bold.ttf"

## The game-wide UI font (Baloo 2 Bold — full Czech glyph coverage). Null if missing.
static func load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	return null

## Rounded-rect stylebox. `corner`/`border_w` and the content margins are design-space
## (1920x1080) pixel values, scaled by `sf` — same math every screen used inline.
static func make_sb(sf: float, bg_color: Color, border_color: Color, corner: float,
		border_w: float, margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(maxi(1, int(border_w * sf)))
	sb.set_corner_radius_all(maxi(1, int(corner * sf)))
	if margin_h > 0.0:
		sb.content_margin_left = margin_h * sf
		sb.content_margin_right = margin_h * sf
	if margin_v > 0.0:
		sb.content_margin_top = margin_v * sf
		sb.content_margin_bottom = margin_v * sf
	return sb
