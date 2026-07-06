class_name Pouncer
extends Enemy
## Commons ambusher: stalk -> plant -> leap. The windup is the tell.

const LUNGE_RANGE := 260.0
const WINDUP := 0.6
const DASH_MULT := 3.1
const DASH_TIME := 0.5


func _init() -> void:
	arch = "pouncer"
	display_name = "Pouncer"
	base_hp = 5.0
	speed = 100.0
	damage = 8.0
	radius = 10.0
	xp_tier = "medium"


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_btimer -= delta
	match _bstate:
		"windup":
			_lock_dir = to_p.normalized()
			if _btimer <= 0.0:
				_bstate = "dashing"
				_btimer = DASH_TIME
			queue_redraw()
			return Vector2.ZERO
		"dashing":
			if _btimer <= 0.0:
				_bstate = "recover"
				_btimer = 1.4
				queue_redraw()
			return _lock_dir
		"recover":
			if _btimer <= 0.0:
				_bstate = ""
			return to_p.normalized()
		_:
			if to_p.length() <= LUNGE_RANGE:
				_bstate = "windup"
				_btimer = WINDUP
				queue_redraw()
			return to_p.normalized()


func _state_speed() -> float:
	match _bstate:
		"windup":
			return 0.0
		"dashing":
			return DASH_MULT
	return 1.0


func _draw_marks() -> void:
	var d := to_player().normalized() if target != null and is_instance_valid(target) else Vector2.RIGHT
	draw_line(Vector2.ZERO, d * (radius + 4.0), Color(0, 0, 0, 0.45), 3.0)
	if _bstate == "windup":
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 16, Color(1, 0.4, 0.3, 0.9), 3.0)
