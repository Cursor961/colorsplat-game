class_name ParticleEffect
extends Node2D
## Simple particle system - converted from Classes/Particle.as
## Manages custom particles (not GPUParticles2D) for paint-death particles.

class PaintParticle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var radius: float = 2.0
	var lifetime: float = 10.0
	var age: float = 0.0
	var friction: float = 0.01
	var death_paint: bool = false
	var player_gravity: bool = false
	var dead: bool = false
	# Chunky death "gib": drawn as a spinning filled square instead of a dot/streak.
	var chunk: bool = false
	var angle: float = 0.0
	var spin: float = 0.0

var _particles: Array[PaintParticle] = []
var _was_active: bool = false  ## true while particles exist; lets _process go quiet when idle
var _floor_paint: FloorPaint  ## Reference for deathPaint splats
var _bounds: Rect2 = Rect2(0, 0, 1920, 1080)

const MAX_PARTICLES := 500  ## Mobile performance cap

func setup(floor_ref: FloorPaint, bounds: Rect2) -> void:
	_floor_paint = floor_ref
	_bounds = bounds

func _process(delta: float) -> void:
	# Idle fast-path: with no particles, skip the whole loop AND the redraw. One final
	# queue_redraw() clears the last frame's particles, then we go fully quiet (no per-frame
	# empty _draw) until the next spawn — matters on phones between kills.
	if _particles.is_empty():
		if _was_active:
			_was_active = false
			queue_redraw()
		return
	_was_active = true

	var dead_indices: Array[int] = []
	# Vacuum particles all target the same player — look it up ONCE per frame, not once per
	# particle (was up to MAX_PARTICLES group queries/frame during the vacuum powerup).
	var grav_player: Node2D = null
	var grav_looked_up := false

	for i in _particles.size():
		var p := _particles[i]
		if p.dead:
			dead_indices.append(i)
			continue

		# Movement
		p.pos += p.vel * delta
		p.vel *= (1.0 - p.friction)
		if p.chunk:
			p.angle += p.spin * delta

		# Wall bounce
		if p.pos.x < _bounds.position.x or p.pos.x > _bounds.end.x:
			p.vel.x = -p.vel.x
			p.pos.x = clampf(p.pos.x, _bounds.position.x, _bounds.end.x)
		if p.pos.y < _bounds.position.y or p.pos.y > _bounds.end.y:
			p.vel.y = -p.vel.y
			p.pos.y = clampf(p.pos.y, _bounds.position.y, _bounds.end.y)

		# Player gravity (powerup vacuum)
		if p.player_gravity:
			if not grav_looked_up:
				grav_looked_up = true
				var players := get_tree().get_nodes_in_group("players")
				grav_player = players[0] as Node2D if not players.is_empty() else null
			if grav_player:
				var player: Node2D = grav_player
				var diff := player.global_position - p.pos
				var dist := diff.length()
				if dist > 1.0:
					var force := 250.0
					p.vel = diff.normalized() * force
					if dist < 30.0:
						p.dead = true

		# Lifetime
		p.age += delta
		if p.age >= p.lifetime:
			p.dead = true

		if p.dead and p.death_paint and _floor_paint:
			_floor_paint.add_small_splat(p.pos, p.color)

	# Remove dead particles (reverse order)
	for i in range(dead_indices.size() - 1, -1, -1):
		_particles.remove_at(dead_indices[i])

	queue_redraw()

func _draw() -> void:
	for p in _particles:
		if p.dead:
			continue
		# Chunky gib: a spinning filled square (reads as a torn-off shard of the monster).
		if p.chunk:
			var r := p.radius
			draw_colored_polygon(PackedVector2Array([
				p.pos + Vector2(-r, -r).rotated(p.angle),
				p.pos + Vector2(r, -r).rotated(p.angle),
				p.pos + Vector2(r, r).rotated(p.angle),
				p.pos + Vector2(-r, r).rotated(p.angle)]), p.color)
			continue
		# Motion blur: line for fast particles, circle for slow
		if p.vel.length_squared() > 120 * 120:
			var prev := p.pos - p.vel * 0.016  # ~1 frame back
			draw_line(prev, p.pos, p.color, p.radius * 2.0)
		else:
			draw_circle(p.pos, p.radius, p.color)

# ============================================================
# SPAWN HELPERS
# ============================================================

