class_name Booster
extends Node2D
## Base floor treasure, collected by touch. Every booster is its own file in
## src/loot/ (registered in LootField.BOOSTERS) and sets its identity in
## _init() plus what happens on pickup in _apply().

const TOUCH := 28.0

var label := "?"          # readable name floating above the token
var letter := "?"         # the letter on the token
var color := Color.WHITE

var player: Node2D
var game
var field  # LootField, if placed on the map
var origin_cell := Vector2i.ZERO


func _ready() -> void:
	z_index = 3
	add_to_group("guided")
	queue_redraw()


func indicator_color() -> Color:
	return color


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= TOUCH:
			_collect()


func _collect() -> void:
	_apply()
	Fx.death_pop(global_position, color)
	if field != null:
		field.on_collected(origin_cell)
	queue_free()


## What this booster does when touched.
func _apply() -> void:
	pass


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, color)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 22, Color(1, 1, 1, 0.85), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-5, 6), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.12))
	draw_string(ThemeDB.fallback_font, Vector2(-60, -20), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, color)
