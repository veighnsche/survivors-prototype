class_name Enemy
extends CharacterBody2D
## A biome creature. Behavior comes from its archetype (brawler rush /
## skirmisher kite+shoot / brute tank), damage resistances from its biome.

signal died

var archetype := "brawler"
var biome := "commons"
var hp := 5.0
var speed := 100.0
var damage := 5.0
var radius := 10.0
var color := Color(0.86, 0.36, 0.36)
var is_boss := false
var xp_tier := "small"
var resists: Dictionary = {}

var target: Node2D
var _dead := false
var _dmg_accum := 0.0
var _dmg_cd := 0.0
var slow_mult := 1.0
var slow_t := 0.0
var vuln_mult := 1.0
var vuln_t := 0.0

# skirmisher state
var _shot_timer := 0.0
var _strafe_dir := 1.0


func apply_slow(factor: float, dur: float) -> void:
	slow_mult = min(slow_mult, factor)
	slow_t = max(slow_t, dur)


func apply_vuln(mult: float, dur: float) -> void:
	vuln_mult = max(vuln_mult, mult)
	vuln_t = max(vuln_t, dur)


func setup(arch: String, biome_id: String, tgt: Node2D, hp_scale: float) -> void:
	archetype = arch
	biome = biome_id
	var stats: Dictionary = Config.ARCHETYPES[arch]
	hp = stats.hp * hp_scale
	speed = stats.speed
	damage = stats.damage
	radius = stats.radius
	xp_tier = stats.xp
	resists = Config.BIOME_RESISTS.get(biome_id, {})
	is_boss = (arch == "boss")
	target = tgt
	var bc: Color = Config.BIOMES[biome_id].color if Config.BIOMES.has(biome_id) else Color(0.9, 0.2, 0.2)
	color = bc.darkened(0.15) if not is_boss else Color(0.92, 0.16, 0.22)
	if arch == "skirmisher":
		_shot_timer = randf_range(0.5, stats.shot_interval)
		_strafe_dir = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	add_to_group("enemies")
	z_index = 5
	collision_layer = 0
	collision_mask = 16

	var body_cs := CollisionShape2D.new()
	var body_circle := CircleShape2D.new()
	body_circle.radius = radius
	body_cs.shape = body_circle
	add_child(body_cs)

	var hitbox := Area2D.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	hitbox.add_child(cs)
	add_child(hitbox)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dmg_accum > 0.0:
		_dmg_cd -= delta
		if _dmg_cd <= 0.0:
			Fx.damage_number(global_position, _dmg_accum)
			_dmg_accum = 0.0
			_dmg_cd = 0.18
	if _dead or target == null or not is_instance_valid(target):
		return
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
	if vuln_t > 0.0:
		vuln_t -= delta
		if vuln_t <= 0.0:
			vuln_mult = 1.0

	var dir := _behavior_dir(delta)
	dir = _avoid_obstacles(dir)
	velocity = dir * speed * slow_mult
	move_and_slide()


func _behavior_dir(delta: float) -> Vector2:
	var to_p := target.global_position - global_position
	match archetype:
		"skirmisher":
			var stats: Dictionary = Config.ARCHETYPES.skirmisher
			var d := to_p.length()
			_shot_timer -= delta
			if _shot_timer <= 0.0 and d <= stats.shot_range * 1.1:
				_shot_timer = stats.shot_interval
				_fire_shot(to_p.normalized(), stats)
			if d > stats.shot_range * 0.85:
				return to_p.normalized()
			elif d < stats.shot_range * 0.45:
				return -to_p.normalized()
			else:
				return to_p.normalized().rotated(PI / 2.0) * _strafe_dir
		_:
			return to_p.normalized()  # brawler / brute / boss: beeline


func _fire_shot(dir: Vector2, stats: Dictionary) -> void:
	var s := EnemyShot.new()
	s.damage = stats.damage
	s.speed = stats.shot_speed
	s.direction = dir
	s.global_position = global_position + dir * (radius + 6.0)
	get_parent().add_child(s)


func _avoid_obstacles(dir: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * Config.ENEMY_AVOID_DIST, 16)
	var hit := space.intersect_ray(q)
	if hit:
		var n: Vector2 = hit.normal
		var slid := dir - n * dir.dot(n)
		return slid.normalized() if slid.length() > 0.05 else Vector2(-n.y, n.x)
	return dir


## Damage funnel with biome resistances + vulnerability. Returns applied damage.
func take_damage(amount: float, dtype: String = "arcane") -> float:
	if _dead:
		return 0.0
	var mult: float = float(resists.get(dtype, 1.0)) * vuln_mult
	var applied := amount * mult
	if Sim.enabled:
		Sim.damage_dealt += applied
	hp -= applied
	if Config.SHOW_DAMAGE_NUMBERS:
		_dmg_accum += applied
	if hp <= 0.0:
		_dead = true
		if _dmg_accum > 0.0:
			Fx.damage_number(global_position, _dmg_accum)
		Fx.death_pop(global_position, color)
		died.emit()
		queue_free()
		return applied
	modulate = Color(2.2, 2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)
	return applied


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.35), 2.0)
	if archetype == "brute":
		draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 14, Color(0, 0, 0, 0.3), 3.0)
	elif archetype == "skirmisher":
		draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 0.85, 0.9))
