class_name Player
extends CharacterBody2D
## The tabula-rasa caster.
## - BASIC ATTACKS are awakened by surviving in biomes (insight from gems).
##   One basic attack fires per cast cycle — the brain picks whichever deals
##   the most damage at that moment.
## - SKILLS (Nova, Aegis, Rot, Mark, wisps...) are never automatic: they are
##   level-up cards, gated by how deep your insight in that family runs.

signal died
signal awakened(fam)

@export var max_hp := 100.0
var hp := 100.0
var speed := 210.0
var radius := 13.0
var color := Color(0.87, 0.85, 0.78)

# GLOBAL cast cooldown: casting ANY cantrip silences all cantrips for the cast
# cantrip's cooldown. Heavy casts cost you your voice.
var cast_cd := 0.0
var bolt_count := 1
var current_biome := "commons"  # set each frame by the run director
var brain_report: Array = []    # live table of the selector's last decision

# Global modifiers
var damage_mult := 1.0
var attack_speed_mult := 1.0
var pickup_radius := 72.0
var armor := 0.0
var recovery := 0.0

# --- Family state ---------------------------------------------------------------
var insight := {"blast": 0.0, "ward": 0.0, "drain": 0.0, "control": 0.0, "sight": 0.0, "summon": 0.0}
var awakened_fams := {"blast": false, "ward": false, "drain": false, "control": false, "sight": false, "summon": false}

# --- Skills (unlocked ONLY via level-up cards) -----------------------------------
var has_nova := false
var nova_timer := 0.0
var shield_max := 0.0
var shield_hp := 0.0
var shield_regen := 0.0
var thorns_damage := 0.0
var deflect_chance := 0.0
var siphon_pct := 0.0
var rot_timer := 0.0
var rot_radius := 0.0
var rot_damage := 0.0
var has_wither := false
var wither_timer := 0.0
var has_frost_pulse := false
var frost_timer := 0.0
var has_shatter := false
var has_dread := false
var dread_timer := 0.0
var crit_chance := 0.0
var crit_mult := 2.0
var has_mark := false
var mark_timer := 0.0
var dodge_chance := 0.0
var wisp_count := 0
var wisp_timer := 0.0
var wisp_speed_mult := 1.0
var has_hex := false
var hex_timer := 0.0

# Family deepening (repeatable cards)
var fam_power := {"blast": 1.0, "ward": 1.0, "drain": 1.0, "control": 1.0, "sight": 1.0, "summon": 1.0}
var blast_radius_mult := 1.0
var control_radius_mult := 1.0
var chill_level := 0
var cantrip_mult := 1.0

# Temporary boosts
var boost_dmg := 1.0
var boost_dmg_t := 0.0
var boost_rate := 1.0
var boost_rate_t := 0.0
var boost_speed := 1.0
var boost_speed_t := 0.0
var invuln_t := 0.0
var bonus_shield := 0.0

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
	_handle_nova(delta)
	_handle_rot(delta)
	_handle_wither(delta)
	_handle_frost(delta)
	_handle_dread(delta)
	_handle_mark(delta)
	_handle_wisp(delta)
	_handle_hex(delta)
	_handle_contact(delta)


# --- Input -------------------------------------------------------------------------
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


# --- Insight: surviving a biome awakens its basic attack -----------------------------
func insight_tier(fam: String) -> int:
	var t := 0
	for threshold in Config.INSIGHT_TIERS:
		if float(insight.get(fam, 0.0)) >= float(threshold):
			t += 1
	return t


## Progress display (wheel/HUD): insight depth of the family.
func family_tier(fam: String) -> int:
	return insight_tier(fam)


func is_awakened(fam: String) -> bool:
	return bool(awakened_fams.get(fam, false))


func add_insight(fam: String, amount: float) -> void:
	if not insight.has(fam):
		return
	insight[fam] = float(insight[fam]) + amount
	if insight_tier(fam) >= 1 and not awakened_fams[fam]:
		awakened_fams[fam] = true
		RunLog.event("%s AWAKENED — basic attack: %s" % [Config.FAMILY_NAMES[fam], Config.BASIC_ATTACKS[fam].name])
		awakened.emit(fam)
		Fx.shake(0.4)
		queue_redraw()


