class_name Player
extends CharacterBody2D
## The controllable character. Class-configured (Ranged/Melee), auto-fires the
## class weapon at the nearest enemy, takes contact damage on a tick, and hosts
## the two shared fork abilities (Orbiting Blades, Damage Aura).

signal died

var class_id := "ranged"
var weapon_kind := "ranged"

@export var max_hp := 100.0
var hp := 100.0
var speed := 210.0
var radius := 13.0
var color := Color(0.35, 0.76, 0.96)

# Attack cadence (shared by both weapons; scaled by Quicken)
var attack_interval := 0.5
var attack_timer := 0.0

# Ranged weapon
var projectile_damage := 5.0
var projectile_speed := 520.0
var projectile_range := 950.0
var projectile_count := 1
var projectile_pierce := 0
var projectile_parent: Node

# Melee weapon
var melee_damage := 15.0
var melee_range := 132.0
var melee_arc_deg := 100.0
var melee_knockback := 0.0

# Pickups
var pickup_radius := 72.0

# Meta-progression (applied at run start)
var armor := 0.0
var recovery := 0.0

# Temporary boosts (from pickups)
var boost_dmg := 1.0
var boost_dmg_t := 0.0
var boost_rate := 1.0  # multiplies attack interval; <1 = faster
var boost_rate_t := 0.0
var boost_speed := 1.0
var boost_speed_t := 0.0
var invuln_t := 0.0

# Contact damage
var contact_tick := 0.5
var contact_timer := 0.0

# Abilities
var blades_level := 0
var _blades: Array = []
var _blade_angle := 0.0

var aura_level := 0
var aura: Area2D
var aura_shape: CircleShape2D
var aura_radius := 0.0
var aura_timer := 0.0
var _aura_enemies: Dictionary = {}

var dead := false
var _overlapping: Dictionary = {}


func _ready() -> void:
	pickup_radius = Config.PICKUP_RADIUS
	contact_tick = Config.CONTACT_TICK
	hp = max_hp
	z_index = 10
	collision_layer = 1
	collision_mask = 16  # collide with obstacles/buildings

	var hurtbox := Area2D.new()
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 2
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	hurtbox.add_child(cs)
	add_child(hurtbox)
	hurtbox.area_entered.connect(_on_hurt_area_entered)
	hurtbox.area_exited.connect(_on_hurt_area_exited)

	queue_redraw()


## Configure the player for a chosen class. Called once, pre-run. Issue #55.
func set_class(id: String) -> void:
	class_id = id
	var c: Dictionary = Config.CLASS[id]
	max_hp = c.max_hp
	hp = max_hp
	speed = c.speed
	attack_interval = c.attack_interval
	color = c.color
	weapon_kind = "melee" if id == "melee" else "ranged"

	projectile_damage = Config.PROJECTILE_DAMAGE
	projectile_speed = Config.PROJECTILE_SPEED
	projectile_range = Config.PROJECTILE_RANGE
	melee_damage = Config.MELEE_DAMAGE
	melee_range = Config.MELEE_RANGE
	melee_arc_deg = Config.MELEE_ARC_DEG
	melee_knockback = Config.MELEE_KNOCKBACK
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if dead:
		return
	velocity = _input_vector() * speed * boost_speed
	move_and_slide()


func _process(delta: float) -> void:
	if dead:
		return
	_tick_boosts(delta)
	if recovery > 0.0 and hp < max_hp:
		hp = min(max_hp, hp + recovery * delta)
	_handle_attack(delta)
	_handle_contact(delta)
	_handle_blades(delta)
	_handle_aura(delta)


# --- Input ------------------------------------------------------------------
func _input_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	var gp := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if gp.length() > 0.25:
		v = gp
	return v.limit_length(1.0)


