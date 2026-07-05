class_name Chest
extends Node2D
## A treasure chest dropped by elites/boss. Collected by touch; grants a burst of
## level-ups + gold.

const TOUCH := 32.0

var player: Node2D
var game
var field  # LootField, if placed on the map
var origin_cell := Vector2i.ZERO


func _ready() -> void:
	z_index = 3
	add_to_group("guided")
	queue_redraw()


func indicator_color() -> Color:
	return Color(0.95, 0.78, 0.28)


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= TOUCH:
			_open()


func _open() -> void:
	if game != null:
		game.open_chest(global_position)
	if field != null:
		field.on_collected(origin_cell)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-15, -11, 30, 22), Color(0.5, 0.32, 0.15))
	draw_rect(Rect2(-15, -11, 30, 22), Color(0.9, 0.68, 0.22), false, 2.5)
	draw_rect(Rect2(-15, -3, 30, 5), Color(0.9, 0.68, 0.22))
	draw_circle(Vector2(0, 0), 2.5, Color(0.95, 0.85, 0.35))
