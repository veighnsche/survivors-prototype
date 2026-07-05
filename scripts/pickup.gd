class_name Pickup
extends Node2D
## A floor treasure the player collects by touch: Heal / Magnet / Bomb.

const TOUCH := 28.0

var kind := "heal"
var player: Node2D
var game
var field  # LootField, if placed on the map
var origin_cell := Vector2i.ZERO


func _ready() -> void:
	z_index = 3
	add_to_group("guided")
	queue_redraw()


func indicator_color() -> Color:
	return _color()


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= TOUCH:
			_collect()


func _collect() -> void:
	match kind:
		"heal":
			player.heal(Config.HEAL_AMOUNT)
		"magnet":
			game.vacuum_all_gems()
		"bomb":
			game.bomb()
		_:
			player.add_boost(kind)  # frenzy / power / haste / shield
	Fx.death_pop(global_position, _color())
	if field != null:
		field.on_collected(origin_cell)
	queue_free()


func _color() -> Color:
	match kind:
		"heal":
			return Color(0.4, 0.9, 0.45)
		"magnet":
			return Color(0.4, 0.72, 1.0)
		"bomb":
			return Color(0.96, 0.6, 0.22)
		"frenzy":
			return Color(0.95, 0.4, 0.32)
		"power":
			return Color(0.8, 0.42, 0.95)
		"haste":
			return Color(0.3, 0.9, 0.95)
		"shield":
			return Color(0.92, 0.9, 0.5)
	return Color.WHITE


func _draw() -> void:
	var c := _color()
	draw_circle(Vector2.ZERO, 12.0, c)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 22, Color(1, 1, 1, 0.85), 2.0)
	var letter: String = {"heal": "+", "magnet": "M", "bomb": "B", "frenzy": "F", "power": "P", "haste": "H", "shield": "S"}.get(kind, "?")
	draw_string(ThemeDB.fallback_font, Vector2(-5, 6), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.12))
	var pname: String = {"heal": "Heal", "magnet": "Magnet", "bomb": "Bomb", "frenzy": "Frenzy", "power": "Power", "haste": "Haste", "shield": "Barrier"}.get(kind, "?")
	draw_string(ThemeDB.fallback_font, Vector2(-60, -20), pname, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, c)
