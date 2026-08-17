class_name CMath
## Math utilities - converted from Utils/CMath.as
## Static helper functions for random, color, geometry, and interpolation.

## Returns a random float between min_val and max_val (inclusive).
static func rand(min_val: float, max_val: float) -> float:
	return min_val + randf() * (max_val - min_val)

## Returns a random integer between min_val and max_val (inclusive).
static func rand_int(min_val: int, max_val: int) -> int:
	return randi_range(min_val, max_val)

## Converts R, G, B (0-255) to a packed uint color (0xRRGGBB).
static func rgb_to_hex(r: int, g: int, b: int) -> int:
	return (r << 16) | (g << 8) | b

## Converts R, G, B, A (0-255) to a packed uint color (0xAARRGGBB).
static func argb_to_hex(a: int, r: int, g: int, b: int) -> int:
	return (a << 24) | (r << 16) | (g << 8) | b

## Extracts red component (0-255) from a packed color.
static func get_red(color: int) -> int:
	return (color >> 16) & 0xFF

## Extracts green component (0-255) from a packed color.
static func get_green(color: int) -> int:
	return (color >> 8) & 0xFF

## Extracts blue component (0-255) from a packed color.
static func get_blue(color: int) -> int:
	return color & 0xFF

## Extracts alpha component (0-255) from a packed color.
static func get_alpha(color: int) -> int:
	return (color >> 24) & 0xFF

## Converts packed int color to Godot Color.
static func int_to_color(hex_color: int) -> Color:
	var r := float((hex_color >> 16) & 0xFF) / 255.0
	var g := float((hex_color >> 8) & 0xFF) / 255.0
	var b := float(hex_color & 0xFF) / 255.0
	return Color(r, g, b, 1.0)

## Converts Godot Color to packed int (0xRRGGBB).
static func color_to_int(c: Color) -> int:
	return rgb_to_hex(int(c.r * 255), int(c.g * 255), int(c.b * 255))

## Rotates a point (x, y) around origin by angle (radians).
static func rotate_point(x: float, y: float, angle: float) -> Vector2:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	return Vector2(x * cos_a - y * sin_a, x * sin_a + y * cos_a)

## Clamps value between min_val and max_val.
static func clamp_value(value: float, min_val: float, max_val: float) -> float:
	return clampf(value, min_val, max_val)

## Swept circle intersection test.
## Checks if a moving circle (from pos1 to pos2, radius r1) intersects
## a stationary circle (at pos3, radius r2).
## Returns intersection point or Vector2.INF if no intersection.
static func swept_circle_intersect(
	pos1: Vector2, pos2: Vector2, r1: float,
	pos3: Vector2, r2: float
) -> Vector2:
	var d := pos2 - pos1
	var f := pos1 - pos3
	var combined_r := r1 + r2

	var a := d.dot(d)
	var b := 2.0 * f.dot(d)
	var c := f.dot(f) - combined_r * combined_r

	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0:
		return Vector2.INF

	discriminant = sqrt(discriminant)
	var t1 := (-b - discriminant) / (2.0 * a)

	if t1 >= 0.0 and t1 <= 1.0:
		return pos1 + d * t1

	return Vector2.INF

## Checks if two colors are approximately equal (within tolerance).
static func color_equal(c1: Color, c2: Color, tolerance: float = 0.05) -> bool:
	return (absf(c1.r - c2.r) < tolerance and
			absf(c1.g - c2.g) < tolerance and
			absf(c1.b - c2.b) < tolerance)

## Simple cubic spline interpolation between 4 points.
static func spline(t: float, p0: float, p1: float, p2: float, p3: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## Normalizes angle to range [-PI, PI].
static func normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

## Shortest angular distance from a to b.
static func angle_diff(a: float, b: float) -> float:
	return normalize_angle(b - a)

## Linearly interpolate between two values.
static func lerp_value(a: float, b: float, t: float) -> float:
	return a + (b - a) * t