## Skill cards call this — nothing here is ever granted automatically.
func unlock_skill(fam: String, key: String) -> void:
	match key:
		"nova":
			has_nova = true
		"volley":
			bolt_count += 1
		"aegis":
			shield_max = 34.0
			shield_regen = 4.0
			shield_hp = shield_max
		"thorns":
			thorns_damage = 9.0
		"deflect":
			deflect_chance = 0.6
			shield_max += 24.0
		"siphon":
			siphon_pct += 0.06
		"rot":
			rot_radius = 100.0
			rot_damage = 2.2
		"wither":
			has_wither = true
		"pulse":
			has_frost_pulse = true
		"shatter":
			has_shatter = true
		"dread":
			has_dread = true
		"keen":
			crit_chance += 0.15
		"mark":
			has_mark = true
		"foresight":
			dodge_chance = 0.25
		"wisp":
			wisp_count = maxi(wisp_count, 1)
		"hex":
			has_hex = true
		"legion":
			wisp_count = 2
	RunLog.event("skill unlocked: %s/%s" % [fam, key])
	queue_redraw()


## Central damage funnel: mults, crits, Shatter, siphon, use-deepens insight.
## Returns the damage actually applied (leech etc. build on it).
func deal(e, base: float, dtype: String, fam: String) -> float:
	if e == null or not is_instance_valid(e):
		return 0.0
	if e.slow_t > 0.0 and has_shatter:
		base *= 1.45
	var final_dtype := dtype
	if crit_chance > 0.0 and randf() < crit_chance:
		base *= crit_mult
		final_dtype = "precise"
	var applied: float = e.take_damage(base * damage_mult * boost_dmg, final_dtype)
	RunLog.bump("damage_by_family", fam if fam != "" else "force", applied)
	RunLog.bump("damage_by_type", dtype, applied)
	if siphon_pct > 0.0 and applied > 0.0:
		hp = min(max_hp, hp + applied * siphon_pct)
		RunLog.bump("healing", "siphon", applied * siphon_pct)
	if fam != "" and applied > 0.0:
		add_insight(fam, 0.008)
	return applied


# --- The caster brain: ONE basic attack per cycle, the mathematically best one -------
func _est(e, base: float, dtype: String) -> float:
	var v: float = base * e.damage_mult_for(dtype)
	if e.slow_t > 0.0 and has_shatter:
		v *= 1.45
	return v


func _available_basics() -> Array:
	var out: Array = ["force"]
	for fam in awakened_fams:
		if awakened_fams[fam]:
			out.append(fam)
	return out


## Damage/cooldown scale with the family's insight tier: deeper = harder-hitting
## but slower, so cheap low-tier attacks stay competitive in the selector.
func _basic_dmg(key: String, atk: Dictionary) -> float:
	if key == "force":
		return atk.damage * cantrip_mult
	var tier := maxi(insight_tier(key), 1)
	return atk.damage * fam_power.get(key, 1.0) * (1.0 + Config.TIER_DMG_BONUS * (tier - 1))


func _basic_cd(key: String, atk: Dictionary) -> float:
	if key == "force":
		return atk.cooldown
	var tier := maxi(insight_tier(key), 1)
	return atk.cooldown * (1.0 + Config.TIER_CD_PENALTY * (tier - 1))


## Expected damage capped at the enemy's remaining HP — overkill is worthless,
## so nuking a swarm of near-dead mites no longer inflates a score.
func _est_capped(e, base: float, dtype: String) -> float:
	return minf(_est(e, base, dtype), maxf(e.hp, 0.0))


