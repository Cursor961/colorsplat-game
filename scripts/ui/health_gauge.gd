class_name HealthGauge
extends Control
## Semicircle (dome) HP gauge — a dark dome with a green arc that depletes and
## shifts toward red as HP drops. Shows the HP percentage prominently with the
## raw "X HP" value beneath it. Drawn bottom-up: the flat side is the control's
## bottom edge, the dome rises above it.

const TRACK_COLOR := Color(0.18, 0.18, 0.21)
const DOME_OUTER := Color(0.14, 0.14, 0.16)
const DOME_INNER := Color(0.09, 0.09, 0.11)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const HP_FULL := Color(0.20, 0.92, 0.25)   ## green at full HP
const HP_LOW := Color(0.95, 0.20, 0.15)    ## red at low HP

var _frac: float = 1.0        ## 0..1 HP fraction (drives arc length + color)
var _value: int = 0           ## current HP
var _font: Font
var _pct_label: Label         ## big percentage
var _hp_label: Label          ## small "X HP" value

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pct_label = _make_label(0.34, 0.74)   # upper text band (big %)
	_hp_label = _make_label(0.72, 1.0)     # lower text band (small HP)
	add_child(_pct_label)
	add_child(_hp_label)
	_style_labels()
	resized.connect(func() -> void:
		_style_labels()
		queue_redraw())

func _make_label(top_frac: float, bottom_frac: float) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = top_frac
	l.anchor_bottom = bottom_frac
	return l

func set_font(f: Font) -> void:
	_font = f
	_style_labels()

## Update the gauge. current/max in HP units.
func set_hp(current: float, max_hp: float) -> void:
	_frac = clampf(current / maxf(max_hp, 1.0), 0.0, 1.0)
	_value = maxi(0, int(round(current)))
	var pct := 0
	if current > 0.0:
		pct = maxi(1, int(round(_frac * 100.0)))
	if _pct_label:
		_pct_label.text = "%d%%" % pct
	if _hp_label:
		_hp_label.text = "%d HP" % _value
	queue_redraw()

func _style_labels() -> void:
	if _pct_label == null:
		return
	var big := maxi(16, int(size.y * 0.30))
	var small := maxi(11, int(size.y * 0.16))
	for entry in [[_pct_label, big, Color.WHITE], [_hp_label, small, Color(0.85, 0.9, 0.85)]]:
		var l: Label = entry[0]
		if _font:
			l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", entry[1])
		l.add_theme_color_override("font_color", entry[2])
		l.add_theme_constant_override("outline_size", maxi(2, int(size.y * 0.045)))
		l.add_theme_color_override("font_outline_color", Color.BLACK)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var center := Vector2(w * 0.5, h)          # bottom-center; dome rises upward
	var r_out := minf(w * 0.5, h)              # outer dome radius
	var thickness := r_out * 0.16
	var r_arc := r_out - thickness * 0.7       # centerline radius of the HP arc

	# Filled dome (outer + inner for a bit of depth)
	_fill_dome(center, r_out, DOME_OUTER)
	_fill_dome(center, r_out - thickness * 1.35, DOME_INNER)

	# Track groove (full upper semicircle: PI -> TAU goes left -> top -> right)
	draw_arc(center, r_arc, PI, TAU, 80, TRACK_COLOR, thickness, true)

	# HP arc — fills from the left, length proportional to HP; green -> red.
	if _frac > 0.0:
		var hp_color := HP_LOW.lerp(HP_FULL, _frac)
		draw_arc(center, r_arc, PI, PI + _frac * PI, 80, hp_color, thickness, true)

	# Thin outline along the outer dome edge for definition.
	draw_arc(center, r_out, PI, TAU, 80, OUTLINE_COLOR, maxf(2.0, thickness * 0.12), true)

## Fill an upper semicircle (dome) of the given radius/color via a polygon.
func _fill_dome(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var a := PI + (PI * float(i) / float(steps))   # PI -> TAU (left -> right over top)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
