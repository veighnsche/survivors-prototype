class_name WeaponPickup
extends Node2D
## A weapon lying on the ground. Not auto-collected — the player presses E while
## standing over it to swap. Beaconed like other loot.

var weapon_kind := "ranged"
var player: Node2D


func _ready() -> void:
	z_index = 4
	add_to_group("weapon_drops")
	add_to_group("guided")  # gets an off-screen beacon
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()  # cheap; refreshes the [E] prompt when the player is near


func consume() -> void:
	queue_free()


func indicator_color() -> Color:
	return Config.WEAPONS[weapon_kind].color


func _draw() -> void:
	var c: Color = Config.WEAPONS[weapon_kind].color
	var wname: String = Config.WEAPONS[weapon_kind].name
	draw_circle(Vector2.ZERO, 14.0, Color(0.1, 0.1, 0.12))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 26, c, 3.0)
	var letter: String = {"ranged": "R", "melee": "C", "chain": "T"}.get(weapon_kind, "?")
	draw_string(ThemeDB.fallback_font, Vector2(-5, 6), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
	draw_string(ThemeDB.fallback_font, Vector2(-60, -22), wname, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, c)
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) < Config.WEAPON_PICKUP_RADIUS:
			draw_string(ThemeDB.fallback_font, Vector2(-40, 34), "[E] swap", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1, 1, 1, 0.9))
