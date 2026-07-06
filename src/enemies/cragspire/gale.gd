class_name Gale
extends Enemy
## Cragspire flyer: circles in over the buildings, peppering light shots.


func _init() -> void:
	arch = "gale"
	display_name = "Gale"
	base_hp = 5.0
	speed = 135.0
	damage = 4.0
	radius = 8.0
	xp_tier = "small"
	flies = true
	shot_range = 300.0
	shot_interval = 4.0
	shot_speed = 210.0


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_shot_timer -= delta
	if _shot_timer <= 0.0 and to_p.length() <= shot_range:
		_shot_timer = shot_interval
		_fire_shot(to_p.normalized())
	return to_p.normalized()


func _draw_marks() -> void:
	draw_line(Vector2(-radius * 0.9, -radius * 0.5), Vector2(0, 0), Color(1, 1, 1, 0.4), 2.0)
	draw_line(Vector2(radius * 0.9, -radius * 0.5), Vector2(0, 0), Color(1, 1, 1, 0.4), 2.0)
