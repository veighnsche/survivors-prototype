class_name Volleyer
extends Enemy
## Thornreach turret: roots in place and fires 3-shot fans when in range.

const BURST := 3


func _init() -> void:
	arch = "volleyer"
	display_name = "Volleyer"
	base_hp = 12.0
	speed = 55.0
	damage = 5.0
	radius = 12.0
	xp_tier = "medium"
	shot_range = 360.0
	shot_interval = 4.2
	shot_speed = 235.0


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	if to_p.length() <= shot_range:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = shot_interval
			_logmech("volleyer:burst")
			var aim := to_p.normalized()
			for i in BURST:
				_fire_shot(aim.rotated(deg_to_rad(-12.0 + 12.0 * i)))
		return Vector2.ZERO
	return to_p.normalized()


func _draw_marks() -> void:
	draw_rect(Rect2(-4, -4, 8, 8), Color(0, 0, 0, 0.4))
