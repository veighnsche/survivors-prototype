class_name Enemy
extends CharacterBody2D
## Base creature. Shared plumbing lives here — territory rules, status effects,
## the damage funnel, the movement driver, obstacle avoidance, the body draw.
## Every creature is its own subclass file in src/enemies/<biome>/ (registered
## in EnemyTypes) and overrides the hooks at the bottom:
##   _init()        its stats
##   _brain()       how it moves and attacks (returns a movement direction)
##   _tick()        housekeeping that runs even while parked (timers, broods)
##   _state_speed() speed of its behavior states (0 = rooted)
##   _incoming()    resist/immunity gate on damage about to land
##   _cheat_death() a chance to avert a lethal hit
##   _on_hit()      reaction to being struck
##   _can_touch()   whether contact/shot damage applies right now
##   _pre_draw()    under-layers (shadows, telegraphs); false = hide the body
##   _draw_marks()  identity marks on top of the body

signal died

const AVOID_DIST := 64.0           # obstacle-avoidance raycast length
const GUARD_AGGRO := 340.0         # guards engage within this range, else hold post
const SELF_DEFENSE_RADIUS := 240.0 # strays fight back if you're this close

# --- Identity (set by each subclass in _init) ---------------------------------
var arch := ""             # registry id, e.g. "husk"
var display_name := "?"
var base_hp := 5.0
var hp := 5.0
var speed := 100.0
var damage := 5.0
var radius := 10.0
var xp_tier := "small"
var flies := false         # soars over buildings: no obstacle avoidance

# Ranged-attack knobs (any subclass that shoots sets these in _init)
var shot_range := 0.0
var shot_interval := 0.0
var shot_speed := 0.0

# --- Run wiring (set by setup()) ----------------------------------------------
var biome := "commons"
var resists: Dictionary = {}
var color := Color(0.86, 0.36, 0.36)
var is_boss := false
var guard := false         # entrance guard: holds its post, engages only up close
var target: Node2D
var biome_map: BiomeMap    # for territory checks
var home_pos := Vector2.ZERO

# --- Territory ------------------------------------------------------------------
var _outside := false      # outside its home biome -> weakened, heads home
var _outside_t := 0.0      # how long it has been astray (fades away eventually)
var _territory_timer := 0.0

# --- Status effects ---------------------------------------------------------------
var slow_mult := 1.0
var slow_t := 0.0
var haste_mult := 1.0      # Howler war-cries speed the pack up
var haste_t := 0.0
var vuln_mult := 1.0
var vuln_t := 0.0
var feared_t := 0.0

# --- Behavior state shared by subclass brains --------------------------------------
var _bstate := ""
var _btimer := 0.0
var _lock_dir := Vector2.ZERO
var _lock_pos := Vector2.ZERO
var _shot_timer := 0.0
var _strafe_dir := 1.0
var _last_state := ""      # for logging behavior-state transitions

var _dead := false
var _dmg_accum := 0.0
var _dmg_cd := 0.0


## Wire this creature into a run: home biome, target, difficulty scale.
func setup(biome_id: String, tgt: Node2D, hp_scale: float) -> void:
	biome = biome_id
	target = tgt
	hp = base_hp * hp_scale
	var b := Biomes.of(biome_id)
	resists = b.resists
	color = b.color.lightened(0.15) if is_boss else b.color.darkened(0.15)
	if shot_interval > 0.0:
		_shot_timer = randf_range(0.5, shot_interval)
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
	_tick_statuses(delta)

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

	_tick(delta)
	if _autonomous():
		return  # the subclass moved (or parked) itself

	var dir := _direction(delta)
	# Prove mechanics fire: log every behavior-state transition (leaps, dives,
	# burrows, pounces, hit-and-runs all pass through _bstate).
	if _bstate != _last_state:
		if _bstate != "" and _bstate != "cooldown" and _bstate != "recover" and _bstate != "fly":
			_logmech("%s:%s" % [arch, _bstate])
		_last_state = _bstate
	if not flies:
		dir = _avoid_obstacles(dir)
	velocity = dir * speed * slow_mult * haste_mult * _state_speed()
	move_and_slide()


