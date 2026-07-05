class_name BoostTimers
extends Control
## Circular countdowns for the player's active temporary boosts. Each active
## boost is a ring that depletes as its timer runs out, bottom-center of screen.

var player: Node2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var boosts: Array = player.active_boosts()
	if boosts.is_empty():
		return

	var vp := get_viewport_rect().size
	var r := 22.0
	var spacing := 58.0
	var total_w := spacing * (boosts.size() - 1)
	var start := Vector2(vp.x * 0.5 - total_w * 0.5, vp.y - 58.0)

	for i in boosts.size():
		var b = boosts[i]
		var center := start + Vector2(spacing * i, 0.0)
		var col: Color = b.color
		var frac: float = clampf(b.frac, 0.0, 1.0)
		var letter: String = b.letter

		draw_circle(center, r, Color(0, 0, 0, 0.5))
		draw_arc(center, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.3), 2.0)
		if frac > 0.0:
			draw_arc(center, r - 4.0, -PI / 2.0, -PI / 2.0 + frac * TAU, 48, col, 5.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 6), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
