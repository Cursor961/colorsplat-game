class_name FloorPaint
extends Node2D
## Paint system - converted from Classes/Floor.as
## Uses SubViewport as paint canvas. Splats drawn as sprites into SubViewport.
## Provides paint detection for player slowdown and vacuum (powerup).

@export var background_color: Color = Color(0.12, 0.12, 0.12)  ## Dark grey floor
@export var splat_texture_count: int = 10  ## Number of pre-made splat mask textures
@export var vacuum_radius: float = 60.0
@export var vacuum_samples_per_sec: float = 3060.0  ## ~90*34 from original

# ---- PAINT CANVAS ----
var paint_viewport: SubViewport
var paint_sprite: Sprite2D  ## Displays the SubViewport texture on screen
var _splat_textures: Array[Texture2D] = []  ## Pre-loaded splat masks (white PNG)

# ---- PAINT DETECTION (CPU grid — no GPU read-back) ----
## Logical paint coverage on a grid: cell -> color. Updated when splats are added
## or erased, and read for player-slowdown detection. Replaces the old per-frame
## SubViewport.get_image() read-back, which stalled the GPU on mobile.
var _paint_cells: Dictionary = {}   ## Vector2i -> Color
var _erosion: Dictionary = {}       ## Vector2i -> float (accumulated clean amount 0..1, for the drive-over erosion)
var _paint_image: Image = null      ## legacy (unused; do_vacuum is not called)

# ---- ICE FLOOR (unerasable background) ----
## Registered ice slabs (world-space). Ice is baked into the same accumulation buffer as
## everything else, so a cleaner/eraser stamp would punch background-coloured holes into it.
## To keep ice a TRUE background: erase ops that touch an ice rect schedule a (throttled)
## re-stamp of the ice art, and the drive-over paint erosion skips cells on ice entirely.
var _ice_stamps: Array = []          ## [{tex: Texture2D, pos: Vector2, size: Vector2}]
var _ice_restamp_pending: bool = false
var _ice_restamp_cd: float = 0.0
const ICE_RESTAMP_INTERVAL := 0.15   ## min seconds between re-stamps (cleaner erases per-frame)

# ---- BAKE QUEUE ----
## The paint canvas is an accumulation buffer (CLEAR_MODE_NEVER): a splat is drawn
## by one UPDATE_ONCE render, then its node is freed (its pixels stay baked). This
## keeps node count ~0 and means idle frames cost zero GPU. Nodes wait a couple of
## physics frames before freeing so the render has definitely happened.
var _bake_queue: Array = []         ## [{ "node": Node, "frame": int }]

# ---- TRAVERSAL TRACKING (paint wear-off system) ----
## Grid-based tracking of how many times the player has crossed each paint cell.
## 0 passes = full paint (60% slowdown), 1 pass = faded (30% slow), 2 passes = erased (no slow).
var _traversal_grid: Dictionary = {}  ## Vector2i -> int (pass count)
const GRID_CELL_SIZE := 12  ## px per grid cell

## Floor dimensions (set by game_world)
var floor_width: float = 1920.0
var floor_height: float = 1080.0

# ---- CANVAS RESOLUTION CAP ----
## The paint canvas is ONE render target sized to the arena. Numbered levels reach ~10000 px
## across, so a 1:1 buffer would be 120-160 MB RGBA8 AND exceed the max texture size on most
## mobile GPUs (GL ES 3.0 only guarantees 4096) — the allocation simply fails. So the buffer
## is rendered DOWNSCALED and the display sprite is stretched back up. Splats are soft blobs,
## so the resolution loss is invisible in play. A 1920x1080 arena stays 1:1 (scale = 1.0).
const PAINT_MAX_DIM := 4096            ## hard per-axis cap (GPU texture limit)
const PAINT_MAX_PIXELS := 8_400_000    ## total-pixel cap (~33 MB RGBA8)
var _paint_scale: float = 1.0          ## buffer px per world px (1.0 = 1:1)

