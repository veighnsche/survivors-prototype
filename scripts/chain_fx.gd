class_name ChainFx
extends Node2D
## Jagged lightning polyline through the chain's hit points, fading fast.
## World-space points; the node sits at origin.

var points: PackedVector2Array
var color := Color(0.7, 0.85, 1.0)


func _ready() -> void:
	z_index = 9
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if points.size() < 2:
		return
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var mid := (a + b) * 0.5 + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		draw_polyline(PackedVector2Array([a, mid, b]), color, 3.0, true)
		draw_circle(b, 4.0, color)
