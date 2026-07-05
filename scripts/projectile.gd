class_name Projectile
extends Area2D
## Straight-flying ranged shot. Damages enemies it touches; despawns once its
## pierce budget is spent (pierce = extra enemies it can pass through).

var damage := 5.0
var speed := 520.0
var direction := Vector2.RIGHT
var life := 1.4
var pierce := 0
var radius := 5.0
var _hit: Dictionary = {}  # enemies already hit, so we don't double-tick one


func _ready() -> void:
	z_index = 8
	collision_layer = 8
	collision_mask = 2 | 16  # enemy hitboxes (2) + buildings (16)
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
	e.take_damage(damage)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	# Blocked by a building — despawn regardless of pierce budget.
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 0.65))
	draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