## Largest scale that keeps the buffer under BOTH caps.
func _compute_paint_scale(w: float, h: float) -> float:
	if w <= 0.0 or h <= 0.0:
		return 1.0
	var s := 1.0
	var longest := maxf(w, h)
	if longest > float(PAINT_MAX_DIM):
		s = float(PAINT_MAX_DIM) / longest
	var px := (w * s) * (h * s)
	if px > float(PAINT_MAX_PIXELS):
		s *= sqrt(float(PAINT_MAX_PIXELS) / px)
	return s

## Buffer size for the current arena at the current scale.
func _buffer_size() -> Vector2i:
	return Vector2i(maxi(1, int(ceil(floor_width * _paint_scale))),
					maxi(1, int(ceil(floor_height * _paint_scale))))

func _ready() -> void:
	pass  # Setup called externally by game_world after scene tree is ready

## Initialize the paint system. Call after scene tree setup.
func setup(width: float, height: float, _parent: Node) -> void:
	floor_width = width
	floor_height = height

	# Joined so the settings UI can trigger a live texture reload on quality change.
	add_to_group("floor_paint")

	# Create SubViewport for paint canvas.
	# Accumulation buffer: never auto-clear, never auto-render. We render ONCE per
	# change (UPDATE_ONCE) and the framebuffer keeps previous paint (CLEAR_MODE_NEVER).
	_paint_scale = _compute_paint_scale(width, height)
	paint_viewport = SubViewport.new()
	paint_viewport.size = _buffer_size()
	paint_viewport.transparent_bg = true
	paint_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	paint_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	paint_viewport.world_2d = World2D.new()  # Isolated rendering
	add_child(paint_viewport)

	# Sprite to display paint on screen - added as our own child so it stays behind
	# game_world's other children (FloorPaint is first child = rendered first = bottom layer).
	# Stretched by 1/_paint_scale so the downscaled buffer still covers the whole arena.
	paint_sprite = Sprite2D.new()
	paint_sprite.texture = paint_viewport.get_texture()
	paint_sprite.centered = false
	paint_sprite.scale = Vector2.ONE / _paint_scale
	paint_sprite.z_index = -10  # Force behind everything else
	add_child(paint_sprite)

	# Bake the dark floor background into the buffer once.
	_stamp_fullscreen_bg()

	# Clear traversal grid on setup/reset
	_traversal_grid.clear()

	# Load splat mask textures (white masks, colored via modulate)
	_load_splat_textures()

func _physics_process(_delta: float) -> void:
	# Throttled ice re-stamp: an eraser touched an ice slab → repaint the ice art over the
	# hole (throttle because the cleaner's eraser moves/erases every frame).
	_ice_restamp_cd = maxf(_ice_restamp_cd - _delta, 0.0)
	if _ice_restamp_pending and _ice_restamp_cd <= 0.0:
		_ice_restamp_pending = false
		_ice_restamp_cd = ICE_RESTAMP_INTERVAL
		_restamp_ice()
	# Free splat nodes whose paint has been baked into the buffer (>= 2 physics
	# frames old, so the UPDATE_ONCE render has definitely run).
	if _bake_queue.is_empty():
		return
	var cur := Engine.get_physics_frames()
	var i := _bake_queue.size() - 1
	while i >= 0:
		var e: Dictionary = _bake_queue[i]
		if cur - int(e["frame"]) >= 2:
			var n: Node = e["node"]
			if is_instance_valid(n):
				n.queue_free()
			_bake_queue.remove_at(i)
		i -= 1

# ============================================================
# ACCUMULATION-CANVAS HELPERS
# ============================================================

## Request one render of the paint canvas (it then idles again).
func _trigger_render() -> void:
	if paint_viewport:
		paint_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Queue a freshly-added node to be freed once its pixels are baked in.
func _queue_bake(node: Node) -> void:
	_bake_queue.append({"node": node, "frame": Engine.get_physics_frames()})
	_trigger_render()

## Re-stamp the floor background a couple of frames AFTER a level (re)load. The paint canvas
## is a CLEAR_MODE_NEVER accumulation buffer: right after set_arena_size recreates the render
## target its memory is UNDEFINED and can show random GPU garbage (a stretched ice/lootbox/UI
## texture lying "on the floor"). The load-frame bg stamp can render before the resize lands,
## so this delayed repaint guarantees a clean floor. Ice tiles re-stamp 3 frames in — after this.
func settle_repaint() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_stamp_fullscreen_bg()

