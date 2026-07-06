class_name Projectile
extends Area2D
## A flying bolt. The cantrip's Force Bolt by default (arcane); wisps fire
## physical ones. With Blast tier 1+ bolts detonate in a Fireburst AoE.

var damage := 3.0
var speed := 520.0
var direction := Vector2.RIGHT
var life := 1.4
var pierce := 0
var radius := 5.0
var explode_radius := 0.0
var explode_factor := 0.6
var dtype := "arcane"
var fam := ""             # family credited when routed through the player
var slow_factor := 1.0    # <1: chills what it hits
var leech := 0.0          # >0: Leech Bolt heals the caster this fraction of damage
var execute_hp := 0.0     # >0: True Bolt deals 1.5x to targets at/above this hp
var tint := Color(1.0, 1.0, 0.65)
var source: Node
var _hit: Dictionary = {}


func _ready() -> void:
	z_index = 8
	collision_layer = 8
	collision_mask = 2 | 16
	monitoring = true
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	# Fixed-step motion: identical trajectories at any sim speed (no tunneling).
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if not (e is Enemy):
		return
	var eid := e.get_instance_id()
	if _hit.has(eid):
		return
	_hit[eid] = true
	var dmg := damage
	if execute_hp > 0.0 and e.hp >= execute_hp:
		dmg *= 1.5  # the sniper's niche: punish the big ones
	_deal(e, dmg)
	if slow_factor < 1.0:
		e.apply_slow(slow_factor, 1.6)
	if explode_radius > 0.0:
		_explode(e.global_position, eid)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


func _deal(e, amount: float) -> void:
	if source != null and is_instance_valid(source) and source.has_method("deal"):
		# route through the player so crits/siphon/shatter/insight apply;
		# global mults are baked into `damage`, divide them back out
		var base: float = amount / max(source.damage_mult * source.boost_dmg, 0.001)
		var credit := fam
		if credit == "" and explode_radius > 0.0:
			credit = "blast"
		var applied: float = source.deal(e, base, dtype, credit)
		if leech > 0.0 and applied > 0.0:
			source.leech_heal(applied * leech)
	else:
		e.take_damage(amount, dtype)


func _explode(pos: Vector2, exclude_id: int) -> void:
	for e2 in get_tree().get_nodes_in_group("enemies"):
		if e2.get_instance_id() == exclude_id:
			continue
		if pos.distance_to(e2.global_position) <= explode_radius:
			_deal(e2, damage * explode_factor)
	var ring := RingFx.new()
	ring.max_radius = explode_radius
	ring.color = Config.FAMILY_COLORS.blast
	ring.global_position = pos
	get_parent().add_child(ring)


func _on_body_entered(_body: Node) -> void:
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
