class_name Juice
## Tiny shared "game feel" helpers with no node dependencies.
## Reference via a local preload alias to dodge global-class timing:
##   const Juice := preload("res://scripts/utils/juice.gd")

## Scale-bounce + sparkle "pop" at a collected pickup's location. Spawned into `parent`
## (the pickup's container) so it survives after the pickup queue_free()s itself.
## `icon` = the pickup's texture (a quick scaling ghost of it); `tint` colors the sparks.
static func pickup_pop(parent: Node, pos: Vector2, icon: Texture2D, tint: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	# Scaling ghost of the icon — pops bigger then fades (the "bounce").
	if icon:
		var ghost := Sprite2D.new()
		ghost.texture = icon
		ghost.global_position = pos
		ghost.z_index = 7
		var ts := icon.get_size()
		var base_sf := 60.0 / maxf(ts.x, ts.y)
		ghost.scale = Vector2(base_sf, base_sf)
		parent.add_child(ghost)
		var tw := ghost.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ghost, "scale", Vector2(base_sf * 1.8, base_sf * 1.8), 0.24) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.24).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(ghost.queue_free)

	# Sparkles flying outward.
	var spark_tex := _spark_texture()
	for i in 8:
		var s := Sprite2D.new()
		s.texture = spark_tex
		s.global_position = pos
		s.z_index = 7
		s.modulate = tint
		var ssf := randf_range(0.18, 0.36)
		s.scale = Vector2(ssf, ssf)
		parent.add_child(s)
		var ang := TAU * float(i) / 8.0 + randf_range(-0.35, 0.35)
		var target := pos + Vector2.from_angle(ang) * randf_range(45.0, 95.0)
		var tw2 := s.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(s, "global_position", target, 0.36) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw2.tween_property(s, "scale", Vector2.ZERO, 0.36).set_ease(Tween.EASE_IN)
		tw2.tween_property(s, "modulate:a", 0.0, 0.36)
		tw2.chain().tween_callback(s.queue_free)

static var _spark_cache: Texture2D = null

## Soft white dot, tinted via modulate when used.
static func _spark_texture() -> Texture2D:
	if _spark_cache:
		return _spark_cache
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c := Vector2(8, 8)
	for y in 16:
		for x in 16:
			var d := Vector2(x, y).distance_to(c)
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(4.0, 8.0, d)))
	_spark_cache = ImageTexture.create_from_image(img)
	return _spark_cache
