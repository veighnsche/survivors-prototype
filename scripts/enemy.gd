class_name Enemy
extends CharacterBody2D
## A biome creature. Behavior comes from its archetype (brawler rush /
## skirmisher kite+shoot / brute tank), damage resistances from its biome.

signal died

var archetype := "brawler"
var behavior := "beeline"
var stats: Dictionary = {}
var biome := "commons"
var hp := 5.0
var speed := 100.0
var damage := 5.0
var radius := 10.0
var color := Color(0.86, 0.36, 0.36)
var is_boss := false
var guard := false   # entrance guard: holds its post, engages only up close
var xp_tier := "small"
var resists: Dictionary = {}

var target: Node2D
var biome_map: BiomeMap  # for territory checks
var home_pos := Vector2.ZERO  # where it spawned (inside its home biome)
var _outside := false     # currently outside its home biome → weakened, heads home
var _outside_t := 0.0     # how long it has been astray (fades away eventually)
var _territory_timer := 0.0
var _dead := false
var _dmg_accum := 0.0
var _dmg_cd := 0.0
var slow_mult := 1.0
var slow_t := 0.0
var haste_mult := 1.0   # Howler war-cries speed the pack up
var haste_t := 0.0
var vuln_mult := 1.0
var vuln_t := 0.0
var feared_t := 0.0

# Generic behavior state (lunger windups, diver dives, burrower phases...)
var _bstate := ""
var _btimer := 0.0
var _lock_dir := Vector2.ZERO
var _lock_pos := Vector2.ZERO
var _buff_timer := 0.0
var _embold := false    # Husk: emboldened by nearby packmates
var _sprint := false    # Mite: frenzy sprint when close
var _revived := false   # Grave-swarm: reassembles once
var _pack_timer := 0.0

# skirmisher state
var _shot_timer := 0.0
var _strafe_dir := 1.0

# Warden state machine: walk -> telegraph -> execute, on a cadence.
var _wstate := "walk"        # walk | tele_charge | charging | tele_slam | summoning
var _wtimer := 0.0
var _watk_cd := 4.0
var _charge_dir := Vector2.ZERO
var _charge_hit := false


func apply_slow(factor: float, dur: float) -> void:
	slow_mult = min(slow_mult, factor)
	slow_t = max(slow_t, dur)


func apply_vuln(mult: float, dur: float) -> void:
	vuln_mult = max(vuln_mult, mult)
	vuln_t = max(vuln_t, dur)


func apply_fear(dur: float) -> void:
	feared_t = max(feared_t, dur)


func apply_haste(mult: float, dur: float) -> void:
	haste_mult = max(haste_mult, mult)
	haste_t = max(haste_t, dur)


## Contact/shot damage right now — softer when fighting away from home turf.
## Phased states (underground, airborne, a bone pile) can't touch you at all.
func eff_damage() -> float:
	if _bstate == "burrowed" or _bstate == "ascend" or _bstate == "bones":
		return 0.0
	return damage * (Config.OUT_OF_BIOME_DMG if _outside else 1.0)