## Paint the whole canvas with the floor background color (used on setup + clear).
func _stamp_fullscreen_bg() -> void:
	if paint_viewport == null:
		return
	var bg := ColorRect.new()
	bg.color = background_color
	bg.size = Vector2(paint_viewport.size)   # buffer coords (canvas may be downscaled)
	bg.position = Vector2.ZERO
	paint_viewport.add_child(bg)
	_queue_bake(bg)

## Resize the paint canvas to a new playfield size. Levels can be LARGER (or smaller)
## than the default 1920x1080, and splats must cover the whole level. Recreates the
## render target and re-stamps the dark background. Call BEFORE the level's ice/floor
## stamps so they aren't wiped. (No-op if the size is unchanged.)
func set_arena_size(width: float, height: float) -> void:
	if paint_viewport == null:
		return
	if is_equal_approx(floor_width, width) and is_equal_approx(floor_height, height):
		return
	floor_width = width
	floor_height = height
	_paint_scale = _compute_paint_scale(width, height)
	# Drop any pending bakes + baked nodes, resize the render target, repaint the floor.
	_bake_queue.clear()
	for child in paint_viewport.get_children():
		child.queue_free()
	paint_viewport.size = _buffer_size()
	if paint_sprite:
		paint_sprite.scale = Vector2.ONE / _paint_scale
	_ice_stamps.clear()   # ice tiles re-register when the (re)loaded layout stamps them
	_ice_restamp_pending = false
	_paint_cells.clear()
	_erosion.clear()
	_traversal_grid.clear()
	_cleaner_eraser = null
	_stamp_fullscreen_bg()

## Stamp a texture into the floor canvas (e.g. an ICE patch) — it bakes ON TOP of the dark
## background but UNDER any splats painted afterwards, so splats stay visible on it.
## `world_pos` = centre, `world_size` = px area to cover. Call AFTER setup/clear.
func stamp_floor(tex: Texture2D, world_pos: Vector2, world_size: Vector2) -> void:
	if paint_viewport == null or tex == null:
		return
	_do_floor_stamp(tex, world_pos, world_size)
	# Register the slab (dedup — ice tiles re-stamp once after the canvas settles) so erase
	# operations can restore it; see the ICE FLOOR block up top.
	for e: Dictionary in _ice_stamps:
		if (e["pos"] as Vector2).distance_to(world_pos) < 1.0 and (e["size"] as Vector2) == world_size:
			return
	_ice_stamps.append({"tex": tex, "pos": world_pos, "size": world_size})

## The actual bake of one floor slab (used by stamp_floor and the ice re-stamp).
func _do_floor_stamp(tex: Texture2D, world_pos: Vector2, world_size: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	# Pixelart slab: crisp pixels even stretched to slab size / downscaled canvases.
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var t := tex.get_size()
	if t.x > 0.0 and t.y > 0.0:
		s.scale = Vector2(world_size.x * _paint_scale / t.x, world_size.y * _paint_scale / t.y)
	s.position = world_pos * _paint_scale
	paint_viewport.add_child(s)
	_queue_bake(s)

## True if a world-space circle touches any registered ice slab.
func _ice_overlaps_circle(pos: Vector2, radius: float) -> bool:
	for e: Dictionary in _ice_stamps:
		var half: Vector2 = (e["size"] as Vector2) * 0.5
		var rect := Rect2((e["pos"] as Vector2) - half, e["size"] as Vector2)
		if rect.grow(radius).has_point(pos):
			return true
	return false

## True if a world-space point sits on any registered ice slab.
func _pos_on_ice(pos: Vector2) -> bool:
	for e: Dictionary in _ice_stamps:
		var half: Vector2 = (e["size"] as Vector2) * 0.5
		if Rect2((e["pos"] as Vector2) - half, e["size"] as Vector2).has_point(pos):
			return true
	return false

## Re-bake every registered ice slab (over whatever an eraser just stamped on it).
func _restamp_ice() -> void:
	for e: Dictionary in _ice_stamps:
		_do_floor_stamp(e["tex"], e["pos"], e["size"])

func _cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / GRID_CELL_SIZE, int(world_pos.y) / GRID_CELL_SIZE)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * GRID_CELL_SIZE + GRID_CELL_SIZE * 0.5,
				   cell.y * GRID_CELL_SIZE + GRID_CELL_SIZE * 0.5)

