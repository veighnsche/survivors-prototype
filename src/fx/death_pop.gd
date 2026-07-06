class_name DeathPop
extends Node2D
## A quick expanding-and-fading ring on enemy death.

var color := Color.WHITE
var radius := 10.0


func _ready() -> void:
	z_index = 4
	queue_redraw()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.4, 2.4), 0.22)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.55))
