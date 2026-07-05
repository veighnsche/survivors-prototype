class_name Player
extends CharacterBody2D
## The tabula-rasa caster. Force Bolt cantrip to start. Essence fills family
## Insight: a family's first spell auto-awakens (loud), deeper spells unlock as
## level-up cards you pick. A caster brain picks the best offensive each cast,
## favoring the damage type the current enemies are weakest to. See DESIGN.md.

signal died
signal awakened(fam)

@export var max_hp := 100.0
var hp := 100.0
var speed := 210.0
var radius := 13.0
var color := Color(0.87, 0.85, 0.78)

# Casting
var bolt_count := 1
var bolt_cd := 0.0
var nova_cd := 0.0
var wither_cd := 0.0

# Global modifiers
var damage_mult := 1.0
var attack_speed_mult := 1.0
var pickup_radius := 72.0
var armor := 0.0
var recovery := 0.0

# --- Family state -------------------------------------------------------------
var insight := {"blast": 0.0, "ward": 0.0, "drain": 0.0, "control": 0.0, "sight": 0.0, "summon": 0.0}
var granted_tier := {"blast": 0, "ward": 0, "drain": 0, "control": 0, "sight": 0, "summon": 0}

# Blast
var explode_radius := 0.0
var nova_radius := 0.0
var nova_damage := 0.0
# Ward
var shield_max := 0.0
var shield_hp := 0.0
var shield_regen := 0.0
var thorns_damage := 0.0
var deflect_chance := 0.0
# Drain
var siphon_pct := 0.0
var rot_timer := 0.0
var rot_radius := 0.0
var rot_damage := 0.0
# Control
var frost_timer := 0.0
var dread_timer := 0.0
var chill_level := 0
# Sight
var crit_chance := 0.0
var crit_mult := 2.0
var dodge_chance := 0.0
var mark_timer := 0.0
# Summon
var wisp_count := 0
var wisp_timer := 0.0
var wisp_speed_mult := 1.0
var hex_timer := 0.0

# Family deepening (repeatable cards)
var fam_power := {"blast": 1.0, "ward": 1.0, "drain": 1.0, "control": 1.0, "sight": 1.0, "summon": 1.0}
var blast_radius_mult := 1.0
var control_radius_mult := 1.0
var cantrip_mult := 1.0

# Temporary boosts
var boost_dmg := 1.0
var boost_dmg_t := 0.0
var boost_rate := 1.0
var boost_rate_t := 0.0
var boost_speed := 1.0
var boost_speed_t := 0.0
var invuln_t := 0.0
var bonus_shield := 0.0  # Barrier pickup: absorbs damage until broken, no timer

# Contact damage
var contact_tick := 0.5
var contact_timer := 0.0

var projectile_parent: Node
var dead := false
var _overlapping: Dictionary = {}


func _ready() -> void:
	pickup_radius = Config.PICKUP_RADIUS
	contact_tick = Config.CONTACT_TICK
	hp = max_hp
	z_index = 10
	collision_layer = 1
	collision_mask = 16

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
	if shield_max > 0.0 and shield_hp < shield_max:
		shield_hp = min(shield_max, shield_hp + shield_regen * delta)
		queue_redraw()
	_cast_brain(delta)
	_handle_rot(delta)
	_handle_frost(delta)
	_handle_dread(delta)
	_handle_mark(delta)
	_handle_wisp(delta)
	_handle_hex(delta)
	_handle_contact(delta)


# --- Input --------------------------------------------------------------------
func _input_vector() -> Vector2:
	if Sim.enabled:
		return _sim_bot_vector()
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


func _sim_bot_vector() -> Vector2:
	if OS.has_environment("DBG_STAND"):
		return Vector2.ZERO
	var e := _nearest_enemy_in(99999.0)
	if e == null:
		return Vector2.RIGHT
	var away := global_position - e.global_position
	return away.normalized() if away.length() > 1.0 else Vector2.RIGHT


# --- Insight / families (hybrid: T1 auto, T2/T3 as cards) ---------------------
func insight_tier(fam: String) -> int:
	var t := 0
	for threshold in Config.INSIGHT_TIERS:
		if float(insight.get(fam, 0.0)) >= float(threshold):
			t += 1
	return t


