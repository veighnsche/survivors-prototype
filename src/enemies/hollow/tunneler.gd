class_name Tunneler
extends Enemy
## Hollow burrower: dives under (untouchable), races close, erupts. Hit it when
## it surfaces.

const BURROW_TIME := 2.4
const SURFACE_TIME := 3.0
const BURROWED_SPEED := 1.9


func _init() -> void:
	arch = "tunneler"
	display_name = "Tunneler"
	base_hp = 18.0
	speed = 70.0
	damage = 9.0
	radius = 13.0
	xp_tier = "medium"


func _brain(delta: float) -> Vector2:
	var to_p := to_player()
	_btimer -= delta
	match _bstate:
		"burrowed":
			if _btimer <= 0.0 or to_p.length() < 70.0:
				_bstate = "surfacing"
				_btimer = 0.5
				queue_redraw()
			return to_p.normalized()
		"surfacing":
			if _btimer <= 0.0:
				_bstate = "surface"
				_btimer = SURFACE_TIME
				queue_redraw()
			return Vector2.ZERO
		"surface":
			if _btimer <= 0.0:
				_bstate = "burrowed"
				_btimer = BURROW_TIME
				queue_redraw()
			return to_p.normalized()
		_:
			_bstate = "burrowed"
			_btimer = BURROW_TIME
			return to_p.normalized()


func _state_speed() -> float:
	match _bstate:
		"surfacing":
			return 0.0
		"burrowed":
			return BURROWED_SPEED  # closing fast underground
	return 1.0


func _incoming(amount: float, _dtype: String) -> float:
	if _bstate == "burrowed":
		return 0.0  # untouchable underground — hit it when it surfaces
	return amount


func _can_touch() -> bool:
	return _bstate != "burrowed"


func _pre_draw() -> bool:
	if _bstate == "burrowed":
		# only a moving mound shows
		draw_arc(Vector2.ZERO, radius * 0.8, PI, TAU, 12, color.darkened(0.2), 4.0)
		return false
	return true


func _draw_marks() -> void:
	draw_arc(Vector2.ZERO, radius * 0.6, PI, TAU, 10, Color(0, 0, 0, 0.4), 3.0)
