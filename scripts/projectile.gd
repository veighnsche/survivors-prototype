class_name Projectile
extends Area2D
## The cantrip's Force Bolt. Arcane damage; with Blast tier 1+ it detonates in a
## Fireburst AoE on impact.

var damage := 3.0
var speed := 520.0
var direction := Vector2.RIGHT
var life := 1.4
var pierce := 0
var radius := 5.0
var explode_radius := 0.0
var source: Node  # the Player, for siphon/insight feedback
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


func _process(delta: float) -> void:
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
	_deal(e, damage)
	if explode_radius > 0.0:
		_explode(e.global_position, eid)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


func _deal(e, amount: float) -> void:
	if source != null and is_instance_valid(source) and source.has_method("deal"):
		# route through the player so siphon/insight apply; damage_mult is
		# already baked into `damage`, so divide it back out
		var base: float = amount / max(source.damage_mult * source.boost_dmg, 0.001)
		source.deal(e, base, "arcane", "blast" if explode_radius > 0.0 else "")
	else:
		e.take_damage(amount, "arcane")


func _explode(pos: Vector2, exclude_id: int) -> void:
	for e2 in get_tree().get_nodes_in_group("enemies"):
		if e2.get_instance_id() == exclude_id:
			continue
		if pos.distance_to(e2.global_position) <= explode_radius:
			_deal(e2, damage * 0.6)
	var ring := RingFx.new()
	ring.max_radius = explode_radius
	ring.color = Config.FAMILY_COLORS.blast
	ring.global_position = pos
	get_parent().add_child(ring)


func _on_body_entered(_body: Node) -> void:
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 0.65))
	draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
