class_name Prowler
extends Enemy
## Wilds pack hunter: circles the prey, then pounces from the flank.

const DART_SPEED := 2.2


func _init() -> void:
	arch = "prowler"
	display_name = "Prowler"
	base_hp = 5.0
	speed = 150.0
	damage = 5.0
	radius = 8.0
	xp_tier = "small"


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_btimer -= delta
	match _bstate:
		"circle":
			if _btimer <= 0.0:
				_bstate = "dart"
				_btimer = 0.5
				_lock_dir = to_p.normalized()
			return to_p.normalized().rotated(PI / 2.0) * _strafe_dir
		"dart":
			if _btimer <= 0.0:
				_bstate = "cooldown"
				_btimer = 0.8
			return _lock_dir
		"cooldown":
			if _btimer <= 0.0:
				_bstate = ""
			return to_p.normalized()
		_:
			if to_p.length() < 180.0:
				_bstate = "circle"
				_btimer = 0.9
			return to_p.normalized()


func _state_speed() -> float:
	return DART_SPEED if _bstate == "dart" else 1.0
