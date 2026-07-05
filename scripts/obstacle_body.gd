class_name ObstacleBody
extends StaticBody2D
## A solid building/rock the player collides with. Layer 16 (obstacle).

var size := Vector2(80, 80)
var color := Color(0.2, 0.2, 0.26)


func _ready() -> void:
	z_index = 1
	collision_layer = 16
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, color)
	draw_rect(r, Color(0.42, 0.42, 0.52), false, 2.0)
