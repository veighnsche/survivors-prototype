class_name RingFx
extends Node2D
## Expanding, fading ring — used by AoE skills (Nova, Frost Ring).

const DUR := 0.3

var max_radius := 100.0
var color := Color.WHITE
var _life := 0.0


func _ready() -> void:
	z_index = 4
	queue_redraw()


func _process(delta: float) -> void:
	_life += delta
	var t := _life / DUR
	if t >= 1.0:
		queue_free()
		return
	modulate.a = 1.0 - t
	queue_redraw()


func _draw() -> void:
	var r: float = max(max_radius * (_life / DUR), 1.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, color, 4.0)
