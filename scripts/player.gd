class_name Player
extends CharacterBody2D
## The controllable character. Holds ONE active weapon (starts with Fists); swap
## by pressing E over a dropped weapon, long-press E to drop back to Fists. Each
## weapon has its own upgradable stats. Also hosts the shared fork abilities.

signal died

@export var max_hp := 100.0
var hp := 100.0
var speed := 210.0
var radius := 13.0
var color := Color(0.85, 0.80, 0.62)

# --- Weapons ---
var weapon_kind := "fists"
var weapon_stats: Dictionary = {}   # per-weapon upgradable stats (copied from Config)
var damage_mult := 1.0              # global (meta Might)
var attack_speed_mult := 1.0        # global (Quicken / meta Cooldown); <1 = faster
var fists_lifesteal := 0.0
var attack_timer := 0.0
var projectile_parent: Node
var arena  # the run director, for spawning dropped weapons

# E-swap input state
var _e_held := 0.0
var _e_long := false

# Pickups
var pickup_radius := 72.0

# Meta-progression
var armor := 0.0
var recovery := 0.0

# Temporary boosts
var boost_dmg := 1.0
var boost_dmg_t := 0.0
var boost_rate := 1.0
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
	collision_mask = 16  # collide with buildings

	weapon_stats = {}
	for k in Config.WEAPONS:
		weapon_stats[k] = Config.WEAPONS[k].duplicate(true)
	set_weapon("fists")

	var body_cs := CollisionShape2D.new()
	var body_circle := CircleShape2D.new()
	body_circle.radius = radius
	body_cs.shape = body_circle
	add_child(body_cs)

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


func set_weapon(kind: String) -> void:
	weapon_kind = kind
	color = weapon_stats[kind].color
	queue_redraw()


func weapon_name() -> String:
	return weapon_stats[weapon_kind].name


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
	_handle_weapon_input(delta)
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


# --- Weapon swap (E tap) / drop-to-fists (E long press) ---------------------
func _handle_weapon_input(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_E):
		_e_held += delta
		if _e_held >= Config.WEAPON_LONG_PRESS and not _e_long:
			_e_long = true
			_drop_to_fists()
	else:
		if _e_held > 0.0 and not _e_long:
			_try_swap()  # was a short tap
		_e_held = 0.0
		_e_long = false


func _try_swap() -> void:
	var wp = _nearest_weapon_pickup()
	if wp == null:
		return
	var new_kind: String = wp.weapon_kind
	var pos: Vector2 = wp.global_position
	wp.consume()
	if weapon_kind != "fists" and arena != null:
		arena.spawn_weapon_pickup(pos, weapon_kind)  # leave your old weapon behind
	set_weapon(new_kind)


func _drop_to_fists() -> void:
	if weapon_kind == "fists":
		return
	if arena != null:
		arena.spawn_weapon_pickup(global_position, weapon_kind)
	set_weapon("fists")


func _nearest_weapon_pickup():
	var best = null
	var best_d := Config.WEAPON_PICKUP_RADIUS * Config.WEAPON_PICKUP_RADIUS
	for w in get_tree().get_nodes_in_group("weapon_drops"):
		var d: float = global_position.distance_squared_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best


# --- Attack dispatch --------------------------------------------------------
func _dmg(base: float) -> float:
	return base * damage_mult * boost_dmg


func _handle_attack(delta: float) -> void:
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	var fired := _weapon_attack()
	var ws: Dictionary = weapon_stats[weapon_kind]
	attack_timer = (ws.interval * attack_speed_mult * boost_rate) if fired else 0.1


func _weapon_attack() -> bool:
	match weapon_kind:
		"fists":
			return _fists_attack()
		"melee":
			return _melee_attack()
		"chain":
			return _chain_attack()
		_:
			return _ranged_attack()