## Utility scoring: damage + survival relief + healing need + home-turf lean,
## normalized by cooldown so heavy AoE must EARN its long recovery.
func _score_attack(key: String, atk: Dictionary) -> Dictionary:
	var dmg_base := _basic_dmg(key, atk)
	var score := 0.0
	var target = null
	match atk.kind:
		"bolt":
			var t := _nearest_enemy_in(atk.range)
			if t == null:
				return {"score": 0.0}
			score = _est_capped(t, dmg_base, atk.dtype) * bolt_count
			if atk.has("explode"):
				var er: float = atk.explode * blast_radius_mult
				for e2 in get_tree().get_nodes_in_group("enemies"):
					if e2 != t and t.global_position.distance_to(e2.global_position) <= er:
						score += _est_capped(e2, dmg_base * 0.6, atk.dtype)
			if atk.has("leech"):
				# healing value scales with how hurt we are
				var urgency: float = clampf(1.0 - hp / max_hp, 0.0, 1.0)
				score += _est_capped(t, dmg_base, atk.dtype) * atk.leech * urgency * 3.0
			target = t
		"cleave":
			var aim_t := _nearest_enemy_in(atk.range)
			if aim_t == null:
				return {"score": 0.0}
			var aim: Vector2 = (aim_t.global_position - global_position).normalized()
			var half: float = deg_to_rad(atk.arc) * 0.5
			for e in get_tree().get_nodes_in_group("enemies"):
				var to_e: Vector2 = e.global_position - global_position
				if to_e.length() <= atk.range and absf(aim.angle_to(to_e.normalized())) <= half:
					score += _est_capped(e, dmg_base, atk.dtype)
					if atk.has("slow") and e.slow_t <= 0.0:
						score += e.speed * 0.02  # slow utility: fast enemies are worth chilling
			target = aim_t
		"chain":
			var t := _nearest_enemy_in(atk.range)
			if t == null:
				return {"score": 0.0}
			score = _est_capped(t, dmg_base, atk.dtype)
			var links := _chain_targets(t, int(atk.jumps), atk.jump_range)
			for e in links:
				score += _est_capped(e, dmg_base * 0.8, atk.dtype)
			target = t
		"repulse":
			# survival tool: value = damage + the contact damage you're relieving
			var pressure := 0.0
			var count := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= atk.range:
					score += _est_capped(e, dmg_base, atk.dtype)
					pressure += e.eff_damage()
					count += 1
			if count == 0:
				return {"score": 0.0}
			var urgency: float = clampf(1.3 - hp / max_hp, 0.3, 1.3)
			score += pressure * urgency
		"burst":
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= atk.range:
					score += _est_capped(e, dmg_base, atk.dtype)
			if score <= 0.0:
				return {"score": 0.0}
	# Home-turf attunement: lean toward the attack this biome teaches.
	if key == Config.BIOMES[current_biome].family:
		score *= Config.BIOME_ATTUNE_BIAS
	# Normalize by cooldown: value per commitment, not per splash fantasy.
	score /= pow(maxf(_basic_cd(key, atk), 0.3), Config.SCORE_CD_EXPONENT)
	return {"score": score, "target": target}


func _cast_brain(delta: float) -> void:
	cast_cd -= delta
	if cast_cd > 0.0:
		return  # the last cast still holds our voice

	# Score EVERY awakened cantrip, cast the best — its cooldown gates us ALL.
	var report: Array = []
	var best := ""
	var best_score := 0.0
	var best_target = null
	for key in _available_basics():
		var atk: Dictionary = Config.BASIC_ATTACKS[key]
		var res := _score_attack(key, atk)
		var entry := {"name": atk.name, "score": float(res.score),
			"home": Config.BIOMES[current_biome].family == key, "picked": false,
			"no_target": float(res.score) <= 0.0}
		report.append(entry)
		if float(res.score) > best_score:
			best_score = res.score
			best = key
			best_target = res.get("target")

	if best != "":
		var chosen: Dictionary = Config.BASIC_ATTACKS[best]
		for entry in report:
			if entry.name == chosen.name:
				entry.picked = true
		_cast_basic(best, chosen, best_target)
		RunLog.bump("basic_casts", chosen.name)
		# THE cost: everything is silenced for this cantrip's cooldown.
		cast_cd = _basic_cd(best, chosen) * attack_speed_mult * boost_rate
	brain_report = report


func _chain_targets(from_enemy, jumps: int, jump_range: float) -> Array:
	var links: Array = []
	var seen := {from_enemy.get_instance_id(): true}
	var current = from_enemy
	for j in jumps:
		var next = null
		var best_d := jump_range * jump_range
		for e in get_tree().get_nodes_in_group("enemies"):
			if seen.has(e.get_instance_id()):
				continue
			var d: float = current.global_position.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				next = e
		if next == null:
			break
		seen[next.get_instance_id()] = true
		links.append(next)
		current = next
	return links


