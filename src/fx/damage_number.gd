class_name DamageNumber
extends Node2D
## Floating damage readout. Rises and fades, then frees itself.

var amount := 0.0
var text_override := ""
var color := Color(1.0, 0.95, 0.6)
var _text := ""


func _ready() -> void:
	z_index = 20
	_text = text_override if text_override != "" else str(int(round(amount)))
	queue_redraw()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(0, -26), 0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-6, 0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
