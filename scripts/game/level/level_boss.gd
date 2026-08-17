class_name LevelBoss
extends CharacterBody2D
## FINAL BOSS "MUTANT" (level 30): a GIANT white Spawner MONSTER (25x a normal spawner's
## health) that walks after the player and births monsters of EVERY kind around itself.
## Every 15s it takes on a random MUTATION (a monster's colour + ability, fill-tint only).
## Damage table (FMJ boosts player sources 1.5x):
##   player Laser 15% - grenade blast 20% - katana swing 10% - arena lasers 7%
##   bullets chip 0.1% (1/1000) each
## It continuously spawns monsters (enrages as it loses HP) and periodically raises healing
## METINS around the arena; each destroyed metin drops a Laser item + a random powerup.
## Registers as a clear_targets goal — killing it wins the level.

const TEX := "res://assets/sprites/enemies/monster_spawner.svg"   # the white Spawner MONSTER art
const JuiceFX := preload("res://scripts/utils/juice.gd")
const RANDOM_POOL := [0, 1, 2, 3, 4, 5, 6, 7, 8]   # births EVERY monster kind (incl. tankbomber)

@export var size: float = 340.0
@export var max_hp: float = 250.0          ## 25x a normal spawner's 10 bullet-hits
@export var move_speed: float = 95.0       ## slow, unstoppable stomp toward the player
@export var enrage_speed: float = 135.0    ## below 50% HP
@export var spawn_interval: float = 4.5    ## monster wave cadence (enrages to 2.5)
@export var metin_interval: float = 15.0   ## healing-metin raise cadence
@export var metin_max: int = 2             ## max healing metins alive
@export var metin_heal_pct: float = 0.012  ## boss max-HP healed per second PER metin
@export var arena_radius: float = 1300.0   ## where metins may appear (around the boss)

var hp: float = 250.0
var _spawn_t: float = 2.5
var _metin_t: float = 4.0
var _metins: Array = []                    ## [{node, pos}]
var _sprite: Sprite2D
var _gw: Node = null
var _hud: Node = null
var _dead: bool = false
var _pulse_t: float = 0.0
var _home: Vector2 = Vector2.ZERO          ## arena centre (metins spawn around IT, not the boss)
var _heading: float = 0.0
# ---- MUTATIONS (every 15s a random monster's colour + ability; fill-tint only) ----
const MUTATIONS: Array = [MonsterTypes.Type.TANK, MonsterTypes.Type.SPEEDER,
	MonsterTypes.Type.BRUTE, MonsterTypes.Type.HEALER, MonsterTypes.Type.SPLITTER,
	MonsterTypes.Type.GHOST]
var _mutation: int = -1                    ## current mutation (-1 = pure white spawner)
var _mut_t: float = 8.0                    ## first mutation kicks in after 8s
var _mut_lunge: float = 0.0                ## BRUTE mutation: remaining lunge time
var _mut_lunge_cd: float = 3.0
var _fill_mat: ShaderMaterial = null       ## fill-only tint (keeps the black outline)
var _crate_t: float = 6.0                  ## edge lootcrate cadence

func _ready() -> void:
	z_index = 6
	add_to_group("boss")
	collision_layer = 1 | 16      # stops laser rays (7% mechanic) + blocks player & monsters
	collision_mask = 16           # collides with walls while walking
	_home = global_position
	hp = max_hp
	_gw = get_tree().get_first_node_in_group("game_world")
	if _gw and "hud" in _gw:
		_hud = _gw.hud
	_build_visual()
	_build_shape()
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm and lm.has_method("register_target"):
		lm.register_target()
	if _hud and _hud.has_method("show_boss_bar"):
		_hud.show_boss_bar(true)
		_hud.set_boss_hp(1.0)