func _cast_basic(key: String, atk: Dictionary, target) -> void:
	var fam := "" if key == "force" else key
	var dmg_base := _basic_dmg(key, atk)
	match atk.kind:
		"bolt":
			var base_dir: Vector2 = (target.global_position - global_position).normalized()
			var spread := deg_to_rad(12.0)
			for i in bolt_count:
				var offset := 0.0
				if bolt_count > 1:
					offset = spread * (i - (bolt_count - 1) / 2.0)
				var p := Projectile.new()
				p.damage = dmg_base * damage_mult * boost_dmg
				p.speed = atk.speed
				p.life = Config.BOLT_LIFE
				p.direction = base_dir.rotated(offset)
				p.dtype = atk.dtype
				p.fam = fam
				if atk.has("explode"):
					p.explode_radius = atk.explode * blast_radius_mult
					p.explode_factor = 0.6
				if atk.has("leech"):
					p.leech = atk.leech
				if key != "force":
					p.tint = Config.FAMILY_COLORS[key]
				p.source = self
				p.global_position = global_position
				projectile_parent.add_child(p)
		"cleave":
			var aim: Vector2 = (target.global_position - global_position).normalized()
			var half: float = deg_to_rad(atk.arc) * 0.5
			var slow_factor := maxf(0.25, atk.slow - 0.05 * chill_level)
			for e in get_tree().get_nodes_in_group("enemies"):
				var to_e: Vector2 = e.global_position - global_position
				if to_e.length() <= atk.range and absf(aim.angle_to(to_e.normalized())) <= half:
					deal(e, dmg_base, atk.dtype, fam)
					e.apply_slow(slow_factor, 1.8)
			var ring := RingFx.new()
			ring.max_radius = atk.range
			ring.color = Config.FAMILY_COLORS.control
			ring.global_position = global_position
			projectile_parent.add_child(ring)
		"chain":
			var pts := PackedVector2Array([global_position, target.global_position])
			deal(target, dmg_base, atk.dtype, fam)
			for e in _chain_targets(target, int(atk.jumps), atk.jump_range):
				deal(e, dmg_base * 0.8, atk.dtype, fam)
				pts.append(e.global_position)
			var bolt := ChainFx.new()
			bolt.points = pts
			bolt.color = Config.FAMILY_COLORS.sight
			projectile_parent.add_child(bolt)
		"repulse":
			for e in get_tree().get_nodes_in_group("enemies"):
				var to_e: Vector2 = e.global_position - global_position
				if to_e.length() <= atk.range:
					deal(e, dmg_base, atk.dtype, fam)
					e.global_position += to_e.normalized() * atk.knockback
			var ring := RingFx.new()
			ring.max_radius = atk.range
			ring.color = Config.FAMILY_COLORS.ward
			ring.global_position = global_position
			projectile_parent.add_child(ring)
		"burst":
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= atk.range:
					deal(e, dmg_base, atk.dtype, fam)
			var ring := RingFx.new()
			ring.max_radius = atk.range
			ring.color = Config.FAMILY_COLORS.summon
			ring.global_position = global_position
			projectile_parent.add_child(ring)