func setup(arch: String, biome_id: String, tgt: Node2D, hp_scale: float) -> void:
	archetype = arch
	biome = biome_id
	stats = Config.ARCHETYPES[arch]
	behavior = stats.get("behavior", "beeline")
	hp = stats.hp * hp_scale
	speed = stats.speed
	damage = stats.damage
	radius = stats.radius
	xp_tier = stats.xp
	resists = Config.BIOME_RESISTS.get(biome_id, {})
	is_boss = (arch == "boss")
	target = tgt
	var bc: Color = Config.BIOMES[biome_id].color if Config.BIOMES.has(biome_id) else Color(0.9, 0.2, 0.2)
	color = bc.darkened(0.15) if not is_boss else bc.lightened(0.15)  # the Warden wears its biome's color
	if stats.has("shot_interval"):
		_shot_timer = randf_range(0.5, stats.shot_interval)
		_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	if behavior == "flyer" or behavior == "diver":
		collision_mask = 0  # flyers soar over buildings


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

	# Territory: sample which biome we're in every so often (boss roams freely).
	if not is_boss and biome_map != null:
		_territory_timer -= delta
		if _territory_timer <= 0.0:
			_territory_timer = 0.4
			_outside = biome_map.biome_at(global_position) != biome
		if _outside:
			_outside_t += delta
			if _outside_t >= Config.OUT_OF_BIOME_DESPAWN:
				queue_free()  # faded away — no death, no reward
				return
		else:
			_outside_t = 0.0

	if feared_t > 0.0:
		feared_t -= delta

	if haste_t > 0.0:
		haste_t -= delta
		if haste_t <= 0.0:
			haste_mult = 1.0

	# Defensive-state ticks (these states park the body, so tick them here).
	if _bstate == "harden":
		_btimer -= delta
		if _btimer <= 0.0:
			_bstate = ""
			queue_redraw()
	elif _bstate == "bones":
		_btimer -= delta
		velocity = Vector2.ZERO
		if _btimer <= 0.0:
			_bstate = ""
			hp = stats.hp * 0.4
			modulate = Color.WHITE
			queue_redraw()
		return  # an inert pile: no behavior, no movement

	if is_boss:
		_warden_brain(delta)
		return

	var dir := _behavior_dir(delta)
	if behavior != "flyer" and behavior != "diver":
		dir = _avoid_obstacles(dir)
	velocity = dir * speed * slow_mult * haste_mult * _state_speed()
	move_and_slide()


func _state_speed() -> float:
	match _bstate:
		"windup", "surfacing", "harden", "bones", "ascend":
			return 0.0
		"dashing":
			return float(stats.get("dash_mult", 3.0))
		"diving":
			return float(stats.get("dive_mult", 3.0))
		"dart":
			return 2.2   # prowler's pounce out of its circle
		"crash":
			return 3.4   # roc dropping out of the sky
		"burrowed":
			return 1.9   # closing fast underground
	var m := 1.0
	if _embold:
		m *= 1.22
	if _sprint:
		m *= 1.6
	return m


# --- The Warden: telegraphed moves, not a walking stat blob -------------------
func _warden_brain(delta: float) -> void:
	var to_p := target.global_position - global_position
	_wtimer -= delta
	match _wstate:
		"walk":
			velocity = to_p.normalized() * speed * slow_mult
			move_and_slide()
			_watk_cd -= delta
			if _watk_cd <= 0.0:
				_watk_cd = Config.WARDEN_ATTACK_EVERY
				var roll := randf()
				if roll < 0.4 and to_p.length() > 180.0:
					_wstate = "tele_charge"
					_wtimer = 0.8
				elif roll < 0.75 and to_p.length() < 320.0:
					_wstate = "tele_slam"
					_wtimer = 1.0
				else:
					_wstate = "summoning"
					_wtimer = 0.9
				queue_redraw()
		"tele_charge":
			velocity = Vector2.ZERO  # plant, aim, glow
			_charge_dir = to_p.normalized()
			if _wtimer <= 0.0:
				_wstate = "charging"
				_wtimer = 0.7
				_charge_hit = false
			queue_redraw()
		"charging":
			velocity = _charge_dir * speed * Config.WARDEN_CHARGE_SPEED
			move_and_slide()
			if not _charge_hit and to_p.length() < radius + 20.0:
				_charge_hit = true
				target.take_damage(damage * 1.2, "Warden (charge)")
			if _wtimer <= 0.0:
				_wstate = "walk"
				queue_redraw()
		"tele_slam":
			velocity = Vector2.ZERO
			if _wtimer <= 0.0:
				if to_p.length() <= Config.WARDEN_SLAM_RADIUS:
					target.take_damage(damage, "Warden (slam)")
				var ring := RingFx.new()
				ring.max_radius = Config.WARDEN_SLAM_RADIUS
				ring.color = color
				ring.global_position = global_position
				get_parent().add_child(ring)
				Fx.shake(0.5)
				_wstate = "walk"
			queue_redraw()
		"summoning":
			velocity = Vector2.ZERO
			if _wtimer <= 0.0:
				var game = get_parent().get_parent()
				if game != null and game.has_method("spawn_minion"):
					var roster: Array = Config.BIOMES[biome].roster
					for i in 4:
						var off := Vector2(randf_range(-70, 70), randf_range(-70, 70))
						game.spawn_minion(roster[0].arch, biome, global_position + off)
				_wstate = "walk"
				queue_redraw()