func _physics_process(delta: float) -> void:
	if _dead or GameManager.time_stopped:
		return
	_pulse_t += delta
	if _sprite:
		_sprite.rotation = _heading + PI / 2.0   # SVG points up
		var k := 1.0 + 0.035 * sin(_pulse_t * 3.0)
		_sprite.scale = _base_scale * k
		# ghost mutation: semi-transparent phantom
		_sprite.self_modulate.a = 0.55 if _mutation == MonsterTypes.Type.GHOST else 1.0
	var enraged := hp < max_hp * 0.5
	# ---- mutation cycle (15s) + per-mutation abilities ----
	_mut_t -= delta
	if _mut_t <= 0.0:
		_mut_t = 15.0
		_cycle_mutation()
	if _mutation == MonsterTypes.Type.HEALER and hp < max_hp:
		hp = minf(hp + max_hp * 0.01 * delta, max_hp)   # healer mutation regenerates
		_update_bar()
	# ---- walk after the player (giant slow stomp) ----
	var pl := get_tree().get_first_node_in_group("players")
	if pl and not pl.is_dead:
		var spd := enrage_speed if enraged else move_speed
		if _mutation == MonsterTypes.Type.SPEEDER:
			spd *= 1.7
		elif _mutation == MonsterTypes.Type.GHOST:
			spd *= 1.25
		if _mutation == MonsterTypes.Type.BRUTE:
			_mut_lunge_cd -= delta
			if _mut_lunge <= 0.0 and _mut_lunge_cd <= 0.0:
				_mut_lunge = 0.55
				_mut_lunge_cd = 3.0
			if _mut_lunge > 0.0:
				_mut_lunge -= delta
				spd *= 2.6                                # brute mutation: charge lunge!
		var dir: Vector2 = global_position.direction_to(pl.global_position)
		_heading = lerp_angle(_heading, dir.angle(), 3.0 * delta)
		velocity = Vector2.from_angle(_heading) * spd
		if not velocity.is_finite():
			velocity = Vector2.ZERO
		if not global_position.is_finite():
			global_position = _home   # NaN-transform recovery (see monster.gd)
			velocity = Vector2.ZERO
		move_and_slide()
		# Contact = the stomp crushes the player (wide margin so pressing against it counts).
		if global_position.distance_to(pl.global_position) < size * 0.42 + pl.radius + 26.0:
			pl.take_damage(50.0)
	# ---- random edge lootcrates (powerups come only from metins + these) ----
	_crate_t -= delta
	if _crate_t <= 0.0:
		_crate_t = 12.0
		if _gw and _gw.has_method("level_spawn_lootcrate"):
			var cont = _gw.get("_lootcrate_container")
			if cont == null or cont.get_child_count() < 2:
				var ca := randf() * TAU
				_gw.level_spawn_lootcrate(_home + Vector2.from_angle(ca) * randf_range(arena_radius * 0.85, arena_radius))
	# ---- monster waves ----
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 2.5 if enraged else spawn_interval
		var wave := 3 if hp < max_hp * 0.3 else 2
		if _mutation == MonsterTypes.Type.SPLITTER:
			wave += 2                                     # splitter mutation floods the arena
		_spawn_wave(wave)
	# ---- healing metins ----
	_metin_t -= delta
	if _metin_t <= 0.0:
		_metin_t = metin_interval
		if _alive_metins() < metin_max:
			_raise_metin()
	_process_metins(delta)

func _spawn_wave(count: int) -> void:
	if _gw == null or not _gw.has_method("level_spawn_monster"):
		return
	var t: int = RANDOM_POOL.pick_random()
	var ang := randf() * TAU
	var pos := global_position + Vector2.from_angle(ang) * (size * 0.62)
	_gw.level_spawn_monster(t, pos, count, 70.0, 0.5)