## Mark logical paint coverage on the CPU grid (used for slowdown detection).
func _mark_paint(pos: Vector2, color: Color, paint_radius: float) -> void:
	if paint_radius < GRID_CELL_SIZE * 0.6:
		var c := _cell_of(pos)
		_paint_cells[c] = color
		_traversal_grid.erase(c)  # fresh paint slows the player again
		return
	var gr := int(paint_radius / GRID_CELL_SIZE) + 1
	var center := _cell_of(pos)
	for dy in range(-gr, gr + 1):
		for dx in range(-gr, gr + 1):
			var cell := center + Vector2i(dx, dy)
			if _cell_to_world(cell).distance_to(pos) <= paint_radius:
				_paint_cells[cell] = color
				_traversal_grid.erase(cell)

## Clear logical paint within a radius (cleaner / eraser).
func _clear_paint_radius(pos: Vector2, radius: float) -> void:
	var gr := int(radius / GRID_CELL_SIZE) + 1
	var center := _cell_of(pos)
	for dy in range(-gr, gr + 1):
		for dx in range(-gr, gr + 1):
			var cell := center + Vector2i(dx, dy)
			if _cell_to_world(cell).distance_to(pos) <= radius:
				_paint_cells.erase(cell)
				_traversal_grid.erase(cell)

# ============================================================
# SPLAT DRAWING
# ============================================================

## Add a paint splat at world position with given color.
## Called on monster death, bullet impact, player death.
func add_splat(pos: Vector2, color: Color, scale_mult: float = 1.0, rotation_rad: float = -1.0) -> void:
	if _splat_textures.is_empty():
		return

	var tex: Texture2D = _splat_textures[randi() % _splat_textures.size()]
	var splat := Sprite2D.new()
	splat.texture = tex
	splat.modulate = color
	splat.position = pos * _paint_scale
	splat.scale = Vector2(scale_mult, scale_mult) * CMath.rand(0.2, 0.5) * 0.75 * _paint_scale

	if rotation_rad < 0:
		splat.rotation = CMath.rand(0.0, TAU)
	else:
		splat.rotation = rotation_rad

	paint_viewport.add_child(splat)
	_queue_bake(splat)
	# Mark logical coverage (~ visual footprint) for slowdown detection.
	_mark_paint(pos, color, scale_mult * 34.0)

## Add a small splat (bullet impact).
## Darkening applied to the TOP splat layer (particle-baked detail splats) — set by
## game_world from the color-distinction setting (the immediate bottom layer is darker).
var top_splat_darken: float = 0.0

func add_small_splat(pos: Vector2, color: Color) -> void:
	add_splat(pos, color.darkened(top_splat_darken), CMath.rand(0.1, 0.3))

## Clear all paint (new game).
func clear() -> void:
	_traversal_grid.clear()
	_paint_cells.clear()
	_erosion.clear()
	_ice_stamps.clear()   # ice tiles re-register when the (re)loaded layout stamps them
	_ice_restamp_pending = false
	_cleaner_eraser = null  # Will be recreated on next erase call
	_bake_queue.clear()
	if paint_viewport:
		# Remove any lingering splat/erase nodes, then repaint the floor background
		# over the accumulated buffer.
		for child in paint_viewport.get_children():
			child.queue_free()
		_stamp_fullscreen_bg()

# ============================================================
# PAINT DETECTION (player slowdown with traversal wear-off)
# ============================================================

## Check paint color under player (logical CPU grid — no GPU read-back).
## Returns the paint color under the player, or Color.TRANSPARENT if no paint.
func check_player_paint(player_pos: Vector2, _player_color: Color) -> Color:
	# CPU grid only stores actual paint (no background), so presence == paint.
	return _paint_cells.get(_cell_of(player_pos), Color.TRANSPARENT)