func _behavior_dir(delta: float) -> Vector2:
	var to_p := target.global_position - global_position
	if feared_t > 0.0:
		return -to_p.normalized()  # Dread: flee
	# Entrance guards hold their post; they only engage up close.
	if guard and to_p.length() > Config.GUARD_AGGRO:
		if global_position.distance_to(home_pos) > 40.0:
			return (home_pos - global_position).normalized()
		return Vector2.ZERO
	# Outside home turf: disengage and head home (unless the player is right on
	# top of us — then fight back). Prevents dragging enemies out to farm them.
	if _outside and to_p.length() > Config.SELF_DEFENSE_RADIUS:
		return (home_pos - global_position).normalized()
	match behavior:
		"kite":  # skirmisher: shoot and keep distance — and LEAD the target
			var d := to_p.length()
			_shot_timer -= delta
			if _shot_timer <= 0.0 and d <= stats.shot_range * 1.1:
				_shot_timer = stats.shot_interval
				var lead: Vector2 = to_p + target.velocity * (d / float(stats.shot_speed)) * 0.8
				_fire_shot(lead.normalized())
			if d > stats.shot_range * 0.85:
				return to_p.normalized()
			elif d < stats.shot_range * 0.45:
				return -to_p.normalized()
			else:
				return to_p.normalized().rotated(PI / 2.0) * _strafe_dir
		"advance_shoot":  # bramble: shoot while lumbering forward
			_shot_timer -= delta
			if _shot_timer <= 0.0 and to_p.length() <= stats.shot_range:
				_shot_timer = stats.shot_interval
				_fire_shot(to_p.normalized())
			return to_p.normalized()
		"darter":  # stray: hit-and-run — bite, then break away, come again
			_btimer -= delta
			if _bstate == "fleeing":
				if _btimer <= 0.0:
					_bstate = ""
				return (-to_p).normalized().rotated(sin(Time.get_ticks_msec() * 0.004) * 0.3)
			if to_p.length() < 46.0:
				_bstate = "fleeing"
				_btimer = 1.1
			return to_p.normalized().rotated(sin(Time.get_ticks_msec() * 0.006 + float(get_instance_id() % 100)) * 0.4)
		"prowl":  # prowler: circle the prey, then pounce from the flank
			_btimer -= delta
			match _bstate:
				"circle":
					if _btimer <= 0.0:
						_bstate = "dart"
						_btimer = 0.5
						_lock_dir = to_p.normalized()
					return to_p.normalized().rotated(PI / 2.0) * _strafe_dir
				"dart":
					if _btimer <= 0.0:
						_bstate = "cooldown"
						_btimer = 0.8
					return _lock_dir
				"cooldown":
					if _btimer <= 0.0:
						_bstate = ""
					return to_p.normalized()
				_:
					if to_p.length() < 180.0:
						_bstate = "circle"
						_btimer = 0.9
					return to_p.normalized()
		"roc_dive":  # roc: climbs out of reach, shadows you, crashes down
			_btimer -= delta
			match _bstate:
				"ascend":
					modulate.a = 0.35
					if _btimer <= 0.0:
						_bstate = "crash"
						_lock_pos = target.global_position
						queue_redraw()
					return Vector2.ZERO
				"crash":
					var to_l := _lock_pos - global_position
					if to_l.length() < 24.0:
						modulate.a = 1.0
						if to_p.length() < 90.0:
							target.take_damage(damage * 1.5, "Roc (dive)")
						Fx.shake(0.2)
						_bstate = "fly"
						_btimer = float(stats.dive_every)
						queue_redraw()
						return Vector2.ZERO
					return to_l.normalized()
				_:
					modulate.a = 1.0
					if _btimer <= 0.0 and to_p.length() < 480.0:
						_bstate = "ascend"
						_btimer = 0.9
						queue_redraw()
					return to_p.normalized()
		"turret":  # volleyer: roots and fires 3-shot bursts when in range
			if to_p.length() <= stats.shot_range:
				_shot_timer -= delta
				if _shot_timer <= 0.0:
					_shot_timer = stats.shot_interval
					var aim := to_p.normalized()
					for i in int(stats.burst):
						_fire_shot(aim.rotated(deg_to_rad(-12.0 + 12.0 * i)))
				return Vector2.ZERO
			return to_p.normalized()
		"lunger":  # pouncer: stalk -> plant -> leap
			_btimer -= delta
			match _bstate:
				"windup":
					_lock_dir = to_p.normalized()
					if _btimer <= 0.0:
						_bstate = "dashing"
						_btimer = float(stats.dash_time)
					queue_redraw()
					return Vector2.ZERO
				"dashing":
					if _btimer <= 0.0:
						_bstate = "recover"
						_btimer = 1.4
						queue_redraw()
					return _lock_dir
				"recover":
					if _btimer <= 0.0:
						_bstate = ""
					return to_p.normalized()
				_:
					if to_p.length() <= float(stats.lunge_range):
						_bstate = "windup"
						_btimer = float(stats.windup)
						queue_redraw()
					return to_p.normalized()
		"diver":  # circles out of reach, then locks and dives THROUGH you
			_btimer -= delta
			match _bstate:
				"diving":
					if _btimer <= 0.0:
						_bstate = ""
						_btimer = float(stats.dive_every)
						queue_redraw()
					return _lock_dir
				_:
					if _btimer <= 0.0 and to_p.length() < 520.0:
						_bstate = "diving"
						_btimer = float(stats.dive_time)
						_lock_dir = to_p.normalized()
						queue_redraw()
						return _lock_dir
					if to_p.length() > 340.0:
						return to_p.normalized()
					return to_p.normalized().rotated(PI / 2.0) * _strafe_dir
		"burrower":  # dives under, races close, erupts
			_btimer -= delta
			match _bstate:
				"burrowed":
					if _btimer <= 0.0 or to_p.length() < 70.0:
						_bstate = "surfacing"
						_btimer = 0.5
						queue_redraw()
					return to_p.normalized()
				"surfacing":
					if _btimer <= 0.0:
						_bstate = "surface"
						_btimer = float(stats.surface_time)
						queue_redraw()
					return Vector2.ZERO
				"surface":
					if _btimer <= 0.0:
						_bstate = "burrowed"
						_btimer = float(stats.burrow_time)
						queue_redraw()
					return to_p.normalized()
				_:
					_bstate = "burrowed"
					_btimer = float(stats.burrow_time)
					return to_p.normalized()
		"pack_buffer":  # howler: runs with the pack and speeds it up
			_buff_timer -= delta
			if _buff_timer <= 0.0:
				_buff_timer = 2.5
				for e in get_tree().get_nodes_in_group("enemies"):
					if e != self and global_position.distance_to(e.global_position) <= float(stats.buff_radius):
						e.apply_haste(1.35, 2.5)
				var ring := RingFx.new()
				ring.max_radius = float(stats.buff_radius)
				ring.color = Color(color.r, color.g, color.b, 0.5)
				ring.global_position = global_position
				get_parent().add_child(ring)
			return to_p.normalized()
		"flyer":  # gale: circles in, peppering light shots on the wing
			if stats.has("shot_interval"):
				_shot_timer -= delta
				if _shot_timer <= 0.0 and to_p.length() <= stats.shot_range:
					_shot_timer = stats.shot_interval
					_fire_shot(to_p.normalized())
			return to_p.normalized()
		_:
			# per-archetype instincts on the shared beeline
			match archetype:
				"brawler":  # husks embolden in packs — thin them or they run you down
					_pack_timer -= delta
					if _pack_timer <= 0.0:
						_pack_timer = 0.5
						var packmates := 0
						for e in get_tree().get_nodes_in_group("enemies"):
							if e != self and e.archetype == "brawler" and global_position.distance_to(e.global_position) < 150.0:
								packmates += 1
								if packmates >= 2:
									break
						_embold = packmates >= 2
						queue_redraw()
				"stalker":  # fades to a shimmer at range; reveals up close
					modulate.a = clampf(1.0 - (to_p.length() - 150.0) / 180.0, 0.16, 1.0)
				"mite":  # frenzy sprint for the last stretch
					_sprint = to_p.length() < 160.0
				"broodmother":  # lays a mite every few seconds while alive
					_buff_timer -= delta
					if _buff_timer <= 0.0:
						_buff_timer = 6.0
						var g = get_parent().get_parent()
						if g != null and g.has_method("spawn_minion"):
							g.spawn_minion("mite", biome, global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
			return to_p.normalized()  # brute / shambler / bonepile / boss


func _fire_shot(dir: Vector2) -> void:
	var s := EnemyShot.new()
	s.damage = eff_damage()
	s.src = str(stats.get("name", archetype))
	s.speed = stats.shot_speed
	s.direction = dir
	s.global_position = global_position + dir * (radius + 6.0)
	get_parent().add_child(s)


var _avoid_cached := Vector2.ZERO
func _avoid_obstacles(dir: Vector2) -> Vector2:
	# Raycast every 3rd tick per enemy (staggered) — same behavior, a third the
	# physics cost, which raises the sim's faithful-speed ceiling.
	if (Engine.get_physics_frames() + get_instance_id()) % 3 != 0:
		return _avoid_cached if _avoid_cached != Vector2.ZERO else dir
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * Config.ENEMY_AVOID_DIST, 16)
	var hit := space.intersect_ray(q)
	if hit:
		var n: Vector2 = hit.normal
		var slid := dir - n * dir.dot(n)
		_avoid_cached = slid.normalized() if slid.length() > 0.05 else Vector2(-n.y, n.x)
	else:
		_avoid_cached = Vector2.ZERO
		return dir
	return _avoid_cached


