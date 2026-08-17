class_name EnemyBullet
extends Node2D
## Projectile fired by ranged monsters (currently the Healer) at the player.
## Flies in a straight line, damages the player on contact, then despawns.
## Built entirely in code (no .tscn) — collision is a simple radius check so it
## does not depend on physics-layer configuration.
##
## It spawns underneath the firing monster (z_index below monsters) and is sized
## to roughly the monster's footprint, so the spawn moment stays hidden.

const LIFETIME := 6.0          ## Seconds before auto-despawn
const OFFSCREEN_MARGIN := 80.0 ## Despawn this far past the arena edge

var direction: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var damage: float = 50.0        ## Absolute HP damage (resolved from % at spawn)
var collide_radius: float = 22.0
## Turret shots also hurt MONSTERS caught in their path (same `damage`). Healer projectiles
## keep this off — a healer must never friendly-fire the pack it protects.
var hits_monsters: bool = false

var _life: float = LIFETIME
var _sprite: Sprite2D = null
## Despawn bounds = arena + margin (cached in _ready). Uses the ARENA size, not the
## 1920x1080 viewport, so projectiles survive across larger levels.
var _despawn_min: Vector2 = Vector2(-OFFSCREEN_MARGIN, -OFFSCREEN_MARGIN)
var _despawn_max: Vector2 = Vector2(1920 + OFFSCREEN_MARGIN, 1080 + OFFSCREEN_MARGIN)

func _ready() -> void:
	z_index = 3  ## Below monsters (z=6) so it is hidden under the shooter on spawn
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw:
		var aw: float = float(gw.get("arena_width"))
		var ah: float = float(gw.get("arena_height"))
		if aw > 0.0 and ah > 0.0:
			_despawn_max = Vector2(aw + OFFSCREEN_MARGIN, ah + OFFSCREEN_MARGIN)

## Configure the projectile. `target_diameter` sizes the visible sprite.
func setup(pos: Vector2, dir: Vector2, spd: float, dmg: float, tex: Texture2D, target_diameter: float) -> void:
	global_position = pos
	direction = dir.normalized()
	speed = spd
	damage = dmg
	collide_radius = target_diameter * 0.4

	if tex:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		var tex_size := tex.get_size()
		var sf := target_diameter / maxf(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(sf, sf)
		_sprite.rotation = direction.angle() + PI / 2.0  ## SVG points up (-Y)
		add_child(_sprite)

func _physics_process(delta: float) -> void:
	# Frozen by the Stoppill powerup, just like monsters.
	if GameManager.time_stopped:
		return

	global_position += direction * speed * delta

	# Spin slightly for a livelier paint-blob look.
	if _sprite:
		_sprite.rotation += delta * 2.0

	# Block on walls / solids — enemy projectiles don't pass through level geometry.
	var space := get_world_2d().direct_space_state
	var pq := PhysicsPointQueryParameters2D.new()
	pq.position = global_position
	pq.collision_mask = 1            # walls + arena boundary + other solids (layer bit 1)
	pq.collide_with_bodies = true
	pq.collide_with_areas = false
	if not space.intersect_point(pq).is_empty():
		queue_free()
		return

	# Hit detection against the player (manual radius check).
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p is Player:
			var player := p as Player
			if player.is_dead:
				continue
			if global_position.distance_to(player.global_position) <= collide_radius + player.radius:
				player.take_damage(damage)
				# Impact feedback: the same "crash" splat as a monster ramming the
				# player (take_damage already triggers the screen shake + red vignette).
				AudioManager.play_sfx_random_at("monster_death", 4, global_position.x)
				queue_free()
				return

	# Turret shots: also damage the first monster in the path (friendly fire).
	if hits_monsters:
		for m: Node in get_tree().get_nodes_in_group("monsters"):
			if not (m is Monster):
				continue
			var mon := m as Monster
			if not mon.is_targetable() or mon.hp <= 0.0:
				continue
			if global_position.distance_to(mon.global_position) <= collide_radius + mon.radius:
				mon.take_damage(damage)
				AudioManager.play_sfx_random_at("bullet_hit", 4, global_position.x, 0.6)
				queue_free()
				return

	# Lifetime / off-screen cleanup.
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if global_position.x < _despawn_min.x or global_position.x > _despawn_max.x \
	or global_position.y < _despawn_min.y or global_position.y > _despawn_max.y:
		queue_free()