func _nearest_enemy_in(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach * reach
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _nearest_enemy_excluding(from: Vector2, reach: float, exclude: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_d := reach * reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if exclude.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _enemies_in_range(reach: float, n: int) -> Array:
	var arr: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d <= reach:
			arr.append({"e": e, "d": d})
	arr.sort_custom(func(a, b): return a.d < b.d)
	var out: Array = []
	for i in min(n, arr.size()):
		out.append(arr[i].e)
	return out


# --- Fists: single/few nearest targets, short range -------------------------
func _fists_attack() -> bool:
	var ws: Dictionary = weapon_stats["fists"]
	var targets := _enemies_in_range(ws.range, int(ws.targets))
	if targets.is_empty():
		return false
	for e in targets:
		e.take_damage(_dmg(ws.damage))
		Fx.death_pop(e.global_position, Color(1, 1, 1))
	if fists_lifesteal > 0.0:
		heal(fists_lifesteal)
	return true


# --- Ranged: projectiles at nearest --------------------------------------
func _ranged_attack() -> bool:
	var ws: Dictionary = weapon_stats["ranged"]
	var target := _nearest_enemy_in(ws.range)
	if target == null:
		return false
	var base_dir := (target.global_position - global_position).normalized()
	var count := int(ws.count)
	var spread := deg_to_rad(Config.MULTISHOT_SPREAD_DEG)
	for i in count:
		var offset := 0.0
		if count > 1:
			offset = spread * (i - (count - 1) / 2.0)
		_spawn_projectile(base_dir.rotated(offset), ws)
	return true


func _spawn_projectile(dir: Vector2, ws: Dictionary) -> void:
	var p := Projectile.new()
	p.damage = _dmg(ws.damage)
	p.speed = ws.speed
	p.life = Config.PROJECTILE_LIFE
	p.pierce = int(ws.pierce)
	p.direction = dir
	p.global_position = global_position
	projectile_parent.add_child(p)


# --- Melee: cone cleave at nearest ------------------------------------------
func _melee_attack() -> bool:
	var ws: Dictionary = weapon_stats["melee"]
	var target := _nearest_enemy_in(ws.range)
	if target == null:
		return false
	var aim := (target.global_position - global_position).normalized()
	var half := deg_to_rad(ws.arc) * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() <= ws.range and absf(aim.angle_to(to_e.normalized())) <= half:
			e.take_damage(_dmg(ws.damage))
			if ws.knockback > 0.0:
				e.global_position += to_e.normalized() * ws.knockback
	_spawn_melee_arc(aim, ws.range, ws.arc)
	return true


func _spawn_melee_arc(aim: Vector2, reach: float, arc_deg: float) -> void:
	var arc := MeleeArc.new()
	arc.aim = aim
	arc.reach = reach
	arc.half_angle = deg_to_rad(arc_deg) * 0.5
	arc.color = Color(color.r, color.g, color.b, 0.4)
	arc.global_position = global_position
	projectile_parent.add_child(arc)


# --- Chain Lightning: zap nearest, arc to nearby ----------------------------
func _chain_attack() -> bool:
	var ws: Dictionary = weapon_stats["chain"]
	var current := _nearest_enemy_in(ws.range)
	if current == null:
		return false
	var pts := PackedVector2Array([global_position])
	var already: Dictionary = {}
	for j in int(ws.jumps) + 1:
		if current == null:
			break
		already[current.get_instance_id()] = true
		current.take_damage(_dmg(ws.damage))
		pts.append(current.global_position)
		current = _nearest_enemy_excluding(current.global_position, ws.jump_range, already)
	_spawn_chain_bolt(pts)
	return true


func _spawn_chain_bolt(pts: PackedVector2Array) -> void:
	var bolt := ChainBolt.new()
	bolt.points = pts
	bolt.color = Color(color.r, color.g, color.b, 0.95)
	projectile_parent.add_child(bolt)


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


func active_boosts() -> Array:
	var out: Array = []
	if boost_dmg_t > 0.0:
		out.append({"name": "Power",  "secs": boost_dmg_t,   "frac": boost_dmg_t / Config.BOOST_DURATION,   "color": Color(0.8, 0.42, 0.95)})
	if boost_rate_t > 0.0:
		out.append({"name": "Frenzy", "secs": boost_rate_t,  "frac": boost_rate_t / Config.BOOST_DURATION,  "color": Color(0.95, 0.4, 0.32)})
	if boost_speed_t > 0.0:
		out.append({"name": "Haste",  "secs": boost_speed_t, "frac": boost_speed_t / Config.BOOST_DURATION, "color": Color(0.3, 0.9, 0.95)})
	if invuln_t > 0.0:
		out.append({"name": "Shield", "secs": invuln_t,      "frac": invuln_t / Config.SHIELD_DURATION,     "color": Color(0.92, 0.9, 0.5)})
	return out


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


# --- Temporary boosts -------------------------------------------------------
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
	var count := blades_level + 1
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
		"movespeed":
			speed *= 1.10
		"pickup":
			pickup_radius *= 1.25
		"maxhp":
			max_hp += 20.0
			hp += 20.0
		"quicken":
			attack_speed_mult *= 0.88
		"blades":
			blades_level += 1
			_update_blades()
		"aura":
			aura_level += 1
			_update_aura()
		"fists_dmg":
			weapon_stats.fists.damage *= 1.30
		"fists_speed":
			weapon_stats.fists.interval = max(0.08, weapon_stats.fists.interval * 0.85)
		"fists_lifesteal":
			fists_lifesteal += 1.5
		"fists_flurry":
			weapon_stats.fists.targets += 1
		"fists_focus":
			weapon_stats.fists.damage *= 1.60
		"r_dmg":
			weapon_stats.ranged.damage *= 1.25
		"r_multishot":
			weapon_stats.ranged.count += 1
		"r_pierce":
			weapon_stats.ranged.pierce += 1
		"r_speed":
			weapon_stats.ranged.speed *= 1.20
		"m_dmg":
			weapon_stats.melee.damage *= 1.25
		"m_arc":
			weapon_stats.melee.arc = min(200.0, weapon_stats.melee.arc + 18.0)
		"m_cleave":
			weapon_stats.melee.range *= 1.18
		"m_knockback":
			weapon_stats.melee.knockback += 40.0
		"c_dmg":
			weapon_stats.chain.damage *= 1.25
		"c_jumps":
			weapon_stats.chain.jumps += 1
		"c_reach":
			weapon_stats.chain.range *= 1.25
		"c_jumprange":
			weapon_stats.chain.jump_range *= 1.20
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
