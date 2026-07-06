class_name Roc
extends Enemy
## Cragspire raptor: climbs out of reach, shadows you, crashes down. Untouchable
## while airborne — its shadow warns where it will land.

const DIVE_EVERY := 4.5
const CRASH_SPEED := 3.4


func _init() -> void:
	arch = "roc"
	display_name = "Roc"
	base_hp = 20.0
	speed = 95.0
	damage = 10.0
	radius = 16.0
	xp_tier = "medium"
	flies = true


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_btimer -= delta
	match _bstate:
		"ascend":
			modulate.a = 0.35
			if _btimer <= 0.0:
				_bstate = "crash"
				_lock_pos = target.global_position
				queue_redraw()
			return Vector2.ZERO
		"crash":
			var to_l := _lock_pos - global_position
			if to_l.length() < 24.0:
				modulate.a = 1.0
				if to_p.length() < 90.0:
					target.take_damage(damage * 1.5, "Roc (dive)")
				Fx.shake(0.2)
				_bstate = "fly"
				_btimer = DIVE_EVERY
				queue_redraw()
				return Vector2.ZERO
			return to_l.normalized()
		_:
			modulate.a = 1.0
			if _btimer <= 0.0 and to_p.length() < 480.0:
				_bstate = "ascend"
				_btimer = 0.9
				queue_redraw()
			return to_p.normalized()


func _state_speed() -> float:
	match _bstate:
		"ascend":
			return 0.0
		"crash":
			return CRASH_SPEED
	return 1.0


func _incoming(amount: float, _dtype: String) -> float:
	if _bstate == "ascend" or _bstate == "crash":
		_logmech("roc:airborne_immune")
		return 0.0  # out of reach in the sky
	return amount


func _can_touch() -> bool:
	return _bstate != "ascend"


func _pre_draw() -> bool:
	# The shadow warns where it will crash.
	if _bstate == "crash" or _bstate == "ascend":
		var shadow := to_local(_lock_pos if _bstate == "crash" else (target.global_position if target != null and is_instance_valid(target) else global_position))
		draw_circle(shadow, 34.0, Color(0, 0, 0, 0.30))
		draw_arc(shadow, 34.0, 0.0, TAU, 20, Color(1, 0.4, 0.3, 0.7), 2.0)
	return true


func _draw_marks() -> void:
	draw_line(Vector2(-radius * 0.9, -radius * 0.5), Vector2(0, 0), Color(1, 1, 1, 0.4), 2.0)
	draw_line(Vector2(radius * 0.9, -radius * 0.5), Vector2(0, 0), Color(1, 1, 1, 0.4), 2.0)