func family_tier(fam: String) -> int:
	return int(granted_tier.get(fam, 0))


## The next tier available to pick as a card (insight-unlocked, not yet granted),
## or 0 if none. T1 auto-awakens, so cards only ever offer T2/T3.
func next_card_tier(fam: String) -> int:
	var g: int = int(granted_tier[fam])
	if g >= 1 and g < 3 and insight_tier(fam) > g:
		return g + 1
	return 0


func add_insight(fam: String, amount: float) -> void:
	if not insight.has(fam):
		return
	insight[fam] = float(insight[fam]) + amount
	# First spell awakens on its own — the world teaching you, loudly.
	if insight_tier(fam) >= 1 and int(granted_tier[fam]) < 1:
		_grant_tier(fam, 1, true)


func grant_family_tier(fam: String, tier: int) -> void:
	_grant_tier(fam, tier, false)


func _grant_tier(fam: String, tier: int, loud: bool) -> void:
	granted_tier[fam] = tier
	RunLog.event("%s tier %d %s" % [Config.FAMILY_NAMES[fam], tier, "AWAKENED" if loud else "(picked as card)"])
	_apply_tier_effects(fam, tier)
	if loud:
		awakened.emit(fam)
		Fx.shake(0.4)
	else:
		var fname: String = Config.FAMILY_NAMES[fam]
		Fx.floating_text(global_position + Vector2(0, -30), "%s %s" % [fname, ["I", "II", "III"][mini(tier, 3) - 1]], Config.FAMILY_COLORS[fam])
	queue_redraw()


func _apply_tier_effects(fam: String, tier: int) -> void:
	match fam:
		"blast":
			match tier:
				1:
					explode_radius = 56.0
				2:
					nova_radius = 120.0
					nova_damage = 11.0
				3:
					bolt_count += 1
					nova_radius = 160.0
					explode_radius = 74.0
		"ward":
			match tier:
				1:
					shield_max = 30.0
					shield_regen = 4.0
				2:
					thorns_damage = 9.0
				3:
					deflect_chance = 0.6
					shield_max = 58.0
		"drain":
			match tier:
				1:
					siphon_pct = 0.10
				2:
					rot_radius = 100.0
					rot_damage = 2.2
				3:
					siphon_pct = 0.16
		"control":
			match tier:
				1:
					frost_timer = 0.5  # frost pulse comes alive
				2:
					pass  # Shatter: slowed enemies take bonus damage (handled in deal)
				3:
					dread_timer = 1.0  # fear pulse comes alive
		"sight":
			match tier:
				1:
					crit_chance += 0.15
				2:
					mark_timer = 1.0  # marking comes alive
				3:
					dodge_chance = 0.25
		"summon":
			match tier:
				1:
					wisp_count = 1
				2:
					hex_timer = 1.0  # hexfields come alive
				3:
					wisp_count = 2


## Central damage funnel: global mults, siphon, use-deepens Insight trickle.
func deal(e, base: float, dtype: String, fam: String) -> void:
	if e == null or not is_instance_valid(e):
		return
	# Shatter (Control II): slowed enemies take bonus damage from everything.
	if e.slow_t > 0.0 and family_tier("control") >= 2:
		base *= 1.45
	# Crits (Sight): strike true — precise damage, which flyers can't shrug.
	var final_dtype := dtype
	if crit_chance > 0.0 and randf() < crit_chance:
		base *= crit_mult
		final_dtype = "precise"
	var applied: float = e.take_damage(base * damage_mult * boost_dmg, final_dtype)
	RunLog.bump("damage_by_family", fam if fam != "" else "cantrip", applied)
	RunLog.bump("damage_by_type", dtype, applied)
	if siphon_pct > 0.0 and applied > 0.0:
		hp = min(max_hp, hp + applied * siphon_pct)
		RunLog.bump("healing", "siphon", applied * siphon_pct)
	if fam != "" and applied > 0.0:
		add_insight(fam, 0.008)


