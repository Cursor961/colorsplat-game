class_name TeleportAnim
## Shared, cached builder for the animated teleports (looped at 32 fps). Frames come from
## a single sprite-sheet PNG per colour (tp_<colour>_sheet.png) — 171 cells of CELL×CELL
## laid out COLS wide. ONE texture per colour (was 171 huge 1060×970 SVGs ≈ 2 GB → ~18 MB).
## Green + pink = paired teleports; blue = level-end goal.

const FPS := 73.6     ## 32 base × 2.3 (portal/teleport spin sped up per request)
const CELL := 160     ## cell size in the sheet (px)
const COLS := 16      ## cells per sheet row
const FRAMES := 171   ## total frames (sheet rows = ceil(171/16) = 11)
## The source frames were non-square (~9% taller than wide) but got squished into square
## sheet cells, so the portal renders as a vertical ellipse. Stretch X back to round it.
const ASPECT_CORRECTION := 1.09
const SHEET := {
	"green": "res://assets/sprites/levels/tp_green_sheet.png",
	"pink": "res://assets/sprites/levels/tp_pink_sheet.png",
	"blue": "res://assets/sprites/levels/tp_blue_sheet.png",
}

static var _cache: Dictionary = {}   ## colour → SpriteFrames (built once, shared)

## Cached SpriteFrames for a colour — AtlasTexture frames into the shared sheet texture.
static func frames(color: String) -> SpriteFrames:
	if _cache.has(color):
		return _cache[color]
	var path: String = SHEET.get(color, SHEET["blue"])
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", FPS)
	sf.set_animation_loop("default", true)
	if ResourceLoader.exists(path):
		var sheet: Texture2D = load(path)
		for i in FRAMES:
			@warning_ignore("integer_division")
			var row := i / COLS
			var col := i % COLS
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(col * CELL, row * CELL, CELL, CELL)
			sf.add_frame("default", at)
	_cache[color] = sf
	return sf

## An AnimatedSprite2D looping the colour's sequence, scaled so its art ≈ `size` px.
## Starts on a random frame so multiple teleports aren't perfectly in sync.
static func make_sprite(color: String, size: float) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames(color)
	a.animation = "default"
	var count := a.sprite_frames.get_frame_count("default")
	if count > 0:
		var sf := size / float(CELL)
		a.scale = Vector2(sf * ASPECT_CORRECTION, sf)   # X-stretch rounds the squished cell
		a.frame = randi() % count
	a.play("default")
	return a
