class_name GraveSwarm
extends Enemy
## Barrows tide. The first "death" only collapses it to bones — it reassembles
## in 2.5s at partial hp. Stomp the pile (any hit) to keep it down for good.

const BONES_TIME := 2.5
const REVIVE_HP_FRAC := 0.4

var _revived := false


func _init() -> void:
	arch = "grave_swarm"
	display_name = "Grave-swarm"
	base_hp = 5.0
	speed = 36.0
	damage = 7.0
	radius = 11.0
	xp_tier = "small"


func _tick(delta: float) -> void:
	if _bstate == "bones":
		_btimer -= delta
		velocity = Vector2.ZERO
		if _btimer <= 0.0:
			_bstate = ""
			hp = base_hp * REVIVE_HP_FRAC
			modulate = Color.WHITE
			queue_redraw()


func _autonomous() -> bool:
	return _bstate == "bones"  # an inert pile: no behavior, no movement


func _cheat_death(_applied: float) -> bool:
	if _revived or _bstate == "bones":
		return false
	_revived = true
	_bstate = "bones"
	_btimer = BONES_TIME
	hp = 0.01
	modulate = Color(0.55, 0.55, 0.55)
	_logmech("grave_swarm:collapse_to_bones")
	queue_redraw()
	return true


func _can_touch() -> bool:
	return _bstate != "bones"


func _pre_draw() -> bool:
	if _bstate == "bones":
		# a stompable pile, ticking back to life
		for i in 4:
			var a := i * TAU / 4.0 + 0.5
			draw_circle(Vector2(cos(a), sin(a)) * radius * 0.4, 3.0, color.darkened(0.3))
		return false
	return true
