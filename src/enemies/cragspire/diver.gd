class_name Diver
extends Enemy
## Cragspire striker: circles out of reach, then locks on and dives THROUGH you.

const DIVE_EVERY := 3.5
const DIVE_MULT := 3.2
const DIVE_TIME := 0.8


func _init() -> void:
	arch = "diver"
	display_name = "Diver"
	base_hp = 7.0
	speed = 120.0
	damage = 9.0
	radius = 9.0
	xp_tier = "medium"
	flies = true


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_btimer -= delta
	match _bstate:
		"diving":
			if _btimer <= 0.0:
				_bstate = ""
				_btimer = DIVE_EVERY
				queue_redraw()
			return _lock_dir
		_:
			if _btimer <= 0.0 and to_p.length() < 520.0:
				_bstate = "diving"
				_btimer = DIVE_TIME
				_lock_dir = to_p.normalized()
				queue_redraw()
				return _lock_dir
			if to_p.length() > 340.0:
				return to_p.normalized()
			return to_p.normalized().rotated(PI / 2.0) * _strafe_dir


func _state_speed() -> float:
	return DIVE_MULT if _bstate == "diving" else 1.0


func _draw_marks() -> void:
	draw_line(Vector2(-radius, -3), Vector2(radius, -3), Color(1, 1, 1, 0.5), 2.0)
	if _bstate == "diving":
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 14, Color(1, 0.5, 0.3, 0.9), 2.5)