func _eff(e, dtype: String) -> float:
	return float(e.resists.get(dtype, 1.0))


# --- Caster brain: pick the best offensive for the situation ------------------
func _cast_brain(delta: float) -> void:
	bolt_cd -= delta
	nova_cd -= delta
	wither_cd -= delta

	var best_score := 0.0
	var best := ""
	var best_target = null

	if bolt_cd <= 0.0:
		var t := _nearest_enemy_in(Config.CANTRIP.range)
		if t != null:
			var s: float = 1.0 * _eff(t, "arcane")
			if s > best_score:
				best_score = s
				best = "bolt"
				best_target = t

	if nova_radius > 0.0 and nova_cd <= 0.0:
		var cnt := 0
		var effsum := 0.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) <= nova_radius:
				cnt += 1
				effsum += _eff(e, "arcane")
		if cnt >= 2:
			var s: float = cnt * (effsum / cnt) * 0.7
			if s > best_score:
				best_score = s
				best = "nova"

	if int(granted_tier.drain) >= 3 and wither_cd <= 0.0:
		var tough = null
		var tough_hp := 14.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) <= 300.0 and e.hp > tough_hp:
				tough_hp = e.hp
				tough = e
		if tough != null:
			var s: float = (tough_hp / 30.0) * _eff(tough, "necrotic")
			if s > best_score:
				best_score = s
				best = "wither"
				best_target = tough

	match best:
		"bolt":
			_cast_bolt(best_target)
			bolt_cd = Config.CANTRIP.interval * attack_speed_mult * boost_rate
		"nova":
			_cast_nova()
			nova_cd = 3.2 * attack_speed_mult
		"wither":
			_cast_wither(best_target)
			wither_cd = 4.0
		_:
			pass  # nothing worth casting; cooldowns keep ticking, brain re-runs next frame


