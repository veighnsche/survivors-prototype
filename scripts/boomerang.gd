class_name Boomerang
extends Area2D
## Thrown weapon: flies out to its reach, then returns to the (moving) player,
## piercing enemies on both passes. Hits each enemy once per pass.

var damage := 6.0
var speed := 660.0
var reach := 380.0
var direction := Vector2.RIGHT
var player: Node2D

var _origin := Vector2.ZERO
var _returning := false
var _hit: Dictionary = {}


func _ready() -> void:
	z_index = 8
	collision_layer = 8
	collision_mask = 2  # enemies only (flies over walls so it can't get stuck)
	monitoring = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 10.0
	cs.shape = sh
	add_child(cs)
	area_entered.connect(_on_area_entered)
	_origin = global_position
	queue_redraw()


func _process(delta: float) -> void:
	rotation += delta * 14.0
	if not _returning:
		position += direction * speed * delta
		if global_position.distance_to(_origin) >= reach:
			_returning = true
			_hit.clear()  # allow a second hit on the way back
	else:
		if player == null or not is_instance_valid(player):
			queue_free()
			return
		var to_p := player.global_position - global_position
		if to_p.length() <= 18.0:
			queue_free()
			return
		position += to_p.normalized() * speed * delta


func _on_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if e is Enemy and not _hit.has(e.get_instance_id()):
		_hit[e.get_instance_id()] = true
		e.take_damage(damage)


func _draw() -> void:
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU * 0.7, 16, Color(0.55, 0.85, 0.4), 3.5)
