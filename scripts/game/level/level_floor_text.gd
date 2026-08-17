class_name LevelFloorText
extends Node2D
## Decorative LOCALIZED text painted on the level floor (tutorial hints). Renders like map
## background — under entities, can't be shot away or erased. `text_key` is a localization
## key resolved in the player's language on load.

const Loc := preload("res://scripts/utils/localization.gd")
const UIT := preload("res://scripts/utils/ui_theme.gd")

@export var text_key: String = ""      ## localization key (e.g. "hint_tap_item")
@export var font_size: int = 46
@export var opacity: float = 0.92
@export var max_width: float = 900.0   ## wraps into multiple centred lines past this

func _ready() -> void:
	z_index = 2   # on the floor (above the paint canvas), under entities — like LevelControlsHint
	if text_key == "":
		return
	var lbl := Label.new()
	lbl.text = Loc.t(text_key)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var f := UIT.load_font()
	if f:
		lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.modulate.a = clampf(opacity, 0.0, 1.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centre the label on this node (fixed width so autowrap can centre multi-line text).
	lbl.custom_minimum_size = Vector2(max_width, 0)
	lbl.size = Vector2(max_width, 0)
	add_child(lbl)
	# Position after the layout pass sized the label.
	lbl.ready.connect(func() -> void: lbl.position = -lbl.size / 2.0)
	lbl.resized.connect(func() -> void: lbl.position = -lbl.size / 2.0)