## Spawn death explosion particles (monster/player death).
func spawn_death_particles(pos: Vector2, color: Color, count: int = 15, death_paint: bool = true) -> void:
	for i in mini(count, MAX_PARTICLES - _particles.size()):
		var p := PaintParticle.new()
		p.pos = pos
		p.vel = Vector2(CMath.rand(-600, 600), CMath.rand(-600, 600))
		p.color = color
		p.radius = CMath.rand(1.5, 3.0)
		p.lifetime = CMath.rand(0.4, 0.6)
		p.friction = CMath.rand(0.2, 0.4)
		p.death_paint = death_paint
		_particles.append(p)

## Spawn chunky death "gibs" — a few spinning shards in the monster's colour that fly out,
## slow down (heavier friction), and stain the floor where they land (death_paint). Bigger
## and slower than the fine death spray, so a kill reads as the monster being torn apart.
func spawn_gibs(pos: Vector2, color: Color, count: int = 5) -> void:
	for i in mini(count, MAX_PARTICLES - _particles.size()):
		var p := PaintParticle.new()
		p.pos = pos
		p.vel = Vector2(CMath.rand(-420, 420), CMath.rand(-420, 420))
		# Slight shade variation so the shards read as separate chunks, not one blob.
		p.color = color.lerp(Color.BLACK if (i % 2 == 0) else Color.WHITE, CMath.rand(0.0, 0.18))
		p.radius = CMath.rand(3.5, 8.0)
		p.lifetime = CMath.rand(0.5, 0.85)
		p.friction = CMath.rand(0.12, 0.22)
		p.death_paint = true
		p.chunk = true
		p.angle = CMath.rand(0.0, TAU)
		p.spin = CMath.rand(-12.0, 12.0)
		_particles.append(p)

## Spawn bullet impact particles.
func spawn_impact_particles(pos: Vector2, color: Color, count: int = 8) -> void:
	for i in mini(count, MAX_PARTICLES - _particles.size()):
		var p := PaintParticle.new()
		p.pos = pos
		p.vel = Vector2(CMath.rand(-300, 300), CMath.rand(-300, 300))
		p.color = color
		p.radius = CMath.rand(0.5, 2.0)
		p.lifetime = CMath.rand(0.1, 0.4)
		p.friction = 0.3
		p.death_paint = false  # Bullet impacts never mark the floor
		_particles.append(p)

## Spawn damage particles (player hit).
func spawn_damage_particles(pos: Vector2, color: Color, count: int = 10) -> void:
	for i in mini(count, MAX_PARTICLES - _particles.size()):
		var p := PaintParticle.new()
		p.pos = pos
		p.vel = Vector2(CMath.rand(-400, 400), CMath.rand(-400, 400))
		p.color = color
		p.radius = CMath.rand(1.0, 2.5)
		p.lifetime = CMath.rand(0.3, 0.6)
		p.friction = CMath.rand(0.1, 0.3)
		p.death_paint = true
		_particles.append(p)

## Spawn menu decoration particles (random colorful splats).
func spawn_menu_particles(pos: Vector2, count: int = 20) -> void:
	var color := Color(randf(), randf(), randf())
	for i in mini(count, MAX_PARTICLES - _particles.size()):
		var p := PaintParticle.new()
		p.pos = pos
		p.vel = Vector2(CMath.rand(-600, 600), CMath.rand(-600, 600))
		p.color = color
		p.radius = CMath.rand(1.5, 3.0)
		p.lifetime = CMath.rand(2.4, 4.6)
		p.friction = CMath.rand(0.2, 0.4)
		p.death_paint = true
		_particles.append(p)

## Spawn decorative cleaner particles — never leave floor marks (death_paint always false).
func spawn_cleaner_particles(pos: Vector2, count: int = 1) -> void:
	for i in mini(count, MAX_PARTICLES - _particles.size()):
		var p := PaintParticle.new()
		p.pos = pos
		p.vel = Vector2(CMath.rand(-200, 200), CMath.rand(-200, 200))
		p.color = Color(0.9, 0.97, 1.0, 0.9)
		p.radius = CMath.rand(1.0, 2.5)
		p.lifetime = CMath.rand(0.2, 0.5)
		p.friction = 0.35
		p.death_paint = false  ## Never mark the floor
		_particles.append(p)

func clear() -> void:
	_particles.clear()
	queue_redraw()
