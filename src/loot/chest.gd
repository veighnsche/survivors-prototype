class_name Chest
extends Node2D
## A treasure chest dropped by elites/boss or found on the floor. Collected by
## touch; the chest owns its reward: gold + a heal + one auto-granted upgrade
## (never a skill — those stay the player's own choice at the card screen).

const TOUCH := 32.0
const GOLD := 2
const HEAL := 25.0

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
		RunLog.event("chest opened")
		Fx.death_pop(global_position, Color(0.95, 0.75, 0.25))
		Fx.shake(0.35)
		game.add_run_gold(GOLD)
		player.heal(HEAL)
		var reward: String = game.grant_random_upgrade()
		var label := "+%d gold" % GOLD
		if reward != "":
			label += "  •  " + reward
		Fx.floating_text(global_position + Vector2(0, -22), label, Color(1.0, 0.85, 0.4))
	if field != null:
		field.on_collected(origin_cell)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-15, -11, 30, 22), Color(0.5, 0.32, 0.15))
	draw_rect(Rect2(-15, -11, 30, 22), Color(0.9, 0.68, 0.22), false, 2.5)
	draw_rect(Rect2(-15, -3, 30, 5), Color(0.9, 0.68, 0.22))
	draw_circle(Vector2(0, 0), 2.5, Color(0.95, 0.85, 0.35))
	draw_string(ThemeDB.fallback_font, Vector2(-60, -22), "Chest", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.95, 0.78, 0.28))