func _nearest_enemy_in(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach * reach
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _cast_bolt(target) -> void:
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var spread := deg_to_rad(12.0)
	for i in bolt_count:
		var offset := 0.0
		if bolt_count > 1:
			offset = spread * (i - (bolt_count - 1) / 2.0)
		var p := Projectile.new()
		p.damage = Config.CANTRIP.damage * cantrip_mult * damage_mult * boost_dmg
		p.speed = Config.CANTRIP.speed
		p.life = Config.CANTRIP.life
		p.direction = base_dir.rotated(offset)
		p.explode_radius = explode_radius
		p.explode_factor = 0.6 * fam_power.blast
		p.source = self
		p.global_position = global_position
		projectile_parent.add_child(p)


func _cast_nova() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= nova_radius:
			deal(e, nova_damage * fam_power.blast, "arcane", "blast")
	var ring := RingFx.new()
	ring.max_radius = nova_radius
	ring.color = Config.FAMILY_COLORS.blast
	ring.global_position = global_position
	projectile_parent.add_child(ring)


func _cast_wither(target) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.apply_vuln(1.5, 4.0)
	deal(target, 14.0, "necrotic", "drain")
	Fx.floating_text(target.global_position + Vector2(0, -18), "withered", Config.FAMILY_COLORS.drain)


# --- Drain: Rot aura (ambient) ------------------------------------------------
func _handle_rot(delta: float) -> void:
	if rot_radius <= 0.0:
		return
	rot_timer -= delta
	if rot_timer > 0.0:
		return
	rot_timer = 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= rot_radius:
			deal(e, rot_damage, "necrotic", "drain")
	queue_redraw()


# --- Control: Frost Pulse (T1) + Dread (T3) ------------------------------------
func _handle_frost(delta: float) -> void:
	if family_tier("control") < 1:
		return
	frost_timer -= delta
	if frost_timer > 0.0:
		return
	frost_timer = 2.6 * attack_speed_mult
	var radius := 135.0 * control_radius_mult
	var slow_factor := maxf(0.25, 0.55 - 0.05 * chill_level)
	var any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= radius:
			e.apply_slow(slow_factor, 2.0)
			deal(e, 3.0 * fam_power.control, "frost", "control")
			any = true
	if any:
		var ring := RingFx.new()
		ring.max_radius = radius
		ring.color = Config.FAMILY_COLORS.control
		ring.global_position = global_position
		projectile_parent.add_child(ring)


func _handle_dread(delta: float) -> void:
	if family_tier("control") < 3:
		return
	dread_timer -= delta
	if dread_timer > 0.0:
		return
	dread_timer = 5.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_boss and global_position.distance_to(e.global_position) <= 210.0:
			e.apply_fear(1.6)


# --- Sight: Mark (T2) ------------------------------------------------------------
func _handle_mark(delta: float) -> void:
	if family_tier("sight") < 2:
		return
	mark_timer -= delta
	if mark_timer > 0.0:
		return
	mark_timer = 4.0
	var tough = null
	var tough_hp := 10.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= 320.0 and e.hp > tough_hp:
			tough_hp = e.hp
			tough = e
	if tough != null:
		tough.apply_vuln(1.5, 3.0)
		Fx.floating_text(tough.global_position + Vector2(0, -18), "marked", Config.FAMILY_COLORS.sight)


# --- Summon: Wisps (T1/T3) + Hexfield (T2) ---------------------------------------
func _handle_wisp(delta: float) -> void:
	if wisp_count <= 0:
		return
	wisp_timer -= delta
	if wisp_timer > 0.0:
		return
	wisp_timer = 1.0 * wisp_speed_mult * attack_speed_mult
	for i in wisp_count:
		var target := _nearest_enemy_in(520.0)
		if target == null:
			return
		var off := Vector2(cos(TAU * i / maxi(wisp_count, 1)), sin(TAU * i / maxi(wisp_count, 1))) * 26.0
		var p := Projectile.new()
		p.damage = 4.0 * fam_power.summon * damage_mult * boost_dmg
		p.speed = 480.0
		p.life = 1.2
		p.radius = 3.5
		p.dtype = "physical"
		p.fam = "summon"
		p.tint = Config.FAMILY_COLORS.summon
		p.direction = (target.global_position - (global_position + off)).normalized()
		p.source = self
		p.global_position = global_position + off
		projectile_parent.add_child(p)


func _handle_hex(delta: float) -> void:
	if family_tier("summon") < 2:
		return
	hex_timer -= delta
	if hex_timer > 0.0:
		return
	hex_timer = 4.5
	var target := _nearest_enemy_in(420.0)
	if target == null:
		return
	var zone := HexZone.new()
	zone.player = self
	zone.power = fam_power.summon
	zone.global_position = target.global_position
	projectile_parent.add_child(zone)


# --- Ward: deflect + contact/thorns -------------------------------------------
func try_deflect_shot(pos: Vector2) -> bool:
	if deflect_chance > 0.0 and randf() < deflect_chance:
		Fx.death_pop(pos, Config.FAMILY_COLORS.ward)
		add_insight("ward", 0.05)
		return true
	return false


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
		if thorns_damage > 0.0:
			for id in _overlapping.keys():
				var e = _overlapping[id]
				if is_instance_valid(e):
					deal(e, thorns_damage, "reflect", "ward")
		contact_timer = contact_tick


func take_damage(amount: float) -> void:
	if dead or invuln_t > 0.0:
		return
	if dodge_chance > 0.0 and randf() < dodge_chance:
		Fx.floating_text(global_position + Vector2(0, -24), "dodged", Config.FAMILY_COLORS.sight)
		RunLog.bump("damage_taken", "dodged", amount)
		return
	if Sim.enabled:
		Sim.damage_taken += max(0.0, amount - armor)
		return
	var remaining := maxf(0.0, amount - armor)
	# Barrier (Shield pickup) absorbs first — it's expendable, the Aegis regens.
	if bonus_shield > 0.0 and remaining > 0.0:
		var soaked: float = min(bonus_shield, remaining)
		bonus_shield -= soaked
		remaining -= soaked
		RunLog.bump("damage_taken", "barrier", soaked)
		queue_redraw()
		if remaining <= 0.0:
			return
	if shield_hp > 0.0 and remaining > 0.0:
		var absorbed: float = min(shield_hp, remaining)
		shield_hp -= absorbed
		remaining -= absorbed
		RunLog.bump("damage_taken", "shield", absorbed)
		add_insight("ward", 0.02)
		queue_redraw()
		if remaining <= 0.0:
			return
	RunLog.bump("damage_taken", "hp", remaining)
	hp -= remaining
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


# --- Boosts -------------------------------------------------------------------
func active_boosts() -> Array:
	var out: Array = []
	if boost_dmg_t > 0.0:
		out.append({"name": "Power",  "secs": boost_dmg_t,   "frac": boost_dmg_t / Config.BOOST_DURATION,   "color": Color(0.8, 0.42, 0.95)})
	if boost_rate_t > 0.0:
		out.append({"name": "Frenzy", "secs": boost_rate_t,  "frac": boost_rate_t / Config.BOOST_DURATION,  "color": Color(0.95, 0.4, 0.32)})
	if boost_speed_t > 0.0:
		out.append({"name": "Haste",  "secs": boost_speed_t, "frac": boost_speed_t / Config.BOOST_DURATION, "color": Color(0.3, 0.9, 0.95)})
	if bonus_shield > 0.0:
		out.append({"name": "Barrier", "secs": bonus_shield, "frac": clampf(bonus_shield / Config.SHIELD_BARRIER, 0.0, 1.0), "color": Color(0.92, 0.9, 0.5)})
	return out


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
			bonus_shield += Config.SHIELD_BARRIER
	modulate = Color(1.4, 1.4, 0.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)


# --- Vital cards --------------------------------------------------------------
func apply_upgrade(id: String) -> void:
	match id:
		"maxhp":
			max_hp += 20.0
			hp += 20.0
		"movespeed":
			speed *= 1.08
		"castspeed":
			attack_speed_mult *= 0.90
		"pickup":
			pickup_radius *= 1.25
		"regen":
			recovery += 0.3
		"focus":
			damage_mult *= 1.10
		"armorcard":
			armor += 1.0
		"sharpen":
			cantrip_mult *= 1.20
		"heal":
			hp = min(max_hp, hp + 30.0)
		# --- family deepening cards (offered once the family is awakened) ---
		"blast_hotter":
			fam_power.blast *= 1.25
		"blast_wider":
			blast_radius_mult *= 1.20
			_reapply_blast_radii()
		"ward_denser":
			shield_max += 12.0
			shield_regen += 1.5
		"ward_sharper":
			thorns_damage *= 1.4 if thorns_damage > 0.0 else 1.0
			thorns_damage = maxf(thorns_damage, 4.0)  # gives pre-T2 wards a base sting
		"drain_deeper":
			fam_power.drain *= 1.25
			rot_damage *= 1.25
		"drain_thicker":
			siphon_pct += 0.03
		"control_chill":
			chill_level += 1
			fam_power.control *= 1.15
		"control_wider":
			control_radius_mult *= 1.20
		"sight_keener":
			crit_chance += 0.06
		"sight_deadly":
			crit_mult += 0.4
		"summon_fiercer":
			fam_power.summon *= 1.30
		"summon_eager":
			wisp_speed_mult *= 0.85


func _reapply_blast_radii() -> void:
	var t := family_tier("blast")
	if t >= 1:
		explode_radius = (56.0 if t < 3 else 74.0) * blast_radius_mult
	if t >= 2:
		nova_radius = (120.0 if t < 3 else 160.0) * blast_radius_mult


func _draw() -> void:
	if rot_radius > 0.0:
		draw_circle(Vector2.ZERO, rot_radius, Color(0.44, 0.69, 0.23, 0.05))
		draw_arc(Vector2.ZERO, rot_radius, 0.0, TAU, 40, Color(0.44, 0.69, 0.23, 0.3), 2.0)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 2.0)
	if shield_max > 0.0:
		var frac := shield_hp / shield_max
		draw_arc(Vector2.ZERO, radius + 6.0, -PI / 2.0, -PI / 2.0 + frac * TAU, 30, Config.FAMILY_COLORS.ward, 2.5)
	if bonus_shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 30, Color(0.92, 0.9, 0.5, 0.8), 2.5)
