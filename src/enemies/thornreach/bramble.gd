class_name Bramble
extends Enemy
## Thornreach lumberer: shoots while advancing, and curls into a hardened ball
## after being struck — 50% reduction while curled up.

const HARDEN_TIME := 1.5


func _init() -> void:
	arch = "bramble"
	display_name = "Bramble"
	base_hp = 15.0
	speed = 40.0
	damage = 6.0
	radius = 15.0
	xp_tier = "medium"
	shot_range = 300.0
	shot_interval = 3.8
	shot_speed = 220.0


func _tick(delta: float) -> void:
	if _bstate == "harden":
		_btimer -= delta
		if _btimer <= 0.0:
			_bstate = ""
			queue_redraw()


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_shot_timer -= delta
	if _shot_timer <= 0.0 and to_p.length() <= shot_range:
		_shot_timer = shot_interval
		_fire_shot(to_p.normalized())
	return to_p.normalized()


func _state_speed() -> float:
	return 0.0 if _bstate == "harden" else 1.0


func _incoming(amount: float, _dtype: String) -> float:
	if _bstate == "harden":
		_logmech("bramble:harden_block")
		return amount * 0.5
	return amount


func _on_hit() -> void:
	if _bstate != "harden":
		_bstate = "harden"
		_btimer = HARDEN_TIME
		queue_redraw()


func _draw_marks() -> void:
	if _bstate == "harden":
		for i in 8:
			var a := i * TAU / 8.0
			draw_line(Vector2(cos(a), sin(a)) * radius, Vector2(cos(a), sin(a)) * (radius + 7.0), Color(1, 1, 1, 0.8), 2.0)