## The full multiplier an incoming hit of this type would get right now
## (resistance x vulnerability x out-of-biome weakness) — used by the caster
## brain to predict damage before committing to a spell.
func damage_mult_for(dtype: String) -> float:
	var mult: float = float(resists.get(dtype, 1.0)) * vuln_mult
	if _outside:
		mult *= Config.OUT_OF_BIOME_VULN
	return mult


## Damage funnel with biome resistances + vulnerability. Returns applied damage.
func take_damage(amount: float, dtype: String = "arcane") -> float:
	if _dead:
		return 0.0
	if _bstate == "burrowed":
		return 0.0  # untouchable underground — hit it when it surfaces
	if _bstate == "ascend" or _bstate == "crash":
		return 0.0  # the Roc is out of reach in the sky
	# Bramble: hardens after being struck — 50% reduction while curled up.
	if archetype == "bramble" and _bstate == "harden":
		amount *= 0.5
	# Barrow-Knight: raised shield blocks half of all RANGED damage; get close.
	if archetype == "brute" and target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > 140.0:
			amount *= 0.5
	var applied := amount * damage_mult_for(dtype)
	if Sim.enabled:
		Sim.damage_dealt += applied
	# Grave-swarm: the first "death" only collapses it to bones — it reassembles
	# in 2.5s at partial hp. Stomp the pile (any hit) to keep it down for good.
	if archetype == "shambler" and not _revived and _bstate != "bones" and hp - applied <= 0.0:
		_revived = true
		_bstate = "bones"
		_btimer = 2.5
		hp = 0.01
		modulate = Color(0.55, 0.55, 0.55)
		queue_redraw()
		return applied
	# Bramble curls up after any hit.
	if archetype == "bramble" and _bstate != "harden":
		_bstate = "harden"
		_btimer = 1.5
		queue_redraw()
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
	# Warden telegraphs: read the move BEFORE it lands.
	if is_boss:
		match _wstate:
			"tele_charge":
				if target != null and is_instance_valid(target):
					var aim := (target.global_position - global_position).normalized()
					draw_line(Vector2.ZERO, aim * 420.0, Color(1, 0.3, 0.2, 0.55), 7.0)
				draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 24, Color(1, 0.3, 0.2, 0.9), 4.0)
			"charging":
				draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 24, Color(1, 0.5, 0.2, 0.9), 4.0)
			"tele_slam":
				draw_circle(Vector2.ZERO, Config.WARDEN_SLAM_RADIUS, Color(1, 0.25, 0.2, 0.10))
				draw_arc(Vector2.ZERO, Config.WARDEN_SLAM_RADIUS, 0.0, TAU, 48, Color(1, 0.3, 0.2, 0.8), 3.0)
			"summoning":
				draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 24, Color(0.8, 0.5, 1.0, 0.8), 3.0)
	# Burrowed tunnelers show only a moving mound.
	if _bstate == "burrowed":
		draw_arc(Vector2.ZERO, radius * 0.8, PI, TAU, 12, color.darkened(0.2), 4.0)
		return
	# Grave-swarm bones: a stompable pile, ticking back to life.
	if _bstate == "bones":
		for i in 4:
			var a := i * TAU / 4.0 + 0.5
			draw_circle(Vector2(cos(a), sin(a)) * radius * 0.4, 3.0, color.darkened(0.3))
		return
	# Roc's shadow warns where it will crash.
	if _bstate == "crash" or (_bstate == "ascend" and archetype == "roc"):
		var shadow := to_local(_lock_pos if _bstate == "crash" else (target.global_position if target != null and is_instance_valid(target) else global_position))
		draw_circle(shadow, 34.0, Color(0, 0, 0, 0.30))
		draw_arc(shadow, 34.0, 0.0, TAU, 20, Color(1, 0.4, 0.3, 0.7), 2.0)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.35), 2.0)
	# Per-archetype identity marks — every enemy in a biome reads differently.
	match archetype:
		"brute":
			draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 14, Color(0, 0, 0, 0.3), 3.0)
			# the raised shield (blocks ranged damage)
			var fd := (target.global_position - global_position).normalized() if target != null and is_instance_valid(target) else Vector2.RIGHT
			draw_arc(Vector2.ZERO, radius + 4.0, fd.angle() - 0.8, fd.angle() + 0.8, 10, Color(0.9, 0.9, 0.95, 0.8), 3.5)
		"bramble" :
			if _bstate == "harden":
				for i in 8:
					var a2 := i * TAU / 8.0
					draw_line(Vector2(cos(a2), sin(a2)) * radius, Vector2(cos(a2), sin(a2)) * (radius + 7.0), Color(1, 1, 1, 0.8), 2.0)
		"brawler":
			if _embold:
				draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 16, Color(1.0, 0.5, 0.4, 0.8), 2.0)
		"skirmisher":
			draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 0.85, 0.9))
		"volleyer":
			draw_rect(Rect2(-4, -4, 8, 8), Color(0, 0, 0, 0.4))
		"lunger":
			var d := (target.global_position - global_position).normalized() if target != null and is_instance_valid(target) else Vector2.RIGHT
			draw_line(Vector2.ZERO, d * (radius + 4.0), Color(0, 0, 0, 0.45), 3.0)
			if _bstate == "windup":
				draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 16, Color(1, 0.4, 0.3, 0.9), 3.0)
		"bonepile":
			for i in 3:
				var a := i * TAU / 3.0
				draw_circle(Vector2(cos(a), sin(a)) * radius * 0.45, 2.5, Color(0, 0, 0, 0.35))
		"howler":
			draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 18, color.lightened(0.3), 2.0)
		"diver":
			draw_line(Vector2(-radius, -3), Vector2(radius, -3), Color(1, 1, 1, 0.5), 2.0)
			if _bstate == "diving":
				draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 14, Color(1, 0.5, 0.3, 0.9), 2.5)
		"broodmother":
			for i in 4:
				var a := i * TAU / 4.0 + 0.4
				draw_circle(Vector2(cos(a), sin(a)) * radius * 0.5, 2.0, Color(1, 1, 1, 0.4))
		"tunneler":
			draw_arc(Vector2.ZERO, radius * 0.6, PI, TAU, 10, Color(0, 0, 0, 0.4), 3.0)
		"gale", "roc":
			draw_line(Vector2(-radius * 0.9, -radius * 0.5), Vector2(0, 0), Color(1, 1, 1, 0.4), 2.0)
			draw_line(Vector2(radius * 0.9, -radius * 0.5), Vector2(0, 0), Color(1, 1, 1, 0.4), 2.0)