## Returns true if the color at pos is enemy paint (different from player color).
func is_enemy_paint(pos: Vector2, player_color: Color) -> bool:
	var paint_color := check_player_paint(pos, player_color)
	if paint_color == Color.TRANSPARENT:
		return false
	return not CMath.color_equal(paint_color, player_color, 0.15)

## Per-cell paint erosion (cheap — no shader, no streak sprites). When the player crosses
## enemy paint, each cell under it is cleaned in tiers (rolled per cell, cumulative across
## passes — repeated driving fully clears it):
##   30% → fully cleaned, 40% → −50% opacity, 30% → −25% opacity.
## A cell that has accumulated ≥0.9 erosion is wiped and stops slowing the player.
## Returns the speed multiplier (1.0 = no slow, 0.4 = on enemy paint).
const ERODE_CLEAR_CHANCE := 0.30   ## fully clean
const ERODE_HALF_CHANCE := 0.40    ## −50% opacity (rest = −25%)
func process_player_paint(player_pos: Vector2, player_radius: float, player_color: Color, _player_velocity: Vector2 = Vector2.ZERO) -> float:
	var center_color: Color = _paint_cells.get(_cell_of(player_pos), Color.TRANSPARENT)
	var on_enemy_paint := center_color.a >= 0.1 and not CMath.color_equal(center_color, player_color, 0.15)

	var check_radius := player_radius * 1.3
	var grid_r := int(check_radius / GRID_CELL_SIZE) + 1
	var center_cell := _cell_of(player_pos)

	for dy in range(-grid_r, grid_r + 1):
		for dx in range(-grid_r, grid_r + 1):
			var cell := center_cell + Vector2i(dx, dy)
			var cell_world := _cell_to_world(cell)
			if cell_world.distance_to(player_pos) > check_radius:
				continue
			var cell_color: Color = _paint_cells.get(cell, Color.TRANSPARENT)
			if cell_color.a < 0.1:
				continue
			if CMath.color_equal(cell_color, player_color, 0.15):
				continue
			# No drive-over erosion ON ICE — the cover stamps would punch background-coloured
			# holes into the (unerasable) ice art. Paint on ice just stays until a cleaner
			# wipes it (which re-stamps the ice underneath).
			if _pos_on_ice(cell_world):
				continue

			# Roll this cell's cleaning tier.
			var roll := randf()
			var add: float
			if roll < ERODE_CLEAR_CHANCE:
				add = 1.0
			elif roll < ERODE_CLEAR_CHANCE + ERODE_HALF_CHANCE:
				add = 0.5
			else:
				add = 0.25
			var total := float(_erosion.get(cell, 0.0)) + add
			if total >= 0.9:
				_stamp_cover(cell_world, 1.0)   # finish: fully clean
				_paint_cells.erase(cell)
				_erosion.erase(cell)
				_traversal_grid.erase(cell)
			else:
				_stamp_cover(cell_world, add)
				_erosion[cell] = total

	return 0.4 if on_enemy_paint else 1.0

## Stamp a background-colored square over one grid cell with the given alpha — fades
## (or fully clears at alpha 1.0) the baked paint there. The buffer accumulates, so
## repeated partial stamps add up.
func _stamp_cover(world_pos: Vector2, alpha: float) -> void:
	if paint_viewport == null:
		return
	var rect := ColorRect.new()
	rect.color = Color(background_color.r, background_color.g, background_color.b, clampf(alpha, 0.0, 1.0))
	# Buffer coords; never smaller than 1 px so a downscaled canvas still erases the cell.
	rect.size = Vector2(maxf(1.0, GRID_CELL_SIZE * _paint_scale), maxf(1.0, GRID_CELL_SIZE * _paint_scale))
	rect.position = (world_pos - Vector2(GRID_CELL_SIZE * 0.5, GRID_CELL_SIZE * 0.5)) * _paint_scale
	paint_viewport.add_child(rect)
	_queue_bake(rect)

# ============================================================
# CLEANER POWERUP (erase paint in radius around player)
# ============================================================

## Persistent eraser sprite in the SubViewport — reused every frame instead of
## creating a new node each call (avoids node pile-up / floor visual artifacts).
var _circle_eraser_tex: Texture2D = null
var _cleaner_eraser: Sprite2D = null
var _cleaner_eraser_radius: float = 0.0

