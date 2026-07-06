class_name Player
extends CharacterBody2D
## The tabula-rasa caster.
## - BASIC ATTACKS are Cantrip objects (src/cantrips/), awakened by surviving
##   in biomes (insight from gems). One fires per cast cycle — the brain
##   scores every available cantrip and casts the mathematically best one.
## - SKILLS are Skill objects (src/skills/), never automatic: level-up cards,
##   gated by how deep your insight in that family runs.

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
var skills: Array = []      # the committed Skill instances; ticked every frame
# Stats the skills grant. Wiped and re-applied by the rebuild after a forget.
var shield_max := 0.0
var shield_hp := 0.0
var shield_regen := 0.0
var thorns_damage := 0.0
var deflect_chance := 0.0
var siphon_pct := 0.0
var rot_radius := 0.0       # Rot aura reach (also drawn as a ring)
var has_shatter := false
var crit_chance := 0.0
var crit_mult := 2.0
var dodge_chance := 0.0
var wisp_count := 0
var wisp_ticker: Skill = null  # which skill instance owns the wisp volley
var wisp_speed_mult := 1.0

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
var _bot: SimBot = null


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
	for s in skills:
		s.tick(self, delta)
	_handle_contact(delta)


# --- Input -------------------------------------------------------------------------
func _input_vector() -> Vector2:
	if Sim.enabled:
		if _bot == null:
			_bot = SimBot.new()
		return _bot.steer(self)
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
	# Diminishing returns: the deeper a family, the less each gem teaches.
	# Early curve (awakening) is untouched; T3 becomes a real commitment
	# instead of a byproduct of the late-game kill-rate explosion.
	var cap: float = Config.INSIGHT_TIERS[Config.INSIGHT_TIERS.size() - 1]
	amount *= maxf(0.05, 1.0 - float(insight[fam]) / (cap * 1.05))
	insight[fam] = float(insight[fam]) + amount
	if insight_tier(fam) >= 1 and not awakened_fams[fam]:
		awakened_fams[fam] = true
		RunLog.event("%s AWAKENED — basic attack: %s" % [Families.display_name(fam), Cantrips.of(fam).display_name])
		awakened.emit(fam)
		Fx.shake(0.4)
		queue_redraw()


var meta_bolt_bonus := 0  # Twin Bolt powerup, survives skill rebuilds


## Wipe everything skills grant, so the remaining set can be re-applied cleanly
## after forgetting one (skills and boost cards overlap — rebuild, don't reverse).
func reset_skill_state() -> void:
	skills.clear()
	shield_max = 0.0
	shield_regen = 0.0
	shield_hp = 0.0
	thorns_damage = 0.0
	deflect_chance = 0.0
	siphon_pct = 0.0
	rot_radius = 0.0
	has_shatter = false
	crit_chance = 0.0
	dodge_chance = 0.0
	wisp_count = 0
	wisp_ticker = null
	bolt_count = 1 + meta_bolt_bonus
	queue_redraw()


## Skill cards call this — nothing here is ever granted automatically.
func unlock_skill(fam: String, key: String, quiet: bool = false) -> void:
	var scr := Families.of(fam).skill_script(key)
	if scr == null:
		return
	var sk: Skill = scr.new()
	sk.apply(self)
	skills.append(sk)
	if not quiet:
		RunLog.event("skill unlocked: %s/%s" % [fam, key])
	queue_redraw()


## Central damage funnel: mults, crits, Shatter, siphon, use-deepens insight.
## Returns the damage actually applied (leech etc. build on it).
func deal(e, base: float, dtype: String, fam: String) -> float:
	if e == null or not is_instance_valid(e):
		return 0.0
	if e.slow_t > 0.0 and has_shatter:
		base *= Shatter.BONUS
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
## Expected damage of a hit on this enemy (resists, vulns, Shatter).
func est(e, base: float, dtype: String) -> float:
	var v: float = base * e.damage_mult_for(dtype)
	if e.slow_t > 0.0 and has_shatter:
		v *= Shatter.BONUS
	return v


## Expected damage capped at the enemy's remaining HP — overkill is worthless,
## so nuking a swarm of near-dead mites no longer inflates a score.
func est_capped(e, base: float, dtype: String) -> float:
	return minf(est(e, base, dtype), maxf(e.hp, 0.0))