func _nearest_enemy_in(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach * reach
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- Skills (auto-firing once unlocked via cards) --------------------------------------
func _handle_nova(delta: float) -> void:
	if not has_nova:
		return
	nova_timer -= delta
	if nova_timer > 0.0:
		return
	nova_timer = 3.2 * attack_speed_mult
	var nova_radius := 130.0 * blast_radius_mult
	var any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= nova_radius:
			deal(e, 11.0 * fam_power.blast, "arcane", "blast")
			any = true
	if any:
		var ring := RingFx.new()
		ring.max_radius = nova_radius
		ring.color = Config.FAMILY_COLORS.blast
		ring.global_position = global_position
		projectile_parent.add_child(ring)


func _handle_rot(delta: float) -> void:
	if rot_radius <= 0.0:
		return
	rot_timer -= delta
	if rot_timer > 0.0:
		return
	rot_timer = 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= rot_radius:
			deal(e, rot_damage * fam_power.drain, "necrotic", "drain")


func _handle_wither(delta: float) -> void:
	if not has_wither:
		return
	wither_timer -= delta
	if wither_timer > 0.0:
		return
	wither_timer = 4.0
	var best: Node2D = null
	var best_hp := 14.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= 300.0 and e.hp > best_hp:
			best_hp = e.hp
			best = e
	if best == null:
		return
	best.apply_vuln(1.5, 4.0)
	deal(best, 14.0 * fam_power.drain, "necrotic", "drain")
	Fx.floating_text(best.global_position + Vector2(0, -18), "withered", Config.FAMILY_COLORS.drain)


func _handle_frost(delta: float) -> void:
	if not has_frost_pulse:
		return
	frost_timer -= delta
	if frost_timer > 0.0:
		return
	frost_timer = 2.6 * attack_speed_mult
	var pulse_radius := 135.0 * control_radius_mult
	var slow_factor := maxf(0.25, 0.55 - 0.05 * chill_level)
	var any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= pulse_radius:
			e.apply_slow(slow_factor, 2.0)
			deal(e, 3.0 * fam_power.control, "frost", "control")
			any = true
	if any:
		var ring := RingFx.new()
		ring.max_radius = pulse_radius
		ring.color = Config.FAMILY_COLORS.control
		ring.global_position = global_position
		projectile_parent.add_child(ring)


func _handle_dread(delta: float) -> void:
	if not has_dread:
		return
	dread_timer -= delta
	if dread_timer > 0.0:
		return
	dread_timer = 5.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_boss and global_position.distance_to(e.global_position) <= 210.0:
			e.apply_fear(1.6)


func _handle_mark(delta: float) -> void:
	if not has_mark:
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


func _handle_wisp(delta: float) -> void:
	if wisp_count <= 0:
		return
	wisp_timer -= delta
	if wisp_timer > 0.0:
		return
	wisp_timer = 1.0 * wisp_speed_mult * attack_speed_mult
	for i in wisp_count:
		var target := _nearest_enemy_in(420.0)
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
	if not has_hex:
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


# --- Ward reactions ------------------------------------------------------------------
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
	# Crowd contact: strongest toucher at full, the rest add partially — being
	# buried in a horde is lethal, one husk brushing you is not.
	var strongest := 0.0
	var others := 0.0
	for id in _overlapping:
		var e = _overlapping[id]
		if is_instance_valid(e):
			var d: float = e.eff_damage()
			if d > strongest:
				others += strongest
				strongest = d
			else:
				others += d
	var dmg := minf(strongest + others * Config.CONTACT_CROWD_FACTOR, Config.CONTACT_CROWD_CAP)
	if dmg > 0.0:
		take_damage(dmg)
		if thorns_damage > 0.0:
			for id in _overlapping.keys():
				var e = _overlapping[id]
				if is_instance_valid(e):
					deal(e, thorns_damage * fam_power.ward, "reflect", "ward")
		contact_timer = contact_tick


func take_damage(amount: float) -> void:
	if dead or invuln_t > 0.0:
		return
	if dodge_chance > 0.0 and randf() < dodge_chance:
		Fx.floating_text(global_position + Vector2(0, -24), "dodged", Config.FAMILY_COLORS.sight)
		RunLog.bump("damage_taken", "dodged", amount)
		return
	if Sim.enabled:
		Sim.note_damage(max(0.0, amount - armor))
		return
	var remaining := maxf(0.0, amount - armor)
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


## Quiet heal for per-hit lifesteal (no flash spam).
func leech_heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)
	RunLog.bump("healing", "leech", amount)


func _on_hurt_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		_overlapping[e.get_instance_id()] = e


func _on_hurt_area_exited(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		_overlapping.erase(e.get_instance_id())


# --- Boosts -----------------------------------------------------------------------------
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


# --- Vital + deepening cards --------------------------------------------------------------
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
		"blast_hotter":
			fam_power.blast *= 1.25
		"blast_wider":
			blast_radius_mult *= 1.20
		"ward_denser":
			shield_max += 12.0
			shield_regen += 1.5
		"ward_sharper":
			thorns_damage = maxf(thorns_damage * 1.4, 4.0)
			fam_power.ward *= 1.15
		"drain_deeper":
			fam_power.drain *= 1.25
		"drain_thicker":
			siphon_pct += 0.02
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
