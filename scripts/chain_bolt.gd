class_name ChainBolt
extends Node2D
## Visual for a chain-lightning zap: a jagged polyline through the hit points,
## fading out quickly.

var points: PackedVector2Array
var color := Color(0.7, 0.9, 1.0)


func _ready() -> void:
	z_index = 9
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if points.size() < 2:
		return
	# points are in world space; this node sits at origin.
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], color, 3.0, true)
		draw_circle(points[i + 1], 4.0, color)
