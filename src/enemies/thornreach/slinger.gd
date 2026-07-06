class_name Slinger
extends Enemy
## Thornreach kiter: shoots and keeps its distance — and LEADS the target.


func _init() -> void:
	arch = "slinger"
	display_name = "Slinger"
	base_hp = 7.0
	speed = 90.0
	damage = 5.0
	radius = 10.0
	xp_tier = "medium"
	shot_range = 320.0
	shot_interval = 3.4
	shot_speed = 250.0


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	var d := to_p.length()
	_shot_timer -= delta
	if _shot_timer <= 0.0 and d <= shot_range * 1.1:
		_shot_timer = shot_interval
		var lead: Vector2 = to_p + target.velocity * (d / shot_speed) * 0.8
		_logmech("slinger:lead_shot")
		_fire_shot(lead.normalized())
	if d > shot_range * 0.85:
		return to_p.normalized()
	elif d < shot_range * 0.45:
		return -to_p.normalized()
	else:
		return to_p.normalized().rotated(PI / 2.0) * _strafe_dir


func _draw_marks() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 0.85, 0.9))