func _tick_statuses(delta: float) -> void:
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
	if vuln_t > 0.0:
		vuln_t -= delta
		if vuln_t <= 0.0:
			vuln_mult = 1.0
	if haste_t > 0.0:
		haste_t -= delta
		if haste_t <= 0.0:
			haste_mult = 1.0
	if feared_t > 0.0:
		feared_t -= delta


## Shared movement priorities: fear beats everything, guards hold their post,
## strays disengage toward home — otherwise the subclass brain decides.
func _direction(delta: float) -> Vector2:
	var to_p := to_player()
	if feared_t > 0.0:
		return -to_p.normalized()  # Dread: flee
	# Entrance guards hold their post; they only engage up close.
	if guard and to_p.length() > GUARD_AGGRO:
		if global_position.distance_to(home_pos) > 40.0:
			return (home_pos - global_position).normalized()
		return Vector2.ZERO
	# Outside home turf: disengage and head home (unless the player is right on
	# top of us — then fight back). Prevents dragging enemies out to farm them.
	if _outside and to_p.length() > SELF_DEFENSE_RADIUS:
		return (home_pos - global_position).normalized()
	return _brain(delta)


# --- Status appliers ------------------------------------------------------------
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


# --- Damage ------------------------------------------------------------------------
## Contact/shot damage right now — softer when fighting away from home turf.
## Phased states (underground, airborne, a bone pile) can't touch you at all.
func eff_damage() -> float:
	if not _can_touch():
		return 0.0
	return damage * (Config.OUT_OF_BIOME_DMG if _outside else 1.0)


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
	amount = _incoming(amount, dtype)
	if amount <= 0.0:
		return 0.0
	var applied := amount * damage_mult_for(dtype)
	if Sim.enabled:
		Sim.damage_dealt += applied
	if hp - applied <= 0.0 and _cheat_death(applied):
		return applied
	_on_hit()
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


# --- Shared helpers for subclasses ---------------------------------------------------
func to_player() -> Vector2:
	return target.global_position - global_position


func _logmech(tag: String) -> void:
	RunLog.bump("mech_fired", tag)


func _fire_shot(dir: Vector2) -> void:
	var s := EnemyShot.new()
	s.damage = eff_damage()
	s.src = display_name
	s.speed = shot_speed
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
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * AVOID_DIST, 16)
	var hit := space.intersect_ray(q)
	if hit:
		var n: Vector2 = hit.normal
		var slid := dir - n * dir.dot(n)
		_avoid_cached = slid.normalized() if slid.length() > 0.05 else Vector2(-n.y, n.x)
	else:
		_avoid_cached = Vector2.ZERO
		return dir
	return _avoid_cached


func _draw() -> void:
	if not _pre_draw():
		return
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.35), 2.0)
	_draw_marks()


# --- Subclass hooks --------------------------------------------------------------
## The creature's instincts. Returns the direction it wants to move.
func _brain(_delta: float) -> Vector2:
	return to_player().normalized()


## Housekeeping that must run even while parked (defensive timers, broods).
func _tick(_delta: float) -> void:
	pass


## Return true when the subclass fully owns movement this frame (bosses,
## inert states) — the base driver then stays out of the way.
func _autonomous() -> bool:
	return false


## Speed of the current behavior state (0 roots the body in place).
func _state_speed() -> float:
	return 1.0


## Gate on damage about to land: immunities return 0, armor reduces.
func _incoming(amount: float, _dtype: String) -> float:
	return amount


## Last chance to avert a lethal hit (return true if death was cheated).
func _cheat_death(_applied: float) -> bool:
	return false


## Reaction to being struck (curl up, retaliate...).
func _on_hit() -> void:
	pass


## Whether contact/shot damage applies right now (false while phased out).
func _can_touch() -> bool:
	return true


## Draw under-layers (shadows, telegraphs). Return false to hide the body.
func _pre_draw() -> bool:
	return true


## Identity marks drawn on top of the body circle.
func _draw_marks() -> void:
	pass


## Death effects owned by the creature (Bonepile's burst, Broodmother's brood).
## Called by the run director after the kill is counted.
func on_death(_game) -> void:
	pass
