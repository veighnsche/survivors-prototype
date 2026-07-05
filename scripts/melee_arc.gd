class_name MeleeArc
extends Node2D
## Short-lived visual wedge for a melee swing. Draws a fading cone in the aim
## direction, then frees itself. Purely cosmetic — damage is applied instantly
## by the player's cone query.

var aim := Vector2.RIGHT
var reach := 132.0
var half_angle := 0.9  # radians
var color := Color(0.95, 0.97, 1.0, 0.45)


func _ready() -> void:
	z_index = 9
	rotation = aim.angle()
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 14
	for i in steps + 1:
		var a: float = lerp(-half_angle, half_angle, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(pts, color)