## Move the persistent eraser to pos. Creates it on first call.
## Also clears traversal grid cells within radius.
func erase_paint_radius(pos: Vector2, radius: float) -> void:
	if paint_viewport == null:
		return

	# Create circle texture once
	if _circle_eraser_tex == null:
		_circle_eraser_tex = _create_circle_texture(64)

	# Create or reuse a single persistent eraser node
	if _cleaner_eraser == null or not is_instance_valid(_cleaner_eraser):
		_cleaner_eraser = Sprite2D.new()
		_cleaner_eraser.texture = _circle_eraser_tex
		_cleaner_eraser.modulate = background_color
		paint_viewport.add_child(_cleaner_eraser)

	# Rescale only when radius changes (buffer coords)
	if _cleaner_eraser_radius != radius:
		_cleaner_eraser_radius = radius
		var diameter := radius * 2.0 * _paint_scale
		var sf := diameter / 64.0
		_cleaner_eraser.scale = Vector2(sf, sf)

	_cleaner_eraser.position = pos * _paint_scale

	# Clear logical paint within radius and render the moving eraser this frame.
	_clear_paint_radius(pos, radius)
	if _ice_overlaps_circle(pos, radius):
		_ice_restamp_pending = true   # the eraser wiped over ice → repaint the slab (throttled)
	_trigger_render()

## Stamp a PERMANENT background-colored circle on the SubViewport.
## Unlike the persistent eraser (which moves with the player), these stay forever
## and truly erase paint until new monsters die on top.
func stamp_permanent_eraser(pos: Vector2, radius: float) -> void:
	if paint_viewport == null:
		return
	if _circle_eraser_tex == null:
		_circle_eraser_tex = _create_circle_texture(64)
	var stamp := Sprite2D.new()
	stamp.texture = _circle_eraser_tex
	stamp.modulate = background_color
	stamp.position = pos * _paint_scale
	var diameter := radius * 2.0 * _paint_scale
	var sf := diameter / 64.0
	stamp.scale = Vector2(sf, sf)
	paint_viewport.add_child(stamp)
	_queue_bake(stamp)
	_clear_paint_radius(pos, radius)
	if _ice_overlaps_circle(pos, radius):
		_ice_restamp_pending = true   # permanent eraser hit ice → repaint the slab

## Hide the persistent cleaner eraser (call when powerup ends).
func hide_cleaner_eraser() -> void:
	if _cleaner_eraser and is_instance_valid(_cleaner_eraser):
		_cleaner_eraser.position = Vector2(-9999.0, -9999.0)
		_trigger_render()
		if not _ice_stamps.is_empty():
			_ice_restamp_pending = true   # final pass: heal any ice the eraser ended on

## Create a filled white circle texture (used as eraser mask, tinted via modulate).
func _create_circle_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(size / 2.0, size / 2.0)
	var r := size / 2.0
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= r:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

# ============================================================
# VACUUM (powerup mode - absorb paint for points)
# ============================================================

## Vacuum paint around position. Returns score points earned.
func do_vacuum(pos: Vector2, delta: float) -> int:
	if _paint_image == null:
		return 0

	var points := 0
	var samples := int(vacuum_samples_per_sec * delta)

	for i in samples:
		var offset := Vector2(CMath.rand(-vacuum_radius, vacuum_radius),
							  CMath.rand(-vacuum_radius, vacuum_radius))
		if offset.length() > vacuum_radius:
			continue

		var px := clampi(int(pos.x + offset.x), 0, _paint_image.get_width() - 1)
		var py := clampi(int(pos.y + offset.y), 0, _paint_image.get_height() - 1)
		var color := _paint_image.get_pixel(px, py)

		if color.a > 0.3:
			# Desaturate paint (visual feedback)
			var luminance := 0.3 * color.r + 0.59 * color.g + 0.11 * color.b
			points += ceili(5.0 * luminance)

	return points

# ============================================================
# TEXTURE LOADING
# ============================================================

