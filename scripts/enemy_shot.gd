class_name EnemyShot
extends Area2D
## A skirmisher's projectile. Hurts the player on contact; blocked by buildings;
## can be negated by Ward's Deflect.

var damage := 7.0
var speed := 300.0
var direction := Vector2.RIGHT
var life := 3.0


func _ready() -> void:
	z_index = 7
	collision_layer = 0
	collision_mask = 4 | 16  # player hurtbox (4) + buildings (16)
	monitoring = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 5.0
	cs.shape = sh
	add_child(cs)
	area_entered.connect(_on_area_entered)
	body_entered.connect(func(_b): queue_free())
	queue_redraw()


func _process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var p := area.get_parent()
	if p is Player:
		if p.try_deflect_shot(global_position):
			pass  # warded off
		else:
			p.take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.95, 0.75, 0.35))
	draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 0.85))