# --- Attack dispatch (weapon abstraction, issue #52) ------------------------
func _handle_attack(delta: float) -> void:
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	var fired := _melee_attack() if weapon_kind == "melee" else _ranged_attack()
	attack_timer = attack_interval * boost_rate if fired else 0.1


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- Ranged weapon ----------------------------------------------------------
func _ranged_attack() -> bool:
	var target := _nearest_enemy()
	if target == null:
		return false
	if global_position.distance_to(target.global_position) > projectile_range:
		return false
	var base_dir := (target.global_position - global_position).normalized()
	var n := projectile_count
	var spread := deg_to_rad(Config.MULTISHOT_SPREAD_DEG)
	for i in n:
		var offset := 0.0
		if n > 1:
			offset = spread * (i - (n - 1) / 2.0)
		_spawn_projectile(base_dir.rotated(offset))
	return true


func _spawn_projectile(dir: Vector2) -> void:
	var p := Projectile.new()
	p.damage = projectile_damage * boost_dmg
	p.speed = projectile_speed
	p.life = Config.PROJECTILE_LIFE
	p.pierce = projectile_pierce
	p.direction = dir
	p.global_position = global_position
	projectile_parent.add_child(p)


# --- Melee weapon (issue #53) -----------------------------------------------
func _melee_attack() -> bool:
	var target := _nearest_enemy()
	if target == null:
		return false
	if global_position.distance_to(target.global_position) > melee_range:
		return false  # nothing in reach — wait, close the gap
	var aim := (target.global_position - global_position).normalized()
	var half := deg_to_rad(melee_arc_deg) * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() <= melee_range and absf(aim.angle_to(to_e.normalized())) <= half:
			e.take_damage(melee_damage * boost_dmg)
			if melee_knockback > 0.0:
				e.global_position += to_e.normalized() * melee_knockback
	_spawn_melee_arc(aim)
	return true


func _spawn_melee_arc(aim: Vector2) -> void:
	var arc := MeleeArc.new()
	arc.aim = aim
	arc.reach = melee_range
	arc.half_angle = deg_to_rad(melee_arc_deg) * 0.5
	arc.color = Color(color.r, color.g, color.b, 0.4)
	arc.global_position = global_position
	projectile_parent.add_child(arc)


# --- Contact damage ---------------------------------------------------------
func _handle_contact(delta: float) -> void:
	contact_timer -= delta
	if contact_timer > 0.0 or _overlapping.is_empty():
		return
	var dmg := 0.0
	for id in _overlapping:
		var e = _overlapping[id]
		if is_instance_valid(e):
			dmg = max(dmg, e.damage)
	if dmg > 0.0:
		take_damage(dmg)
		contact_timer = contact_tick


func _tick_boosts(delta: float) -> void:
	if boost_dmg_t > 0.0:
		boost_dmg_t -= delta
		if boost_dmg_t <= 0.0:
			boost_dmg = 1.0
	if boost_rate_t > 0.0:
		boost_rate_t -= delta
		if boost_rate_t <= 0.0:
			boost_rate = 1.0
	if boost_speed_t > 0.0:
		boost_speed_t -= delta
		if boost_speed_t <= 0.0:
			boost_speed = 1.0
	if invuln_t > 0.0:
		invuln_t -= delta


func add_boost(kind: String) -> void:
	match kind:
		"frenzy":
			boost_rate = 0.5
			boost_rate_t = Config.BOOST_DURATION
		"power":
			boost_dmg = 1.6
			boost_dmg_t = Config.BOOST_DURATION
		"haste":
			boost_speed = 1.4
			boost_speed_t = Config.BOOST_DURATION
		"shield":
			invuln_t = Config.SHIELD_DURATION
	modulate = Color(1.4, 1.4, 0.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)