## Paint detail tiers all share the SAME organic splat shape (the imported SVG
## masks), so the splat's footprint on the ground is IDENTICAL across settings.
## Only the size/appearance of the detail elements changes:
##   low  → the shape pixelated into chunky blocks (coarse detail)
##   mid  → the organic SVG mask as-is (this was the old "high" look)
##   high → the organic mask plus fine paint-spray droplets (finest detail)
func _load_splat_textures() -> void:
	var quality: String = SaveManager.get_setting("paint_quality", "mid")

	# Load the shared base masks once (same footprint for every tier).
	var base_images: Array[Image] = _load_base_splat_images()
	if base_images.is_empty():
		# SVG/PNG art missing — fall back to procedural generation.
		_generate_procedural_splats(quality)
		return

	for im: Image in base_images:
		match quality:
			"low":
				_splat_textures.append(_pixelate_image(im, 22))
			"high":
				_splat_textures.append(_detail_image(im))
			_:  # "mid" (default) — organic mask unchanged
				_splat_textures.append(ImageTexture.create_from_image(im))

## Load the organic splat masks as 256x256 RGBA8 images (shared by all tiers).
func _load_base_splat_images() -> Array[Image]:
	var images: Array[Image] = []
	for i in splat_texture_count:
		var svg_path := "res://assets/sprites/effects/paint_splats/splat_mask_%02d.svg" % (i + 1)
		var png_path := "res://assets/sprites/effects/paint_splats/splat_mask_%02d.png" % (i + 1)
		var tex: Texture2D = null
		if ResourceLoader.exists(svg_path):
			tex = load(svg_path)
		elif ResourceLoader.exists(png_path):
			tex = load(png_path)
		if tex == null:
			continue
		var im := tex.get_image()
		if im == null:
			continue
		if im.is_compressed():
			im.decompress()
		if im.get_format() != Image.FORMAT_RGBA8:
			im.convert(Image.FORMAT_RGBA8)
		images.append(im)
	return images

