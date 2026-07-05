class_name BeamFx
extends Node2D
## Fading beam line for the Railgun. Points are world-space (node sits at origin).

var from := Vector2.ZERO
var to := Vector2.ZERO
var width := 20.0
var color := Color(1.0, 0.5, 0.85)


func _ready() -> void:
	z_index = 8
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_line(from, to, Color(color.r, color.g, color.b, 0.8), width, true)
	draw_line(from, to, Color(1, 1, 1, 0.9), width * 0.35, true)
