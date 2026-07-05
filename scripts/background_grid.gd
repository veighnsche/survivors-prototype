class_name BackgroundGrid
extends Node2D
## A world-space grid that follows the player so movement reads on the
## otherwise-empty infinite field.

var target: Node2D
var cell := 64.0
var line_color := Color(1, 1, 1, 0.05)
var tint_color := Color(0.9, 0.3, 0.28)  # set by the run director to the current biome color
var _shown_tint := Color(0.9, 0.3, 0.28)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
		_shown_tint = _shown_tint.lerp(tint_color, minf(delta * 2.0, 1.0))
		queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var half := vp * 0.65  # cover a bit more than the screen
	var left := -half.x
	var right := half.x
	var top := -half.y
	var bottom := half.y

	# Soft biome tint so you can read which region you're in at a glance.
	draw_rect(Rect2(left, top, right - left, bottom - top), Color(_shown_tint.r, _shown_tint.g, _shown_tint.b, 0.045))

	# Offset the lines by the world position so the grid appears to scroll.
	var ox := fposmod(global_position.x, cell)
	var oy := fposmod(global_position.y, cell)

	var x := left - ox
	while x <= right:
		draw_line(Vector2(x, top), Vector2(x, bottom), line_color, 1.0)
		x += cell
	var y := top - oy
	while y <= bottom:
		draw_line(Vector2(left, y), Vector2(right, y), line_color, 1.0)
		y += cell