## LOW tier: downsample the mask to a small grid then nearest-upscale, producing
## chunky pixel blocks. The white silhouette (footprint) is preserved exactly.
func _pixelate_image(src: Image, blocks: int) -> Texture2D:
	var im := src.duplicate() as Image
	im.resize(blocks, blocks, Image.INTERPOLATE_NEAREST)
	im.resize(256, 256, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(im)

## HIGH tier: keep the organic mask and add fine paint-spray droplets hugging the
## shape's edge. Droplets stay within a few px of existing paint so the overall
## footprint is unchanged — only fine detail is added.
func _detail_image(src: Image) -> Texture2D:
	var im := src.duplicate() as Image
	var droplets := CMath.rand_int(45, 85)
	var placed := 0
	var attempts := 0
	var max_attempts := droplets * 10
	while placed < droplets and attempts < max_attempts:
		attempts += 1
		var x := randi() % 256
		var y := randi() % 256
		# Seed droplets only next to existing paint (keeps them on the splat).
		if im.get_pixel(x, y).a <= 0.5:
			continue
		var ang := CMath.rand(0.0, TAU)
		var off := CMath.rand(2.0, 9.0)
		var dx := int(x + cos(ang) * off)
		var dy := int(y + sin(ang) * off)
		if dx < 0 or dx >= 256 or dy < 0 or dy >= 256:
			continue
		var ds := CMath.rand_int(1, 3)
		_draw_rect_on_image(im, Vector2(dx, dy), ds, ds, Color.WHITE)
		placed += 1
	return ImageTexture.create_from_image(im)

## Reload splat textures when quality setting changes (called externally).
func reload_splat_textures() -> void:
	_splat_textures.clear()
	_load_splat_textures()

func _generate_procedural_splats(quality: String) -> void:
	for i in splat_texture_count:
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var center := Vector2(128, 128)

		match quality:
			"low":
				# Simple large square blocks — minimal detail
				var arm_count := CMath.rand_int(6, 12)
				for a in arm_count:
					var angle := CMath.rand(0, TAU)
					var arm_length := CMath.rand(40, 120)
					var block_count := CMath.rand_int(2, 6)
					for s in block_count:
						var t := pow(randf(), 2.0) * arm_length
						var sx := center.x + cos(angle) * t
						var sy := center.y + sin(angle) * t
						var block_size := int((1.0 - t / arm_length) * 18.0 * CMath.rand(0.5, 1.0))
						block_size = maxi(block_size, 4)
						_draw_rect_on_image(img, Vector2(sx, sy), block_size, block_size, Color.WHITE)
			"mid":
				# Square blocks with more dots — higher detail
				var arm_count := CMath.rand_int(8, 24)
				for a in arm_count:
					var angle := CMath.rand(0, TAU)
					var arm_length := CMath.rand(40, 115)
					var block_count := CMath.rand_int(5, 20)
					for s in block_count:
						var t := pow(randf(), 3.0) * arm_length
						var sx := center.x + cos(angle) * t + CMath.rand(-6, 6)
						var sy := center.y + sin(angle) * t + CMath.rand(-6, 6)
						var block_size := int((1.0 - t / arm_length) * 10.0 * CMath.rand(0.3, 1.0))
						block_size = maxi(block_size, 2)
						_draw_rect_on_image(img, Vector2(sx, sy), block_size, block_size, Color.WHITE)
				# Extra scatter dots for detail
				for _d in CMath.rand_int(20, 50):
					var angle := CMath.rand(0, TAU)
					var dist := CMath.rand(10, 120)
					var px := center.x + cos(angle) * dist
					var py := center.y + sin(angle) * dist
					var dot_size := CMath.rand_int(1, 4)
					_draw_rect_on_image(img, Vector2(px, py), dot_size, dot_size, Color.WHITE)
			_:  # "high" fallback (if SVGs not found)
				# Ellipses and organic shapes — fluid simulation look
				var arm_count := CMath.rand_int(6, 16)
				for a in arm_count:
					var angle := CMath.rand(0, TAU)
					var arm_length := CMath.rand(40, 120)
					var blob_count := CMath.rand_int(4, 12)
					for s in blob_count:
						var t := pow(randf(), 2.5) * arm_length
						var sx := center.x + cos(angle) * t + CMath.rand(-8, 8)
						var sy := center.y + sin(angle) * t + CMath.rand(-8, 8)
						var rx := int((1.0 - t / arm_length) * 14.0 * CMath.rand(0.4, 1.2))
						var ry := int((1.0 - t / arm_length) * 14.0 * CMath.rand(0.3, 0.8))
						rx = maxi(rx, 2)
						ry = maxi(ry, 2)
						_draw_ellipse_on_image(img, Vector2(sx, sy), rx, ry, Color.WHITE)

		var tex := ImageTexture.create_from_image(img)
		_splat_textures.append(tex)

func _draw_rect_on_image(img: Image, pos: Vector2, w: int, h: int, color: Color) -> void:
	var x0 := clampi(int(pos.x) - w / 2, 0, img.get_width() - 1)
	var y0 := clampi(int(pos.y) - h / 2, 0, img.get_height() - 1)
	var x1 := clampi(int(pos.x) + w / 2, 0, img.get_width() - 1)
	var y1 := clampi(int(pos.y) + h / 2, 0, img.get_height() - 1)
	for dy in range(y0, y1 + 1):
		for dx in range(x0, x1 + 1):
			img.set_pixel(dx, dy, color)

func _draw_ellipse_on_image(img: Image, pos: Vector2, rx: int, ry: int, color: Color) -> void:
	var x0 := clampi(int(pos.x) - rx, 0, img.get_width() - 1)
	var y0 := clampi(int(pos.y) - ry, 0, img.get_height() - 1)
	var x1 := clampi(int(pos.x) + rx, 0, img.get_width() - 1)
	var y1 := clampi(int(pos.y) + ry, 0, img.get_height() - 1)
	var cx := pos.x
	var cy := pos.y
	var rxf := float(maxi(rx, 1))
	var ryf := float(maxi(ry, 1))
	for dy in range(y0, y1 + 1):
		for dx in range(x0, x1 + 1):
			var ex := (float(dx) - cx) / rxf
			var ey := (float(dy) - cy) / ryf
			if ex * ex + ey * ey <= 1.0:
				img.set_pixel(dx, dy, color)