func take_damage(amount: float) -> void:
	if dead or invuln_t > 0.0:
		return
	hp -= max(0.0, amount - armor)
	Fx.shake(Config.SHAKE_ON_HIT)
	modulate = Color(1.7, 0.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		velocity = Vector2.ZERO
		died.emit()


func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	modulate = Color(0.6, 1.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func _on_hurt_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		_overlapping[e.get_instance_id()] = e


func _on_hurt_area_exited(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		_overlapping.erase(e.get_instance_id())


# --- Ability: Orbiting Blades ----------------------------------------------
func _handle_blades(delta: float) -> void:
	if blades_level <= 0 or _blades.is_empty():
		return
	_blade_angle += delta * Config.BLADE_SPIN
	var n := _blades.size()
	for i in n:
		var ang := _blade_angle + TAU * i / n
		_blades[i].position = Vector2(cos(ang), sin(ang)) * Config.BLADE_ORBIT
	queue_redraw()


func _update_blades() -> void:
	var count := blades_level + 1  # Lv1 -> 2 blades
	while _blades.size() < count:
		var b := Area2D.new()
		b.collision_layer = 0
		b.collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 10.0
		cs.shape = sh
		b.add_child(cs)
		add_child(b)
		b.area_entered.connect(_on_blade_hit.bind(b))
		_blades.append(b)
	while _blades.size() > count:
		var b = _blades.pop_back()
		b.queue_free()
	var dmg := 5.0 + 4.0 * blades_level
	for b in _blades:
		b.set_meta("dmg", dmg)
	queue_redraw()


func _on_blade_hit(area: Area2D, blade: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		e.take_damage(blade.get_meta("dmg"))


# --- Ability: Damage Aura ---------------------------------------------------
func _handle_aura(delta: float) -> void:
	if aura_level <= 0:
		return
	aura_timer -= delta
	if aura_timer > 0.0:
		return
	aura_timer = Config.AURA_TICK
	var dmg := 3.0 + 3.0 * aura_level
	for id in _aura_enemies.keys():
		var e = _aura_enemies[id]
		if is_instance_valid(e):
			e.take_damage(dmg)
		else:
			_aura_enemies.erase(id)


func _update_aura() -> void:
	aura_radius = 58.0 + 22.0 * aura_level
	if aura == null:
		aura = Area2D.new()
		aura.collision_layer = 0
		aura.collision_mask = 2
		var cs := CollisionShape2D.new()
		aura_shape = CircleShape2D.new()
		cs.shape = aura_shape
		aura.add_child(cs)
		add_child(aura)
		aura.area_entered.connect(_on_aura_enter)
		aura.area_exited.connect(_on_aura_exit)
	aura_shape.radius = aura_radius
	queue_redraw()


func _on_aura_enter(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		_aura_enemies[e.get_instance_id()] = e


func _on_aura_exit(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		_aura_enemies.erase(e.get_instance_id())


# --- Upgrades ---------------------------------------------------------------
func apply_upgrade(id: String) -> void:
	match id:
		"dmg":
			projectile_damage *= 1.25
			melee_damage *= 1.25
		"firerate":
			attack_interval = max(0.08, attack_interval * 0.85)
		"movespeed":
			speed *= 1.10
		"pickup":
			pickup_radius *= 1.25
		"maxhp":
			max_hp += 20.0
			hp += 20.0
		"multishot":
			projectile_count += 1
		"projspeed":
			projectile_speed *= 1.20
		"pierce":
			projectile_pierce += 1
		"arc":
			melee_arc_deg = min(200.0, melee_arc_deg + 18.0)
		"cleave":
			melee_range *= 1.18
		"knockback":
			melee_knockback += 40.0
		"blades":
			blades_level += 1
			_update_blades()
		"aura":
			aura_level += 1
			_update_aura()
		"heal":
			hp = min(max_hp, hp + 30.0)


func _draw() -> void:
	if aura_level > 0:
		draw_circle(Vector2.ZERO, aura_radius, Color(0.4, 0.7, 1.0, 0.06))
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 40, Color(0.4, 0.7, 1.0, 0.28), 3.0)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 2.0)
	for b in _blades:
		draw_circle(b.position, 6.0, Color(0.85, 0.9, 1.0))
		draw_arc(b.position, 6.0, 0.0, TAU, 12, Color(0.5, 0.6, 0.8), 1.5)