func _available_basics() -> Array:
	var out: Array = ["force"]
	for fam in awakened_fams:
		if awakened_fams[fam]:
			out.append(fam)
	return out


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
		var c := Cantrips.of(key)
		var res := c.score(self)
		var sc := float(res.score)
		# Home-turf attunement: lean toward the attack this biome teaches.
		if key == Biomes.of(current_biome).family:
			sc *= Config.BIOME_ATTUNE_BIAS
		# Normalize by cooldown: value per commitment, not per splash fantasy.
		sc /= pow(maxf(c.cd_for(self), 0.3), Config.SCORE_CD_EXPONENT)
		report.append({"name": c.display_name, "score": sc,
			"home": Biomes.of(current_biome).family == key, "picked": false,
			"no_target": sc <= 0.0})
		if sc > best_score:
			best_score = sc
			best = key
			best_target = res.get("target")

	if best != "":
		var chosen := Cantrips.of(best)
		for entry in report:
			if entry.name == chosen.display_name:
				entry.picked = true
		chosen.cast(self, best_target)
		RunLog.bump("basic_casts", chosen.display_name)
		# THE cost: everything is silenced for this cantrip's cooldown.
		cast_cd = chosen.cd_for(self) * attack_speed_mult * boost_rate
	brain_report = report


func nearest_enemy_in(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach * reach
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- Ward reactions ------------------------------------------------------------------
func try_deflect_shot(pos: Vector2) -> bool:
	if deflect_chance > 0.0 and randf() < deflect_chance:
		Fx.death_pop(pos, Families.color("ward"))
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
	var strongest_name := "contact"
	for id in _overlapping:
		var e = _overlapping[id]
		if is_instance_valid(e):
			var d: float = e.eff_damage()
			if d > strongest:
				others += strongest
				strongest = d
				strongest_name = e.display_name
			else:
				others += d
	var dmg := minf(strongest + others * Config.CONTACT_CROWD_FACTOR, Config.CONTACT_CROWD_CAP)
	if dmg > 0.0:
		take_damage(dmg, strongest_name + " (contact)")
		if thorns_damage > 0.0:
			for id in _overlapping.keys():
				var e = _overlapping[id]
				if is_instance_valid(e):
					deal(e, thorns_damage * fam_power.ward, "reflect", "ward")
		contact_timer = contact_tick


func take_damage(amount: float, src: String = "?") -> void:
	if dead or invuln_t > 0.0:
		return
	RunLog.bump("threat_by_source", src, amount)  # WHO is actually hurting the player
	if dodge_chance > 0.0 and randf() < dodge_chance:
		Fx.floating_text(global_position + Vector2(0, -24), "dodged", Families.color("sight"))
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
		out.append({"name": "Barrier", "secs": bonus_shield, "frac": clampf(bonus_shield / BarrierCharm.BARRIER, 0.0, 1.0), "color": Color(0.92, 0.9, 0.5)})
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


## Pickup flash — the charms (src/loot/) set their own boost fields, then call
## this for the shared juice.
func boost_flash() -> void:
	modulate = Color(1.4, 1.4, 0.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)


# --- Vital + deepening cards --------------------------------------------------------------
## Dispatch only: Vital cards are owned by Upgrades (src/meta/upgrades.gd),
## family deepening cards by their Family (src/families/).
func apply_upgrade(id: String) -> void:
	if Upgrades.apply(self, id):
		return
	for fam in Families.ids():
		if Families.of(fam).apply_minor(self, id):
			return


func _draw() -> void:
	if rot_radius > 0.0:
		draw_circle(Vector2.ZERO, rot_radius, Color(0.44, 0.69, 0.23, 0.05))
		draw_arc(Vector2.ZERO, rot_radius, 0.0, TAU, 40, Color(0.44, 0.69, 0.23, 0.3), 2.0)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 2.0)
	if shield_max > 0.0:
		var frac := shield_hp / shield_max
		draw_arc(Vector2.ZERO, radius + 6.0, -PI / 2.0, -PI / 2.0 + frac * TAU, 30, Families.color("ward"), 2.5)
	if bonus_shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 30, Color(0.92, 0.9, 0.5, 0.8), 2.5)
