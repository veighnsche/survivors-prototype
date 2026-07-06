class_name GoldCoin
extends Node2D
## A gold coin drop. Attracts to the player within pickup radius, banks into the
## run's gold on contact.

const ATTRACT_SPEED := 600.0
const COLLECT_DIST := 16.0

var value := 1
var player: Node2D
var game
var field  # LootField, if placed on the map
var origin_cell := Vector2i.ZERO
var attracting := false
var collected := false


func _ready() -> void:
	add_to_group("gold")  # so the Magnet lure can pull coins too
	z_index = 2
	queue_redraw()


func _process(delta: float) -> void:
	if collected:
		return
	if player != null and is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		if d <= COLLECT_DIST:
			collected = true
			if game != null:
				game.add_run_gold(value)
			if field != null:
				field.on_collected(origin_cell)
			queue_free()
			return
		if attracting or d <= player.pickup_radius:
			attracting = true
			global_position = global_position.move_toward(player.global_position, ATTRACT_SPEED * delta)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.82, 0.2))
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 14, Color(0.7, 0.5, 0.05), 1.5)
