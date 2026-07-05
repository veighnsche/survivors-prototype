class_name Projectile
extends Area2D
## Straight-flying auto-attack shot. Damages the first enemy it touches, then
## despawns. No pierce in M1.

var damage := 4.0
var speed := 520.0
var direction := Vector2.RIGHT
var life := 1.4
var radius := 5.0


func _ready() -> void:
	z_index = 8
	collision_layer = 8
	collision_mask = 2  # hits enemy hitboxes
	monitoring = true
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy:
		e.take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 0.65))
	draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