func _raise_metin() -> void:
	if _gw == null:
		return
	var ang := randf() * TAU
	# Raise CLOSE to the boss (not anywhere in the arena): the summon ray, the rise and
	# the heal beam then all happen on-screen around the boss, so every metin is
	# unmistakably the Mutant's doing. Clamped inside the arena.
	var pos := global_position + Vector2.from_angle(ang) * randf_range(350.0, 600.0)
	pos = _home + (pos - _home).limit_length(arena_radius - 160.0)
	# SUMMON RAY: an orange beam + glow dot FLIES from the boss to the rise spot, so the
	# player sees the boss casting the metin. The metin rises when the dot lands.
	# (Visuals are top_level children of the boss -> global coords + auto-cleanup on death.)
	var amat := CanvasItemMaterial.new()
	amat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ray := Line2D.new()
	ray.top_level = true
	ray.width = 9.0
	ray.default_color = Color(1.0, 0.55, 0.15, 0.85)
	ray.z_index = 7
	ray.material = amat
	add_child(ray)
	ray.add_point(global_position)
	ray.add_point(global_position)
	var dot := Sprite2D.new()
	dot.top_level = true
	dot.texture = JuiceFX._spark_texture()
	dot.modulate = Color(1.0, 0.62, 0.2)
	dot.scale = Vector2(2.4, 2.4)
	dot.z_index = 8
	dot.material = amat
	add_child(dot)
	dot.global_position = global_position
	var from := global_position
	var step := func(f: float) -> void:
		if is_instance_valid(ray):
			ray.set_point_position(1, from.lerp(pos, f))
		if is_instance_valid(dot):
			dot.global_position = from.lerp(pos, f)
	var land := func() -> void:
		if is_instance_valid(dot): dot.queue_free()
		if is_instance_valid(ray): ray.queue_free()
		_spawn_metin_at(pos)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, 0.65)
	tw.tween_callback(land)

## The metin actually rises here (after the summon ray lands) + gets its HEAL BEAM visual.
func _spawn_metin_at(pos: Vector2) -> void:
	if _dead or _gw == null:
		return
	var Metin = load("res://scripts/game/level/level_metin.gd")
	var mt: StaticBody2D = Metin.new()
	mt.color = "red"
	mt.random_type = true
	mt.max_hp = 500.0
	mt.spawn_per_damage = 250.0
	mt.drop_count = 1
	mt.count_as_target = false   # healing metins are NOT win targets — only the boss is
	_gw.call_deferred("add_child", mt)
	mt.set_deferred("global_position", pos)
	# HEAL BEAM: green pulsing ray metin -> boss, shown while the metin heals it.
	var bmat := CanvasItemMaterial.new()
	bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var beam := Line2D.new()
	beam.top_level = true
	beam.width = 7.0
	beam.default_color = Color(0.3, 1.0, 0.55, 0.6)
	beam.z_index = 5
	beam.material = bmat
	add_child(beam)
	beam.add_point(pos)
	beam.add_point(global_position)
	_metins.append({"node": mt, "pos": pos, "beam": beam})

func _alive_metins() -> int:
	var n := 0
	for e in _metins:
		if is_instance_valid(e["node"]):
			n += 1
	return n

## Metins heal the boss while alive; a destroyed one drops a LASER item + a random powerup.
func _process_metins(delta: float) -> void:
	var i := _metins.size() - 1
	while i >= 0:
		var e: Dictionary = _metins[i]
		if is_instance_valid(e["node"]):
			e["pos"] = (e["node"] as Node2D).global_position
			var beam: Line2D = e.get("beam")
			if beam and is_instance_valid(beam):
				beam.set_point_position(0, e["pos"])
				beam.set_point_position(1, global_position)
				beam.default_color.a = 0.4 + 0.3 * sin(_pulse_t * 6.0)
				beam.width = 6.0 + 2.0 * sin(_pulse_t * 6.0)
			if hp < max_hp:
				hp = minf(hp + max_hp * metin_heal_pct * delta, max_hp)
				_update_bar()
		else:
			var dbeam: Line2D = e.get("beam")
			if dbeam and is_instance_valid(dbeam):
				dbeam.queue_free()
			if _gw:
				if _gw.has_method("level_spawn_item"):
					_gw.level_spawn_item(3, e["pos"])              # guaranteed LASER item
				if _gw.has_method("level_spawn_powerup"):
					_gw.level_spawn_powerup([2, 3, 4, 5, 6].pick_random(), e["pos"])  # random powerup
			_metins.remove_at(i)
		i -= 1

# ---- MUTATIONS ----
func _cycle_mutation() -> void:
	var pool := MUTATIONS.filter(func(t): return int(t) != _mutation)
	_mutation = int(pool.pick_random())
	_set_fill_tint(MonsterTypes.get_color(_mutation))
	# announce with a quick scale punch
	if _sprite:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", _base_scale * 1.22, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_sprite, "scale", _base_scale, 0.18)
	AudioManager.play_sfx("powerup_pickup")

