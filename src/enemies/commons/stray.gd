class_name Stray
extends Enemy
## Commons skirmisher-dog: hit-and-run — bite, break away, come again.


func _init() -> void:
	arch = "stray"
	display_name = "Stray"
	base_hp = 2.0
	speed = 165.0
	damage = 3.0
	radius = 7.0
	xp_tier = "small"


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_btimer -= delta
	if _bstate == "fleeing":
		if _btimer <= 0.0:
			_bstate = ""
		return (-to_p).normalized().rotated(sin(Time.get_ticks_msec() * 0.004) * 0.3)
	if to_p.length() < 46.0:
		_bstate = "fleeing"
		_btimer = 1.1
	return to_p.normalized().rotated(sin(Time.get_ticks_msec() * 0.006 + float(get_instance_id() % 100)) * 0.4)