func _mut_color() -> Color:
	return MonsterTypes.get_color(_mutation) if _mutation >= 0 else Color.WHITE

## Fill-only tint (the SVG's black outline stays black) — same trick as hybrid monsters.
func _set_fill_tint(col: Color) -> void:
	if _fill_mat:
		_fill_mat.set_shader_parameter("tint", col)

# ---- damage table ----
func hit_by_bullet(_b: Node) -> void:
	_damage(max_hp * 0.001, false)   # bullets chip 1/1000 (no big flash/shake)

func player_laser_hit(mult: float = 1.0) -> void:
	_damage(max_hp * 0.15 * mult)

func enemy_laser_hit() -> void:
	_damage(max_hp * 0.07)

func grenade_hit(mult: float = 1.0) -> void:
	_damage(max_hp * 0.20 * mult)

func katana_hit() -> void:
	_damage(max_hp * 0.10)

func _damage(a: float, juice: bool = true) -> void:
	if _dead:
		return
	if _mutation == MonsterTypes.Type.TANK:
		a *= 0.5                                   # tank mutation halves ALL damage
	hp -= a
	_update_bar()
	if juice:
		_flash_red()
		if _gw and _gw.has_method("_add_shake"):
			_gw.call("_add_shake", 7.0)
		GameManager.vibrate(25)
	if hp <= 0.0:
		_die()

## Red hit-flash driven through the fill shader (modulate rgb is ignored by it).
func _flash_red() -> void:
	if _fill_mat == null:
		return
	# Interpolate toward the LIVE mutation colour (a mutation switch mid-flash must win).
	var setter := func(f: float) -> void:
		if _fill_mat:
			_fill_mat.set_shader_parameter("tint", Color(2.0, 0.35, 0.35).lerp(_mut_color(), f))
	var tw := create_tween()
	tw.tween_method(setter, 0.0, 1.0, 0.22)

func _update_bar() -> void:
	if _hud and _hud.has_method("set_boss_hp"):
		_hud.set_boss_hp(clampf(hp / max_hp, 0.0, 1.0))

func _die() -> void:
	if _dead:
		return
	_dead = true
	if _hud and _hud.has_method("show_boss_bar"):
		_hud.show_boss_bar(false)
	# Report the kill FIRST — the win flow makes the player invulnerable, so the
	# celebratory blast below can't kill them (a death here would schedule a respawn
	# that reloads the level underneath the result screen).
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm and lm.has_method("target_destroyed"):
		lm.target_destroyed()
	# Big finish: blast + splat (pure celebration — the player is already safe).
	var fp := get_tree().get_first_node_in_group("floor_paint")
	if fp and fp.has_method("add_splat"):
		fp.add_splat(global_position, Color(0.9, 0.2, 0.2), 5.0)
	if _gw and _gw.has_method("explode_at"):
		_gw.explode_at(global_position, 2.0)
	if _gw and "particles" in _gw and _gw.particles:
		_gw.particles.spawn_death_particles(global_position, Color(1.0, 0.4, 0.2), 60)
	AudioManager.play_sfx("grenade_explosion")
	queue_free()

var _base_scale: Vector2 = Vector2.ONE

func _build_visual() -> void:
	if not ResourceLoader.exists(TEX):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	var t: Vector2 = _sprite.texture.get_size()
	var sf := size / maxf(t.x, t.y)
	_sprite.scale = Vector2(sf, sf)
	# Fill-only tint shader: recolours the body, keeps the black outline (like hybrids).
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV);\n\tfloat bright = max(max(t.r, t.g), t.b);\n\tfloat fill = smoothstep(0.18, 0.45, bright);\n\tvec3 rgb = mix(t.rgb, tint.rgb, fill);\n\tCOLOR = vec4(rgb, t.a * COLOR.a);\n}\n"
	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = sh
	_fill_mat.set_shader_parameter("tint", Color.WHITE)
	_sprite.material = _fill_mat
	_base_scale = _sprite.scale
	add_child(_sprite)

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size * 0.42
	cs.shape = c
	add_child(cs)
